import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/account.dart';
import '../../../data/models/vendor_document.dart';
import '../../../data/providers/firestore_vendors_provider.dart';
import '../../../data/providers/mock_accounts_provider.dart';
import '../../../shared/widgets/app_network_image.dart';
import '../../../shared/widgets/document_viewer_screen.dart';
import '../../../shared/widgets/status_chip.dart';

/// Vendor Approval Detail (spec §7.7). Looks the vendor up across both
/// stores — Firestore's `vendors` collection and the in-memory
/// `mockAccountsProvider` (a same-session mirror of a vendor this Manager
/// just added, before the Firestore stream catches up) — the same merge
/// `manager_vendor_list_screen.dart` uses, so every mutation below routes
/// to whichever store actually owns this vendor's record
/// ([_isFirestoreBacked]) rather than silently writing somewhere that
/// doesn't persist.
///
/// Rebate % is fixed once, on `manager_vendor_create_screen.dart`'s "Add
/// Vendor" form — shown here read-only, never editable again, so a
/// negotiated split can't drift after the fact.
///
/// Document checklist is real: each of the 4 fixed documents tracks
/// Required/Not Required/Submitted rather than a static "Submitted"
/// placeholder — Manager sets required/not required
/// here, Vendor is the only one who can move an entry to Submitted (see
/// the Vendor-side `vendor_documents_status_screen.dart`). Once every
/// required document is submitted, [Account.readyToActivate] flips true and
/// the status pill reads "READY TO ACTIVATE" instead of "PENDING" while
/// still `pendingReview` — Manager's cue to hit Approve.
class ManagerVendorDetailScreen extends ConsumerStatefulWidget {
  const ManagerVendorDetailScreen({super.key, required this.accountId});
  final String accountId;

  @override
  ConsumerState<ManagerVendorDetailScreen> createState() => _ManagerVendorDetailScreenState();
}

class _ManagerVendorDetailScreenState extends ConsumerState<ManagerVendorDetailScreen> {
  Future<void> _setStatus(Account account, bool isFirestoreBacked, AccountStatus status, {String? rejectionReason}) {
    if (isFirestoreBacked) {
      return updateVendorStatus(account.id, status, rejectionReason: rejectionReason);
    }
    ref.read(mockAccountsProvider.notifier).setStatus(account.id, status, rejectionReason: rejectionReason);
    return Future.value();
  }

  Future<void> _setDocumentStatus(Account account, bool isFirestoreBacked, VendorDocumentType type, VendorDocumentStatus status) {
    if (isFirestoreBacked) {
      return updateVendorDocumentStatus(account.id, type, status);
    }
    ref.read(mockAccountsProvider.notifier).updateDocumentStatus(account.id, type, status);
    return Future.value();
  }

  Future<void> _approve(Account account, bool isFirestoreBacked) async {
    await _setStatus(account, isFirestoreBacked, AccountStatus.active);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${account.name} approved.')));
    context.pop();
  }

