import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/session/session_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/account.dart';
import '../../../data/providers/firestore_managers_provider.dart';
import '../../../data/providers/firestore_vendors_provider.dart';
import '../../../data/providers/mock_accounts_provider.dart';
import '../../../shared/widgets/app_network_image.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/status_chip.dart';

/// Vendor Management — List (spec §7.7, Phase I.5 directory). A territory
/// may have several Managers, each running their own shops:
///  - **My Vendors** (default): the shops assigned to the signed-in Manager —
///    full records, any status, merged with a same-session mirror of one
///    they just added (`mockAccountsProvider`) until Firestore catches up.
///  - **All / Other Managers' / Active / Inactive**: the territory's
///    sanitized directory (`vendor_directory`) — name, category, status and
///    who runs it, never contact, UPI, KYC or money. Another Manager's shop
///    opens a read-only summary, not the management screen.
class ManagerVendorListScreen extends ConsumerWidget {
  const ManagerVendorListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(sessionControllerProvider.select((s) => s.account?.id));
    final mockVendors = ref.watch(mockAccountsProvider).where((a) => a.role == AppRole.vendor).toList();
    final firestoreVendors = ref.watch(firestoreVendorsProvider).valueOrNull ?? const [];
    final directory = ref.watch(territoryVendorDirectoryProvider).valueOrNull ?? const [];
    final managerNames = {
      for (final m in ref.watch(firestoreManagersProvider).valueOrNull ?? const <Account>[]) m.id: m.name,
    };

    final mine = mergeVendorAccounts(mockVendors, firestoreVendors).where((a) => me != null && a.isAssignedTo(me)).toList()
      ..sort((a, b) => _statusOrder(a).compareTo(_statusOrder(b)));
    final others = directory.where((a) => me == null || !a.isAssignedTo(me)).toList();

    return DefaultTabController(
      length: 5,
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
          bottom: const TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(text: 'My Vendors'),
              Tab(text: 'All Territory'),
              Tab(text: "Other Managers'"),
              Tab(text: 'Active'),
              Tab(text: 'Inactive'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _VendorList(accounts: mine, me: me, managerNames: managerNames, emptyTitle: 'No vendors assigned to you'),
            _VendorList(accounts: directory, me: me, managerNames: managerNames),
            _VendorList(accounts: others, me: me, managerNames: managerNames, emptyTitle: "No other Managers' vendors"),
            _VendorList(accounts: directory.where((a) => a.status == AccountStatus.active).toList(), me: me, managerNames: managerNames),
            _VendorList(accounts: directory.where((a) => a.status != AccountStatus.active).toList(), me: me, managerNames: managerNames),
          ],
        ),
      ),
    );
  }

  static int _statusOrder(Account a) => switch (a.status) {
    AccountStatus.pendingReview => 0,
    AccountStatus.active => 1,
    AccountStatus.suspended => 2,
    AccountStatus.rejected => 3,
  };
}

class _VendorList extends StatelessWidget {
  const _VendorList({required this.accounts, required this.me, required this.managerNames, this.emptyTitle = 'No vendors here'});
  final List<Account> accounts;
  final String? me;
  final Map<String, String> managerNames;
  final String emptyTitle;

  @override
  Widget build(BuildContext context) {
    if (accounts.isEmpty) {
      return EmptyState(icon: Icons.storefront_outlined, title: emptyTitle, subtitle: 'Nothing to show in this list yet.');
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: accounts.length,
      separatorBuilder: (context, _) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final a = accounts[i];
        final mine = me != null && a.isAssignedTo(me!);
        return _VendorTile(
          account: a,
          mine: mine,
          managerLabel: mine ? 'You' : (a.assignedManagerId == null ? 'No Manager yet' : managerNames[a.assignedManagerId] ?? 'Another Manager'),
        );
      },
    );
  }
}

class _VendorTile extends StatelessWidget {
  const _VendorTile({required this.account, required this.mine, required this.managerLabel});
  final Account account;
  final bool mine;
  final String managerLabel;

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
    final coverUrl = account.coverPhotoUrl;
    return Material(
      color: palette.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        // Only the shop's own Manager opens its management screen.
        onTap: mine ? () => context.push('/manager/vendors/${account.id}') : () => _showDirectoryEntry(context),
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
                    // Directory entries carry no phone number.
                    Text(
                      mine && account.phone.isNotEmpty ? '${account.phone} · Managed by you' : 'Managed by $managerLabel',
                      style: TextStyle(color: palette.textMuted, fontSize: 12.5),
                    ),
                  ],
                ),
              ),
              StatusChip(label: meta.label, tone: meta.tone),
              const SizedBox(width: 6),
              Icon(mine ? Icons.chevron_right_rounded : Icons.info_outline_rounded, color: palette.textMuted),
            ],
          ),
        ),
      ),
    );
  }

  /// Read-only: what the territory directory says about another Manager's
  /// shop. Its orders, money and documents stay with its own Manager.
  void _showDirectoryEntry(BuildContext context) {
    final palette = context.colors;
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(account.name, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: palette.textPrimary)),
              const SizedBox(height: 12),
              _line(palette, 'Category', [account.category, account.subCategory].whereType<String>().join(' · ')),
              _line(palette, 'Status', _statusMeta(account).label),
              _line(palette, 'Managed by', managerLabel),
              const SizedBox(height: 12),
              Text(
                "This shop is run by another Manager. Its orders, payments and documents are visible only to them and the Super Admin.",
                style: TextStyle(color: palette.textMuted, fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _line(AppPalette palette, String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 110, child: Text(label, style: TextStyle(color: palette.textMuted))),
        Expanded(child: Text(value.isEmpty ? '—' : value, style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w600))),
      ],
    ),
  );
}
