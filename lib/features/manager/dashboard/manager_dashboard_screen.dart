import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/account.dart';
import '../../../data/models/order.dart';
import '../../../data/providers/firestore_drivers_provider.dart';
import '../../../data/providers/firestore_orders_provider.dart';
import '../../../data/providers/firestore_vendors_provider.dart';
import '../../../shared/widgets/currency_text.dart';
import '../../../shared/widgets/mock_map_view.dart';
import '../manager_session.dart';

/// Manager Dashboard (spec §7.6): territory overview map, active
/// vendors/drivers count, today's GMV, today's rebate pool, and an
/// orders/day trend chart — plus quick-action links into every other
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
    final vendors = (ref.watch(firestoreVendorsProvider).valueOrNull ?? const []).where((v) => v.territory == managerAccount.territory).toList();
    final territoryDrivers = (ref.watch(firestoreDriversProvider).valueOrNull ?? const []).where((d) => d.territory == managerAccount.territory).toList();
    final activeDrivers = territoryDrivers.where((a) => a.status == AccountStatus.active).length;
    final vendorIds = vendors.map((v) => v.id).toSet();
    final hasVendor = vendors.isNotEmpty;
    final hasDriver = territoryDrivers.isNotEmpty;

    // Seed order data has no live "today" concept in a mock app — every
    // seeded order under this territory is treated as today's activity for
    // demo purposes.
    final territoryOrders = (ref.watch(firestoreOrdersProvider).valueOrNull ?? const []).where((o) => vendorIds.contains(o.vendorId)).toList();
    final gmvToday = territoryOrders.fold<double>(0, (sum, o) => sum + o.subtotal);
    final rebatePoolToday = territoryOrders
        .where((o) => o.status == OrderStatus.delivered)
        .fold<double>(0, (sum, o) => sum + o.rebateAmount);

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
          const SizedBox(height: 16),
          MockMapView(height: 180, borderRadius: BorderRadius.circular(16)),
          const SizedBox(height: 20),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            mainAxisSpacing: 14,
            crossAxisSpacing: 14,
            childAspectRatio: 1.7,
            children: [
              _KpiCard(label: 'Active Vendors', value: '${vendors.length}', onTap: () => context.go('/manager/vendors')),
              _KpiCard(label: 'Active Drivers', value: '$activeDrivers', onTap: () => context.go('/manager/drivers')),
              _KpiCard(label: "Today's GMV", value: AppFormat.currency(gmvToday)),
              _KpiCard(label: "Today's Rebate Pool", value: AppFormat.currency(rebatePoolToday)),
            ],
          ),
          const SizedBox(height: 28),
          Text('Orders / day trend (7 days)', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 6),
          Text('Illustrative demo trend', style: TextStyle(color: palette.textMuted, fontSize: 11.5)),
          const SizedBox(height: 16),
          SizedBox(height: 200, child: _OrdersTrendChart(palette: palette)),
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

class _OrdersTrendChart extends StatelessWidget {
  const _OrdersTrendChart({required this.palette});
  final AppPalette palette;

  static const _ordersByDay = [18.0, 24.0, 21.0, 30.0, 27.0, 35.0, 32.0];

  @override
  Widget build(BuildContext context) {
    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: 40,
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(days[value.toInt()], style: TextStyle(fontSize: 11, color: palette.textMuted)),
                );
              },
            ),
          ),
        ),
        barGroups: [
          for (var i = 0; i < _ordersByDay.length; i++)
            BarChartGroupData(x: i, barRods: [
              BarChartRodData(toY: _ordersByDay[i], color: palette.primary, width: 20, borderRadius: BorderRadius.circular(6)),
            ]),
        ],
      ),
    );
  }
}

class _QuickActionsGrid extends StatelessWidget {
  static const _actions = [
    (icon: Icons.receipt_long_rounded, label: 'Settlement History', path: '/manager/settlement/history'),
    (icon: Icons.trending_up_rounded, label: 'Territory Earnings', path: '/manager/reports/earnings'),
    (icon: Icons.campaign_outlined, label: 'Marketing Tracker', path: '/manager/marketing'),
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
