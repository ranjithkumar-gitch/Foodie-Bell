import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/account.dart';
import '../../../data/providers/firestore_drivers_provider.dart';
import '../../../data/providers/earnings_provider.dart';
import '../../../data/providers/firestore_orders_provider.dart';
import '../../../data/providers/firestore_vendors_provider.dart';
import '../../../data/providers/settlement_provider.dart';
import '../../../data/providers/vendor_incidents_provider.dart';
import '../../../shared/widgets/currency_text.dart';
import '../manager_session.dart';

/// Manager Dashboard (spec §7.6; Phase I.5 §5.1): the signed-in Manager's
/// own business only — their shops, their orders today, completed and
/// pending, their commission, what's owed to them, their unsettled days and
/// their shops' cancellations to review — plus the territory's shop count
/// (a directory figure, not money) — and quick-action links into every other
/// Manager screen (Vendor/Driver Management already have rail tabs; the
/// rest — Settlement History, Territory Earnings, Marketing Tracker,
/// Promotion Approvals, Order Oversight, Support — only have entry points
/// here and from Profile, mirroring how admin_routes.dart only wires a
/// handful of screens onto rail tabs. Code Management/Notifications are
/// Profile-only now — trimmed out of this quick-actions grid).
///
/// The "setting up your territory" checklist ([_TerritorySetupCard]) is
/// real — it reads whether this Manager has actually onboarded any
/// Vendor/Driver in their territory, not a self-reported checkbox (the old
/// `managerOnboardingProvider`, deleted along with the dead post-approval
/// onboarding chain it drove — Manager accounts are Admin-created and
/// active immediately now, so there was never a real "fee paid"/"checklist"
/// moment for a Manager to walk through in the first place).
class ManagerDashboardScreen extends ConsumerWidget {
  const ManagerDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.colors;
    final managerAccount = ref.watch(currentManagerAccountProvider);
    // Phase I.5: `firestoreVendorsProvider` is this Manager's own shops; the
    // directory is the whole territory (a count only, never money).
    final vendors = ref.watch(firestoreVendorsProvider).valueOrNull ?? const [];
    final territoryVendors = ref.watch(territoryVendorDirectoryProvider).valueOrNull ?? const [];
    final territoryDrivers = ref.watch(firestoreDriversProvider).valueOrNull ?? const [];
    final activeDrivers = territoryDrivers.where((a) => a.status == AccountStatus.active).length;
    final hasVendor = vendors.isNotEmpty;
    final hasDriver = territoryDrivers.isNotEmpty;

    // Every financial figure is this Manager's own — their shops' orders,
    // their statements — never another Manager's (Phase I.5).
    final today = ref.watch(managerTodayEarningsProvider).valueOrNull ?? const EarningsFigures({});
    final ordersToday = ref.watch(todaysOrdersProvider).valueOrNull ?? const [];
    final pending = ref.watch(activeOrdersProvider).valueOrNull ?? const [];
    final statements = ref.watch(territoryStatementsProvider).valueOrNull ?? const <SettlementStatement>[];
    final me = managerAccount.id.isEmpty ? null : partyKeyFor(AppRole.manager, managerAccount.id);
    final latest = statements.firstOrNull;
    final owedToMePaise = latest == null || me == null
        ? 0
        : latest.obligations.where((o) => o.to == me && o.outstandingPaise > 0).fold<int>(0, (a, o) => a + o.outstandingPaise);
    final unsettledDays = statements.where((s) => s.status != SettlementStatus.completed).length;
    final incidents = ref.watch(territoryIncidentsProvider).valueOrNull ?? const [];
    final needReview = incidents.where((i) => i.reviewFlags.isNotEmpty).length;