  Future<void> _reject(Account account, bool isFirestoreBacked) async {
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject application'),
        content: TextField(controller: controller, maxLines: 3, decoration: const InputDecoration(hintText: 'Reason for rejection')),
        actions: [
          TextButton(onPressed: () => context.pop(), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => context.pop(controller.text.trim()), child: const Text('Reject')),
        ],
      ),
    );
    if (reason == null || reason.isEmpty || !mounted) return;
    await _setStatus(account, isFirestoreBacked, AccountStatus.rejected, rejectionReason: reason);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${account.name} rejected.')));
    context.pop();
  }

  Future<void> _toggleSuspend(Account account, bool isFirestoreBacked) async {
    final next = account.status == AccountStatus.suspended ? AccountStatus.active : AccountStatus.suspended;
    await _setStatus(account, isFirestoreBacked, next);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${account.name} ${next == AccountStatus.suspended ? 'suspended' : 'reactivated'}.')));
  }

  Future<void> _markPending(Account account, bool isFirestoreBacked) async {
    await _setStatus(account, isFirestoreBacked, AccountStatus.pendingReview);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${account.name} marked as pending review.')));
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    final mockAccounts = ref.watch(mockAccountsProvider);
    final firestoreVendors = ref.watch(firestoreVendorsProvider).valueOrNull ?? const [];
    final isFirestoreBacked = firestoreVendors.any((v) => v.id == widget.accountId);
    final account = mergeVendorAccounts(mockAccounts, firestoreVendors).where((a) => a.id == widget.accountId).firstOrNull;

    if (account == null) {
      return Scaffold(appBar: AppBar(title: const Text('Vendor')), body: const Center(child: Text('Vendor not found.')));
    }
    final coverUrl = account.documentUrl(VendorDocumentType.shopFrontPhoto);
    return Scaffold(
      appBar: AppBar(title: Text(account.name)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Row(
            children: [
              coverUrl != null
                  ? AppNetworkImage(url: coverUrl, width: 52, height: 52, borderRadius: BorderRadius.circular(15))
                  : Container(
                      width: 52,
                      height: 52,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: palette.primaryLight.withValues(alpha: 0.25), borderRadius: BorderRadius.circular(15)),
                      child: Icon(Icons.storefront_rounded, color: palette.primary, size: 26),
                    ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(account.name, style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 3),
                    if (account.ownerName != null) Text('Owner: ${account.ownerName}', style: TextStyle(color: palette.textSecondary, fontSize: 12.5)),
                    Text(account.phone, style: TextStyle(color: palette.textSecondary)),
                  ],
                ),
              ),
              _StatusPill(account: account),
            ],
          ),
          if (account.status == AccountStatus.rejected && account.rejectionReason != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: palette.error.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12)),
              child: Text('Rejection reason: ${account.rejectionReason}', style: TextStyle(color: palette.error, fontWeight: FontWeight.w600)),
            ),
          ],
          if (account.status == AccountStatus.pendingReview && account.readyToActivate) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: palette.primary.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12)),
              child: Row(
                children: [
                  Icon(Icons.task_alt_rounded, color: palette.primary, size: 18),
                  const SizedBox(width: 8),
                  Expanded(child: Text('All required documents are submitted — ready to activate.', style: TextStyle(color: palette.primary, fontWeight: FontWeight.w600, fontSize: 12.5))),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),
          Text('Documents', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          Text('Set which documents apply to this vendor — only the vendor can mark one Submitted.', style: TextStyle(color: palette.textMuted, fontSize: 12)),
          const SizedBox(height: 12),
          for (final type in VendorDocumentType.values)
            _DocumentTile(
              type: type,
              status: account.documentStatus(type),
              imageUrl: account.documentUrl(type),
              onChanged: (status) => _setDocumentStatus(account, isFirestoreBacked, type, status),
            ),
          const SizedBox(height: 24),
          Text('Rebate %', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          Text('Fixed when this vendor was onboarded — cannot be changed.', style: TextStyle(color: palette.textMuted, fontSize: 12)),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(color: palette.surfaceMuted, borderRadius: BorderRadius.circular(12)),
            child: Row(
              children: [
                Icon(Icons.lock_outline_rounded, size: 18, color: palette.textMuted),
                const SizedBox(width: 10),
                Expanded(child: Text('Negotiated split routed to this territory.', style: TextStyle(color: palette.textSecondary, fontSize: 12.5))),
                Text('${account.rebatePercent.round()}%', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: palette.textPrimary)),
              ],
            ),
          ),
          const SizedBox(height: 20),
          if (account.status == AccountStatus.pendingReview) ...[
            ElevatedButton.icon(onPressed: () => _approve(account, isFirestoreBacked), icon: const Icon(Icons.check_circle_outline_rounded), label: const Text('Approve')),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () => _reject(account, isFirestoreBacked),
              style: OutlinedButton.styleFrom(foregroundColor: palette.error, side: BorderSide(color: palette.error)),
              icon: const Icon(Icons.cancel_outlined),
              label: const Text('Reject'),
            ),
          ] else ...[
            if (account.status == AccountStatus.active || account.status == AccountStatus.suspended)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: OutlinedButton.icon(
                  onPressed: () => _toggleSuspend(account, isFirestoreBacked),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: account.status == AccountStatus.suspended ? palette.success : palette.error,
                    side: BorderSide(color: account.status == AccountStatus.suspended ? palette.success : palette.error),
                  ),
                  icon: Icon(account.status == AccountStatus.suspended ? Icons.play_circle_outline_rounded : Icons.pause_circle_outline_rounded),
                  label: Text(account.status == AccountStatus.suspended ? 'Reactivate vendor' : 'Suspend vendor'),
                ),
              ),
            OutlinedButton.icon(
              onPressed: () => _markPending(account, isFirestoreBacked),
              icon: const Icon(Icons.hourglass_empty_rounded),
              label: const Text('Mark as Pending'),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.account});
  final Account account;

  @override
  Widget build(BuildContext context) {
    final meta = switch (account.status) {
      AccountStatus.active => (label: 'ACTIVE', tone: StatusTone.success),
      AccountStatus.pendingReview => account.readyToActivate ? (label: 'READY TO ACTIVATE', tone: StatusTone.info) : (label: 'PENDING', tone: StatusTone.warning),
      AccountStatus.rejected => (label: 'REJECTED', tone: StatusTone.error),
      AccountStatus.suspended => (label: 'SUSPENDED', tone: StatusTone.error),
    };
    return StatusChip(label: meta.label, tone: meta.tone);
  }
}

