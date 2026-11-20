import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/refund_case.dart';
import '../../../data/providers/refunds_provider.dart';
import '../../../shared/error_reporting.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../vendor/refunds/vendor_refunds_screen.dart' show RefundListTile;
import '../../../shared/widgets/busy_overlay.dart';

/// Customer refunds on this Manager's own orders (Phase I.7; Phase I.5
/// attribution: the order's Manager, even after the shop moves to another
/// Manager). The Manager follows up with the shop and may escalate to
/// Quicky; they can't confirm a refund — only the customer, or Quicky from
/// evidence, can. The shop, not the Manager, owes the money.
class ManagerRefundsScreen extends ConsumerWidget {
  const ManagerRefundsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.colors;
    final async = ref.watch(managerRefundsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Customer refunds')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(friendlyError(e, action: 'Loading refunds')),
            TextButton(onPressed: () => ref.invalidate(managerRefundsProvider), child: const Text('Retry')),
          ]),
        ),
        data: (refunds) {
          if (refunds.isEmpty) {
            return const EmptyState(icon: Icons.currency_rupee_rounded, title: 'No refunds', subtitle: 'Refunds owed to customers on your orders show here.');
          }
          final open = refunds.where((r) => !r.status.isDone).toList();
          final outstanding = open.fold<int>(0, (a, r) => a + (r.outstandingPaise ?? 0));
          final followUps = open.where((r) => r.managerFollowUpNeeded).length;
          // Overdue first (oldest obligation first), then the rest as listed.
          final sorted = [...refunds]..sort((a, b) {
            int rank(RefundCase r) => r.status.isDone ? 2 : r.managerFollowUpNeeded ? 0 : 1;
            final c = rank(a).compareTo(rank(b));
            return c != 0 ? c : (b.ageHours() ?? 0).compareTo(a.ageHours() ?? 0);
          });
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text('${open.length} open · ${rupeesOf(outstanding)} still owed to customers by shops', key: const Key('managerRefundSummary'), style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              if (followUps > 0)
                Text('$followUps overdue (24 h or more): please follow up with the shop.', key: const Key('managerFollowUpCount'), style: TextStyle(color: palette.error, fontWeight: FontWeight.w700)),
              Text('The shop that was paid owes each refund. Follow up with the shop; escalate to QuickMandi if it isn\'t resolved. You can\'t confirm a refund for the customer.', style: TextStyle(color: palette.textSecondary, fontSize: 12)),
              const SizedBox(height: 12),
              for (final r in sorted) ...[
                RefundListTile(
                  refund: r,
                  trailing: r.status.isDone
                      ? null
                      : Wrap(spacing: 8, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
                          if (r.managerFollowUpNeeded)
                            FilledButton.tonalIcon(
                              key: Key('followUpRefund_${r.orderId}'),
                              icon: const Icon(Icons.edit_note_rounded, size: 18),
                              label: Text(r.followUpCount == 0 ? 'Record follow-up' : 'Record follow-up (${r.followUpCount} so far)'),
                              onPressed: () => _followUp(context, ref, r),
                            ),
                          if (r.escalated)
                            Text('Escalated to QuickMandi${r.escalationReason != null ? ': ${r.escalationReason}' : ''}', style: TextStyle(color: palette.textSecondary, fontSize: 12))
                          else
                            OutlinedButton.icon(
                              key: Key('escalateRefund_${r.orderId}'),
                              icon: const Icon(Icons.flag_outlined, size: 18),
                              label: const Text('Escalate to QuickMandi'),
                              onPressed: () => _escalate(context, ref, r),
                            ),
                          if (r.lastFollowUpRemark != null)
                            Text('Your last note: ${r.lastFollowUpRemark}', style: TextStyle(color: palette.textSecondary, fontSize: 12)),
                        ]),
                ),
                const SizedBox(height: 10),
              ],
            ],
          );
        },
      ),
    );
  }

  Future<void> _followUp(BuildContext context, WidgetRef ref, RefundCase r) async {
    final requestId = newRefundRequestId();
    final remark = await showDialog<String>(context: context, builder: (_) => const _EscalateDialog(followUp: true));
    if (remark == null) return;
    try {
      await runBusy(() => ref.read(refundActionsProvider).recordFollowUp(orderId: r.orderId, requestId: requestId, remark: remark));
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Follow-up recorded.')));
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _escalate(BuildContext context, WidgetRef ref, RefundCase r) async {
    final reason = await showDialog<String>(context: context, builder: (_) => const _EscalateDialog());
    if (reason == null) return;
    try {
      await runBusy(() => ref.read(refundActionsProvider).escalate(orderId: r.orderId, reason: reason));
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sent to QuickMandi for review.')));
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }
}

class _EscalateDialog extends StatefulWidget {
  const _EscalateDialog({this.followUp = false});

  /// A follow-up remark rather than an escalation.
  final bool followUp;

  @override
  State<_EscalateDialog> createState() => _EscalateDialogState();
}

class _EscalateDialogState extends State<_EscalateDialog> {
  final _reason = TextEditingController();

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ok = _reason.text.trim().length >= 10;
    return AlertDialog(
      title: Text(widget.followUp ? 'Record a follow-up' : 'Escalate this refund'),
      content: TextField(
        key: const Key('escalateReason'),
        controller: _reason,
        maxLines: 3,
        maxLength: 500,
        decoration: InputDecoration(labelText: widget.followUp ? 'What you did or found (at least 10 characters)' : 'What\'s wrong? (at least 10 characters)'),
        onChanged: (_) => setState(() {}),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(key: const Key('escalateSubmit'), onPressed: ok ? () => Navigator.pop(context, _reason.text.trim()) : null, child: Text(widget.followUp ? 'Save note' : 'Escalate')),
      ],
    );
  }
}
