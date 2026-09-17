import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/session/session_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/account.dart';
import '../../../data/providers/firestore_drivers_provider.dart';
import '../../../data/providers/mock_accounts_provider.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/status_chip.dart';

/// Driver Management — List (spec §7.8): same pending/active/suspended
/// pattern as Vendor Management (`manager_vendor_list_screen.dart`), over
/// Driver accounts filtered to the signed-in Manager's own territory
/// (`managerCode`, from the real session account, not a hardcoded demo
/// constant). Merges `mockAccountsProvider` (a same-session mirror of
/// drivers this Manager just added, before the Firestore stream below
/// catches up) with Firestore's `drivers` collection, deduped by id.
class ManagerDriverListScreen extends ConsumerWidget {
  const ManagerDriverListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final managerCode = ref.watch(sessionControllerProvider.select((s) => s.account?.managerCode));
    final mockDrivers = ref.watch(mockAccountsProvider).where((a) => a.role == AppRole.driver).toList();
    final firestoreDrivers = ref.watch(firestoreDriversProvider).valueOrNull ?? const [];

    final drivers = mergeDriverAccounts(mockDrivers, firestoreDrivers).where((a) => managerCode != null && a.managerCode == managerCode).toList();

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Driver Management'),
          actions: [
            IconButton(
              icon: const Icon(Icons.person_add_alt_1_rounded),
              tooltip: 'Add Driver',
              onPressed: () => context.push('/manager/drivers/new'),
            ),
          ],
          bottom: const TabBar(tabs: [Tab(text: 'Pending'), Tab(text: 'Active'), Tab(text: 'Suspended / Rejected')]),
        ),
        body: TabBarView(
          children: [
            _DriverList(accounts: drivers.where((a) => a.status == AccountStatus.pendingReview).toList()),
            _DriverList(accounts: drivers.where((a) => a.status == AccountStatus.active).toList()),
            _DriverList(accounts: drivers.where((a) => a.status == AccountStatus.suspended || a.status == AccountStatus.rejected).toList()),
          ],
        ),
      ),
    );
  }
}

class _DriverList extends StatelessWidget {
  const _DriverList({required this.accounts});
  final List<Account> accounts;

  @override
  Widget build(BuildContext context) {
    if (accounts.isEmpty) {
      return const EmptyState(icon: Icons.two_wheeler_outlined, title: 'No drivers here', subtitle: 'Nothing to show in this category yet.');
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: accounts.length,
      separatorBuilder: (context, _) => const SizedBox(height: 10),
      itemBuilder: (context, i) => _DriverTile(account: accounts[i]),
    );
  }
}

class _DriverTile extends StatelessWidget {
  const _DriverTile({required this.account});
  final Account account;

  static ({String label, StatusTone tone}) _statusMeta(Account account) => switch (account.status) {
    AccountStatus.active => (label: 'ACTIVE', tone: StatusTone.success),
    AccountStatus.pendingReview => account.driverReadyToActivate ? (label: 'READY TO ACTIVATE', tone: StatusTone.info) : (label: 'PENDING REVIEW', tone: StatusTone.warning),
    AccountStatus.rejected => (label: 'REJECTED', tone: StatusTone.error),
    AccountStatus.suspended => (label: 'SUSPENDED', tone: StatusTone.error),
  };

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    final meta = _statusMeta(account);
    return Material(
      color: palette.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => context.push('/manager/drivers/${account.id}'),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: palette.border)),
          child: Row(
            children: [
              CircleAvatar(backgroundColor: palette.primaryLight.withValues(alpha: 0.25), child: Icon(Icons.two_wheeler_rounded, color: palette.primary)),
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