    return Scaffold(
      appBar: AppBar(title: const Text('Manager Dashboard')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (!hasVendor || !hasDriver) _TerritorySetupCard(hasVendor: hasVendor, hasDriver: hasDriver),
          if (!hasVendor || !hasDriver) const SizedBox(height: 20),
          Text(managerAccount.territory ?? '—', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 4),
          Text('Manager code: ${managerAccount.managerCode ?? '—'}', style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w600)),
          const SizedBox(height: 20),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            mainAxisSpacing: 14,
            crossAxisSpacing: 14,
            childAspectRatio: 1.7,
            children: [
              _KpiCard(label: 'My vendors', value: '${vendors.length}', onTap: () => context.go('/manager/vendors')),
              _KpiCard(label: 'Territory vendors', value: '${territoryVendors.length}', onTap: () => context.go('/manager/vendors')),
              _KpiCard(label: 'My orders today', value: '${ordersToday.length}'),
              _KpiCard(label: 'My completed today', value: '${today.orders}'),
              _KpiCard(label: 'My pending orders', value: '${pending.length}'),
              _KpiCard(label: 'My commission today', value: AppFormat.currency(today.earnings)),
              _KpiCard(label: 'Owed to me', value: AppFormat.currency(owedToMePaise / 100)),
              _KpiCard(label: 'My unsettled days', value: '$unsettledDays'),
              _KpiCard(label: 'Cancellations to review', value: '$needReview'),
              _KpiCard(label: 'Active Drivers', value: '$activeDrivers', onTap: () => context.go('/manager/drivers')),
            ],
          ),
          const SizedBox(height: 28),
          Text('Quick actions', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 14),
          _QuickActionsGrid(),
        ],
      ),
    );
  }
}

/// Real progress, not a self-reported checkbox: each row reflects whether
/// this Manager's territory actually has at least one Vendor/Driver in
/// Firestore. Disappears entirely once both are true — no separate
/// "complete" screen to revisit, since there's nothing left to do.
class _TerritorySetupCard extends StatelessWidget {
  const _TerritorySetupCard({required this.hasVendor, required this.hasDriver});
  final bool hasVendor;
  final bool hasDriver;

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    final doneCount = (hasVendor ? 1 : 0) + (hasDriver ? 1 : 0);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: palette.warning.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.hourglass_top_rounded, color: palette.warning),
              const SizedBox(width: 10),
              Expanded(child: Text('Setting up your territory', style: TextStyle(fontWeight: FontWeight.w800, color: palette.textPrimary))),
              Text('$doneCount/2', style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w700, fontSize: 12.5)),
            ],
          ),
          const SizedBox(height: 12),
          _SetupStepRow(
            done: hasVendor,
            label: 'Recruit your first vendor',
            onTap: hasVendor ? null : () => context.push('/manager/vendors/new'),
          ),
          const SizedBox(height: 8),
          _SetupStepRow(
            done: hasDriver,
            label: 'Recruit your first driver',
            onTap: hasDriver ? null : () => context.push('/manager/drivers/new'),
          ),
        ],
      ),
    );
  }
}

class _SetupStepRow extends StatelessWidget {
  const _SetupStepRow({required this.done, required this.label, required this.onTap});
  final bool done;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Row(
          children: [
            Icon(done ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded, color: done ? palette.success : palette.textMuted, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: done ? palette.textSecondary : palette.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  decoration: done ? TextDecoration.lineThrough : null,
                ),
              ),
            ),
            if (!done) Icon(Icons.chevron_right_rounded, color: palette.textMuted, size: 18),
          ],
        ),
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({required this.label, required this.value, this.onTap});
  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    return Material(
      color: palette.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: palette.border)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(value, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: palette.textPrimary), maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 4),
              Text(label, style: TextStyle(fontSize: 12, color: palette.textSecondary)),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickActionsGrid extends StatelessWidget {
  static const _actions = [
    (icon: Icons.receipt_long_rounded, label: 'Settlement History', path: '/manager/settlement/history'),
    (icon: Icons.trending_up_rounded, label: 'Territory Earnings', path: '/manager/reports/earnings'),
    (icon: Icons.local_offer_outlined, label: 'Promotion Approvals', path: '/manager/promotions'),
    (icon: Icons.delivery_dining_rounded, label: 'Order Oversight', path: '/manager/orders'),
    (icon: Icons.support_agent_rounded, label: 'Help & Support', path: '/manager/support'),
  ];

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 2.6,
      children: [
        for (final action in _actions)
          Material(
            color: palette.surface,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => context.push(action.path),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: palette.border)),
                child: Row(
                  children: [
                    Icon(action.icon, color: palette.primary, size: 20),
                    const SizedBox(width: 10),
                    Expanded(child: Text(action.label, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5, color: palette.textPrimary))),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
