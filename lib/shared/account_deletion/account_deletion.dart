import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/release/app_build.dart';
import '../../core/session/access_scope.dart';
import '../../core/theme/app_colors.dart';
import '../../l10n/app_localizations_context.dart';
import '../widgets/busy_overlay.dart';
import '../widgets/menu_tile.dart';

/// Account deletion requests (2026-11-19), the same flow as ShuttleLounge:
/// "Delete account" in every role's Profile menu asks for confirmation,
/// sends the request, and says it's reviewed within 2–3 working days. While
/// it's pending, a red card at the top of the Profile page says so and lets
/// them cancel. The Super Admin decides in QuickyAdmin (Account Deletions)
/// and, if approved, the account is hard-deleted on the server
/// (QuickyAdmin `functions/account_deletion.js`) — the app never deletes
/// anything itself.
///
/// The request lives at `account_deletion_requests/<role>_<accountId>`,
/// readable by the account itself (firestore.rules) and written only by the
/// `requestAccountDeletion` / `cancelAccountDeletion` callables.
enum DeletionRequestState { none, pending, rejected }

typedef MyDeletionRequest = ({DeletionRequestState state, DateTime? requestedAt, String? rejectionReason});

const _none = (state: DeletionRequestState.none, requestedAt: null, rejectionReason: null);

final myDeletionRequestProvider = StreamProvider.autoDispose<MyDeletionRequest>((ref) {
  final scope = ref.watch(accessScopeProvider);
  if (scope == null) return Stream.value(_none);
  return FirebaseFirestore.instance.doc('account_deletion_requests/${scope.role.name}_${scope.accountId}').snapshots().map((d) {
    final data = d.data();
    final status = data?['status'];
    final at = data?['requestedAt'];
    return (
      // A delete that has started is still "pending" to them.
      state: status == 'pending' || status == 'deleting'
          ? DeletionRequestState.pending
          : status == 'rejected'
          ? DeletionRequestState.rejected
          : DeletionRequestState.none,
      requestedAt: at is Timestamp ? at.toDate() : null,
      rejectionReason: data?['decisionReason'] as String?,
    );
  });
});

final _functions = FirebaseFunctions.instanceFor(region: 'asia-south1');

Future<void> _call(String name, Map<String, dynamic> data) => _functions.httpsCallable(name).call<Object?>(withClientBuild(data));

String _errorText(Object e) {
  if (e is FirebaseFunctionsException && e.message != null && e.code != 'internal' && e.code != 'unavailable') return e.message!;
  return "We couldn't reach the server. Check your connection and try again.";
}

void _toast(BuildContext context, String text) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

/// Confirms, sends the request and shows the "2–3 working days" message.
/// [context] must stay mounted throughout (from a drawer, pass the page's).
Future<void> startAccountDeletion(BuildContext context) async {
  final reason = await showDialog<String>(context: context, builder: (_) => const _ConfirmDialog());
  if (reason == null || !context.mounted) return;
  try {
    await runBusy(() => _call('requestAccountDeletion', {if (reason.isNotEmpty) 'reason': reason}));
  } catch (e) {
    if (context.mounted) _toast(context, _errorText(e));
    return;
  }
  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    builder: (ctx) => _DeletionDialog(
      icon: Icons.hourglass_top_rounded,
      title: ctx.l10n.accountDeleteSubmittedTitle,
      message: ctx.l10n.accountDeleteSubmittedBody,
      actions: [
        Expanded(
          child: ElevatedButton(onPressed: () => Navigator.pop(ctx), child: Text(ctx.l10n.accountDeleteOk)),
        ),
      ],
    ),
  );
}

/// "Delete account", red — place just above Log Out. Hidden while a request
/// is pending (the [AccountDeletionBanner] shows instead).
class AccountDeletionTile extends ConsumerWidget {
  const AccountDeletionTile({super.key, this.onTap});

  /// Overrides the default (used from the Manager drawer, which must close first).
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Guests have no account to delete.
    if (ref.watch(accessScopeProvider) == null) return const SizedBox.shrink();
    final request = ref.watch(myDeletionRequestProvider).valueOrNull;
    // Nothing until known, so the tile doesn't flash before a pending card.
    if (request == null || request.state == DeletionRequestState.pending) return const SizedBox.shrink();
    return MenuTile(
      icon: Icons.delete_forever_rounded,
      label: context.l10n.accountDeleteTile,
      color: context.colors.error,
      onTap: onTap ?? () => startAccountDeletion(context),
    );
  }
}

