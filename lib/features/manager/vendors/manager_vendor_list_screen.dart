import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/session/session_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/account.dart';
import '../../../data/models/vendor_document.dart';
import '../../../data/providers/firestore_vendors_provider.dart';
import '../../../data/providers/mock_accounts_provider.dart';
import '../../../shared/widgets/app_network_image.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/status_chip.dart';

/// Vendor Management — List (spec §7.7): pending / active / suspended
/// Vendor accounts filtered to the signed-in Manager's own territory
/// (`managerCode`, from the real session account — not a hardcoded demo
/// constant, so each Manager only ever sees their own vendors). Merges two
/// sources: the in-memory `mockAccountsProvider` (a same-session mirror of
/// vendors this Manager just added, before the Firestore stream below
/// catches up) and Firestore's `vendors` collection (real, persisted —
/// vendors a Manager added directly via "Add Vendor", see
/// `manager_vendor_create_screen.dart`), deduped by id since a just-created
/// vendor briefly exists in both.
/// Tapping a row opens the Approval Detail screen.
class ManagerVendorListScreen extends ConsumerWidget {
  const ManagerVendorListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final managerCode = ref.watch(sessionControllerProvider.select((s) => s.account?.managerCode));
    final mockVendors = ref.watch(mockAccountsProvider).where((a) => a.role == AppRole.vendor).toList();
    final firestoreVendors = ref.watch(firestoreVendorsProvider).valueOrNull ?? const [];

    final vendors = mergeVendorAccounts(mockVendors, firestoreVendors).where((a) => managerCode != null && a.managerCode == managerCode).toList();

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Vendor Management'),
          actions: [
            IconButton(
              icon: const Icon(Icons.add_business_rounded),
              tooltip: 'Add Vendor',
              onPressed: () => context.push('/manager/vendors/new'),
            ),
          ],
          bottom: const TabBar(tabs: [Tab(text: 'Pending'), Tab(text: 'Active'), Tab(text: 'Suspended / Rejected')]),
        ),
        body: TabBarView(
          children: [
            _VendorList(accounts: vendors.where((a) => a.status == AccountStatus.pendingReview).toList()),
            _VendorList(accounts: vendors.where((a) => a.status == AccountStatus.active).toList()),
            _VendorList(accounts: vendors.where((a) => a.status == AccountStatus.suspended || a.status == AccountStatus.rejected).toList()),
          ],
        ),
      ),
    );
  }
}

class _VendorList extends StatelessWidget {
  const _VendorList({required this.accounts});
  final List<Account> accounts;

  @override
  Widget build(BuildContext context) {
    if (accounts.isEmpty) {
      return const EmptyState(icon: Icons.storefront_outlined, title: 'No vendors here', subtitle: 'Nothing to show in this category yet.');
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: accounts.length,
      separatorBuilder: (context, _) => const SizedBox(height: 10),
      itemBuilder: (context, i) => _VendorTile(account: accounts[i]),
    );
  }
}

class _VendorTile extends StatelessWidget {
  const _VendorTile({required this.account});
  final Account account;

  static ({String label, StatusTone tone}) _statusMeta(Account account) => switch (account.status) {
    AccountStatus.active => (label: 'ACTIVE', tone: StatusTone.success),
    AccountStatus.pendingReview => account.readyToActivate ? (label: 'READY TO ACTIVATE', tone: StatusTone.info) : (label: 'PENDING REVIEW', tone: StatusTone.warning),
    AccountStatus.rejected => (label: 'REJECTED', tone: StatusTone.error),
    AccountStatus.suspended => (label: 'SUSPENDED', tone: StatusTone.error),
  };

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    final meta = _statusMeta(account);
    final coverUrl = account.documentUrl(VendorDocumentType.shopFrontPhoto);
    return Material(
      color: palette.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => context.push('/manager/vendors/${account.id}'),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: palette.border)),
          child: Row(
            children: [
              coverUrl != null
                  ? AppNetworkImage(url: coverUrl, width: 44, height: 44, borderRadius: BorderRadius.circular(12))
                  : Container(
                      width: 44,
                      height: 44,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: palette.primaryLight.withValues(alpha: 0.25), borderRadius: BorderRadius.circular(12)),
                      child: Icon(Icons.storefront_rounded, color: palette.primary),
                    ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(account.name, style: TextStyle(fontWeight: FontWeight.w700, color: palette.textPrimary)),
                    const SizedBox(height: 3),
                    Text(account.phone, style: TextStyle(color: palette.textMuted, fontSize: 12.5)),
                  ],
                ),
              ),
              StatusChip(label: meta.label, tone: meta.tone),
              const SizedBox(width: 6),
              Icon(Icons.chevron_right_rounded, color: palette.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}
