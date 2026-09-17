import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/order.dart';
import '../../../data/providers/firestore_orders_provider.dart';
import '../../../data/providers/firestore_vendors_provider.dart';
import '../../../shared/widgets/currency_text.dart';
import '../manager_session.dart';

enum _Scenario { conservative, moderate, optimistic }

extension on _Scenario {
  String get label => switch (this) {
    _Scenario.conservative => 'Conservative',
    _Scenario.moderate => 'Moderate',
    _Scenario.optimistic => 'Optimistic',
  };

  /// Demo multiplier applied to the *real* last-7-day daily rebate average
  /// to project a monthly figure — the multiplier itself is illustrative
  /// (no real forecasting model), but the run-rate it's applied to is real.
  double get monthlyMultiplier => switch (this) {
    _Scenario.conservative => 22,
    _Scenario.moderate => 28,
    _Scenario.optimistic => 34,
  };
}

final _weekdayFormat = DateFormat('E');

/// Territory Earnings Report (spec §7.11): real rebate income trend,
/// payback progress, and a growth projection — all off delivered orders
/// across this Manager's territory (`firestoreOrdersProvider`, filtered by
/// `firestoreVendorsProvider`'s territory match, same pattern
/// `manager_daily_settlement_screen.dart` uses). Only the Growth Scenario's
/// Conservative/Moderate/Optimistic *multiplier* stays a demo constant — a
/// forward projection is inherently speculative regardless of how real the
/// input is — but that multiplier is now applied to the real 7-day average,
/// not a hardcoded run-rate.
class ManagerTerritoryEarningsScreen extends ConsumerStatefulWidget {
  const ManagerTerritoryEarningsScreen({super.key});

  @override
  ConsumerState<ManagerTerritoryEarningsScreen> createState() => _ManagerTerritoryEarningsScreenState();
}

class _ManagerTerritoryEarningsScreenState extends ConsumerState<ManagerTerritoryEarningsScreen> {
  _Scenario _scenario = _Scenario.moderate;

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    final managerAccount = ref.watch(currentManagerAccountProvider);
    final vendorIds = (ref.watch(firestoreVendorsProvider).valueOrNull ?? const []).where((v) => v.territory == managerAccount.territory).map((v) => v.id).toSet();
    final delivered = (ref.watch(firestoreOrdersProvider).valueOrNull ?? const [])
        .where((o) => vendorIds.contains(o.vendorId) && o.status == OrderStatus.delivered)
        .toList();

    // All-time real rebate captured in this territory — the numerator for
    // payback progress against the one-time territory fee.
    final earnedSoFar = delivered.fold<double>(0, (sum, o) => sum + o.rebateAmount);
    final paybackProgress = (earnedSoFar / managerAccount.territoryFee).clamp(0.0, 1.0);

    // Real last-7-calendar-day rebate trend (today inclusive), each day's
    // total summed from that day's delivered orders.
    final today = DateTime.now();
    final last7Days = [for (var i = 6; i >= 0; i--) DateTime(today.year, today.month, today.day).subtract(Duration(days: i))];
    final rebateByDay = [
      for (final day in last7Days)
        delivered.where((o) => _isSameDay(o.placedAt, day)).fold<double>(0, (sum, o) => sum + o.rebateAmount),
    ];
    final weeklyTotal = rebateByDay.fold<double>(0, (sum, v) => sum + v);
    final projectedMonthly = (weeklyTotal / 7) * _scenario.monthlyMultiplier;
    final chartMaxY = (rebateByDay.isEmpty ? 0.0 : rebateByDay.reduce((a, b) => a > b ? a : b)).clamp(100.0, double.infinity) * 1.2;

    return Scaffold(
      appBar: AppBar(title: const Text('Territory Earnings Report')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('Rebate income trend (7 days)', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          SizedBox(
            height: 200,
            child: LineChart(
              LineChartData(
                minY: 0,
                maxY: chartMaxY,
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
                        final i = value.toInt();
                        if (i < 0 || i >= last7Days.length) return const SizedBox.shrink();
                        return Padding(padding: const EdgeInsets.only(top: 8), child: Text(_weekdayFormat.format(last7Days[i]), style: TextStyle(fontSize: 11, color: palette.textMuted)));
                      },
                    ),
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: [for (var i = 0; i < rebateByDay.length; i++) FlSpot(i.toDouble(), rebateByDay[i])],
                    isCurved: true,
                    color: palette.primary,
                    barWidth: 3,
                    dotData: const FlDotData(show: true),
                    belowBarData: BarAreaData(show: true, color: palette.primary.withValues(alpha: 0.12)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 28),
          Text('Growth scenario', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          Text('Projection multiplier is illustrative — applied to your real 7-day average.', style: TextStyle(color: palette.textMuted, fontSize: 11.5)),
          const SizedBox(height: 12),
          SegmentedButton<_Scenario>(
            segments: [for (final s in _Scenario.values) ButtonSegment(value: s, label: Text(s.label, overflow: TextOverflow.ellipsis))],
            selected: {_scenario},
            showSelectedIcon: false,
            expandedInsets: EdgeInsets.zero,
            onSelectionChanged: (selection) => setState(() => _scenario = selection.first),
            style: const ButtonStyle(
              visualDensity: VisualDensity.compact,
              textStyle: WidgetStatePropertyAll(TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
              padding: WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 8)),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: palette.surfaceMuted, borderRadius: BorderRadius.circular(14)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Projected monthly rebate income (${_scenario.label})', style: TextStyle(color: palette.textSecondary, fontSize: 12.5)),
                const SizedBox(height: 6),
                CurrencyText(projectedMonthly, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 22, color: palette.textPrimary)),
              ],
            ),
          ),
          const SizedBox(height: 28),
          Text('Payback to ${AppFormat.currency(managerAccount.territoryFee)} territory fee', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(value: paybackProgress, minHeight: 12, backgroundColor: palette.surfaceMuted, color: palette.primary),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${(paybackProgress * 100).toStringAsFixed(1)}% recovered', style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w700, fontSize: 12.5)),
              CurrencyText(earnedSoFar, style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w700, fontSize: 12.5)),
            ],
          ),
        ],
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;
}