class _DocumentTile extends StatelessWidget {
  const _DocumentTile({required this.type, required this.status, required this.imageUrl, required this.onChanged});
  final VendorDocumentType type;
  final VendorDocumentStatus status;
  final String? imageUrl;
  final ValueChanged<VendorDocumentStatus> onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    final submitted = status == VendorDocumentStatus.submitted;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: palette.surfaceMuted, borderRadius: BorderRadius.circular(12)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (submitted && imageUrl != null)
                  InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => DocumentViewerScreen.show(context, imageUrl: imageUrl!, title: type.label),
                    child: AppNetworkImage(url: imageUrl!, width: 36, height: 36, borderRadius: BorderRadius.circular(8)),
                  )
                else
                  Icon(type.icon, color: palette.textSecondary),
                const SizedBox(width: 12),
                Expanded(child: Text(type.label, style: TextStyle(fontWeight: FontWeight.w600, color: palette.textPrimary))),
                if (submitted) StatusChip(label: 'SUBMITTED', tone: StatusTone.success),
              ],
            ),
            if (status != VendorDocumentStatus.submitted) ...[
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: _RequirementToggle(
                  required: status == VendorDocumentStatus.required,
                  onChanged: (isRequired) => onChanged(isRequired ? VendorDocumentStatus.required : VendorDocumentStatus.notRequired),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _RequirementToggle extends StatelessWidget {
  const _RequirementToggle({required this.required, required this.onChanged});
  final bool required;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    return SegmentedButton<bool>(
      segments: const [
        ButtonSegment(value: true, label: Text('Required', style: TextStyle(fontSize: 11.5))),
        ButtonSegment(value: false, label: Text('Not Required', style: TextStyle(fontSize: 11.5))),
      ],
      selected: {required},
      showSelectedIcon: false,
      onSelectionChanged: (selection) => onChanged(selection.first),
      style: ButtonStyle(
        visualDensity: VisualDensity.compact,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        padding: WidgetStateProperty.all(const EdgeInsets.symmetric(horizontal: 8, vertical: 2)),
        side: WidgetStateProperty.all(BorderSide(color: palette.border)),
      ),
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
