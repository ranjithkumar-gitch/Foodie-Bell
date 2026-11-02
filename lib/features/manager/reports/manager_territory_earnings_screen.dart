import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/providers/earnings_provider.dart';
import '../../../data/providers/settlement_provider.dart';
import '../../../shared/widgets/currency_text.dart';
import '../manager_session.dart';

final _weekdayFormat = DateFormat('E');

/// Territory Earnings Report (spec §7.11): the Manager's real commission
/// share over the last 7 settlement days and payback progress towards the
/// territory fee — all from the server's earnings read models
/// (`earnings_daily`, `earnings_totals`). The old "growth scenario"
/// projection applied invented multipliers and was removed (Phase I.2).
class ManagerTerritoryEarningsScreen extends ConsumerStatefulWidget {
  const ManagerTerritoryEarningsScreen({super.key});

  @override
  ConsumerState<ManagerTerritoryEarningsScreen> createState() => _ManagerTerritoryEarningsScreenState();
}

class _ManagerTerritoryEarningsScreenState extends ConsumerState<ManagerTerritoryEarningsScreen> {
  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    final managerAccount = ref.watch(currentManagerAccountProvider);
    // The Manager's share of the commission, all time — what pays back the
    // territory fee — from the server's running total.
    final earnedSoFar = ref.watch(myEarningsTotalsProvider).valueOrNull?.earnings ?? 0;
    final paybackProgress = (earnedSoFar / managerAccount.territoryFee).clamp(0.0, 1.0);

    // Last 7 settlement days (today inclusive), from the server's per-day figures.
    final cutoff = ref.watch(settlementCutoffProvider).valueOrNull ?? 22 * 60;
    final today = DateTime.parse(currentSettlementDay(cutoffMinutes: cutoff));
    final last7Days = [for (var i = 6; i >= 0; i--) today.subtract(Duration(days: i))];
    final days = ref.watch(myEarningsDaysProvider(7)).valueOrNull ?? const <EarningsDay>[];
    final rebateByDay = [
      for (final day in last7Days) days.where((d) => _isSameDay(d.date, day)).fold<double>(0, (sum, d) => sum + d.earnings),
    ];
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