/// The red "under review for deletion" card (with Cancel request) while a
/// request is pending, or a note when the admin declined it. Place at the
/// top of the Profile page.
class AccountDeletionBanner extends ConsumerWidget {
  const AccountDeletionBanner({super.key, this.padding = const EdgeInsets.only(bottom: 16)});

  final EdgeInsets padding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final request = ref.watch(myDeletionRequestProvider).valueOrNull;
    if (request == null || request.state == DeletionRequestState.none) return const SizedBox.shrink();
    return Padding(
      padding: padding,
      child: request.state == DeletionRequestState.pending ? _PendingCard(requestedAt: request.requestedAt) : _RejectedCard(reason: request.rejectionReason),
    );
  }
}

class _PendingCard extends StatefulWidget {
  const _PendingCard({required this.requestedAt});

  final DateTime? requestedAt;

  @override
  State<_PendingCard> createState() => _PendingCardState();
}

class _PendingCardState extends State<_PendingCard> {
  bool _cancelling = false;

  Future<void> _cancel() async {
    setState(() => _cancelling = true);
    try {
      await runBusy(() => _call('cancelAccountDeletion', const {}));
      if (mounted) _toast(context, context.l10n.accountDeleteCancelledToast);
    } catch (e) {
      if (mounted) _toast(context, _errorText(e));
    } finally {
      if (mounted) setState(() => _cancelling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    final l10n = context.l10n;
    final at = widget.requestedAt;
    return _Card(
      color: palette.error,
      icon: Icons.warning_amber_rounded,
      title: l10n.accountDeletePendingTitle,
      body: at == null ? l10n.accountDeletePendingBodyNoDate : l10n.accountDeletePendingBody(DateFormat('dd/MM/yyyy').format(at.toLocal())),
      action: TextButton(onPressed: _cancelling ? null : _cancel, child: Text(_cancelling ? l10n.accountDeleteCancelling : l10n.accountDeleteCancelRequest)),
    );
  }
}

class _RejectedCard extends StatelessWidget {
  const _RejectedCard({required this.reason});

  final String? reason;

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    final r = (reason ?? '').trim();
    return _Card(
      color: palette.warning,
      icon: Icons.info_outline_rounded,
      title: context.l10n.accountDeleteRejectedTitle,
      body: context.l10n.accountDeleteRejectedBody(r.isEmpty ? '' : (r.endsWith('.') ? r : '$r.')).trim(),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.color, required this.icon, required this.title, required this.body, this.action});

  final Color color;
  final IconData icon;
  final String title;
  final String body;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(color: color, fontSize: 15, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(body, style: TextStyle(color: palette.textSecondary, fontSize: 13, height: 1.45)),
          if (action != null) Align(alignment: Alignment.centerRight, child: action),
        ],
      ),
    );
  }
}

/// Confirmation with an optional reason. Returns the reason ('' for none),
/// or null when cancelled.
class _ConfirmDialog extends StatefulWidget {
  const _ConfirmDialog();

  @override
  State<_ConfirmDialog> createState() => _ConfirmDialogState();
}

class _ConfirmDialogState extends State<_ConfirmDialog> {
  final _reason = TextEditingController();

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final palette = context.colors;
    return _DeletionDialog(
      icon: Icons.delete_forever_rounded,
      title: l10n.accountDeleteConfirmTitle,
      message: l10n.accountDeleteConfirmBody,
      extra: TextField(
        controller: _reason,
        maxLength: 500,
        maxLines: 2,
        decoration: InputDecoration(labelText: l10n.accountDeleteReasonLabel),
      ),
      actions: [
        Expanded(
          child: OutlinedButton(onPressed: () => Navigator.pop(context), child: Text(l10n.accountDeleteCancel)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: palette.error, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, _reason.text.trim()),
            child: Text(l10n.accountDeleteConfirmAction),
          ),
        ),
      ],
    );
  }
}

class _DeletionDialog extends StatelessWidget {
  const _DeletionDialog({required this.icon, required this.title, required this.message, required this.actions, this.extra});

  final IconData icon;
  final String title;
  final String message;
  final List<Widget> actions;
  final Widget? extra;

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      contentPadding: const EdgeInsets.fromLTRB(24, 28, 24, 16),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: palette.error.withValues(alpha: 0.12), shape: BoxShape.circle),
              child: Icon(icon, size: 36, color: palette.error),
            ),
            const SizedBox(height: 18),
            Text(title, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: palette.textSecondary, fontSize: 13, height: 1.5),
            ),
            if (extra != null) ...[const SizedBox(height: 12), extra!],
            const SizedBox(height: 20),
            Row(children: actions),
          ],
        ),
      ),
    );
  }
}
