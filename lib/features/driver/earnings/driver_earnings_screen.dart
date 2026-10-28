import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/order.dart';
import '../../../data/providers/earnings_provider.dart';
import '../../../data/providers/firestore_orders_provider.dart';
import '../../../data/providers/settlement_provider.dart';
import '../../../shared/widgets/currency_text.dart';
import '../../../shared/widgets/empty_state.dart';
import '../driver_session.dart';
import '../home/driver_home_screen.dart';

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

enum _Period { today, week, month }

extension on _Period {
  String get label => switch (this) {
    _Period.today => 'Today',
    _Period.week => 'This week',
    _Period.month => 'This month',
  };
}

/// When a delivered order actually counts toward earnings — the moment it
/// was delivered, falling back to when it was placed for older orders from
/// before status timestamps were recorded.
DateTime _deliveredAt(Order o) => o.statusReachedAt(OrderStatus.delivered) ?? o.placedAt;

DateTime _dayOf(DateTime d) => DateTime(d.year, d.month, d.day);

/// Earnings Dashboard (spec §6 item 13), laid out like the Swiggy/Zomato
/// partner apps: a Today / This week / This month switch over one big
/// earnings figure (with deliveries and cash collected), a last-7-days
/// earnings chart, weekly payouts, and every delivery grouped by day. The
/// figures are the server's per-day totals (`earnings_daily`, one document
/// per settlement day — "today" is the settlement day, as on the daily
/// statement); the delivery list is read a page at a time.
class DriverEarningsScreen extends ConsumerStatefulWidget {
  const DriverEarningsScreen({super.key});

  @override
  ConsumerState<DriverEarningsScreen> createState() => _DriverEarningsScreenState();
}

class _DriverEarningsScreenState extends ConsumerState<DriverEarningsScreen> {
  static const _weeksOfHistory = 4;

  _Period _period = _Period.today;

  List<({String period, double amount, int count})> _weeklyHistory(List<EarningsDay> days, DateTime now) {
    final thisMonday = _dayOf(now).subtract(Duration(days: now.weekday - 1));
    String label(DateTime d) => '${d.day} ${_months[d.month - 1]}';
    return [
      for (var w = 0; w < _weeksOfHistory; w++)
        () {
          final weekStart = thisMonday.subtract(Duration(days: 7 * w));
          final weekEnd = weekStart.add(const Duration(days: 7));
          final inWeek = days.where((d) => !d.date.isBefore(weekStart) && d.date.isBefore(weekEnd));
          final count = inWeek.fold<int>(0, (s, d) => s + d.orders);
          final period = w == 0 ? 'This week' : '${label(weekStart)} – ${label(weekEnd.subtract(const Duration(days: 1)))}';
          return (period: period, amount: inWeek.fold<double>(0, (s, d) => s + d.earnings), count: count);
        }(),
    ].where((w) => w.count > 0 || w.period == 'This week').toList();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    final driver = ref.watch(currentDriverAccountProvider);
    // Six weeks of per-day totals covers the month, the 7-day chart and the
    // weekly payouts.
    final days = ref.watch(myEarningsDaysProvider(42)).valueOrNull ?? const <EarningsDay>[];
    final cutoff = ref.watch(settlementCutoffProvider).valueOrNull ?? 22 * 60;
    final today = DateTime.parse(currentSettlementDay(cutoffMinutes: cutoff));
    final now = today;

    final periodStart = switch (_period) {
      _Period.today => today,
      _Period.week => today.subtract(Duration(days: now.weekday - 1)),
      _Period.month => DateTime(now.year, now.month),
    };
    final inPeriod = days.where((d) => !d.date.isBefore(periodStart)).toList();
    final periodEarnings = inPeriod.fold<double>(0, (s, d) => s + d.earnings);
    final periodDeliveries = inPeriod.fold<int>(0, (s, d) => s + d.orders);
    // The cash actually recorded on COD deliveries. It is owed to the
    // Manager in full; the delivery fee comes back in settlement.
    final cashCollected = inPeriod.fold<double>(0, (s, d) => s + d.codCollected);

    // Last 7 days, oldest → today, for the chart.
    final byDate = {for (final d in days) d.date: d};
    final last7 = [
      for (var i = 6; i >= 0; i--)
        () {
          final day = today.subtract(Duration(days: i));
          return (day: day, amount: byDate[day]?.earnings ?? 0.0);
        }(),
    ];

    final payoutHistory = _weeklyHistory(days, now);

    // Every delivery, newest first, a page at a time, grouped under a day header.
    final history = ref.watch(orderHistoryProvider(OrderHistoryFilter.delivered));
    final delivered = [
      for (final o in history.orders)
        if (o.driverId == driver.id) o,
    ]..sort((a, b) => _deliveredAt(b).compareTo(_deliveredAt(a)));
    final byDay = <DateTime, List<Order>>{};
    for (final o in delivered) {
      byDay.putIfAbsent(_dayOf(_deliveredAt(o)), () => []).add(o);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Earnings'),
        actions: [IconButton(icon: const Icon(Icons.account_balance_wallet_outlined), tooltip: 'Settlement payments', onPressed: () => context.push('/driver/settlement-payments'))],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        children: [
          SegmentedButton<_Period>(
            segments: [for (final p in _Period.values) ButtonSegment(value: p, label: Text(p.label))],
            selected: {_period},
            showSelectedIcon: false,
            onSelectionChanged: (s) => setState(() => _period = s.first),
            style: ButtonStyle(
              textStyle: const WidgetStatePropertyAll(TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
              visualDensity: VisualDensity.compact,
            ),
          ),
          const SizedBox(height: 16),
          _HeroEarnings(
            periodLabel: _period.label,
            amount: periodEarnings,
            deliveries: periodDeliveries,
            cashCollected: cashCollected,
          ),
          const SizedBox(height: 22),
          Text('Last 7 days', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w500)),
          const SizedBox(height: 12),
          _Last7DaysChart(days: last7),
          const SizedBox(height: 24),
          Text('Weekly payouts', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w500)),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: palette.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: palette.border),
            ),
            child: Column(
              children: [
                for (var i = 0; i < payoutHistory.length; i++) ...[
                  if (i > 0) Divider(height: 1, color: palette.divider),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    child: Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: palette.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(Icons.account_balance_wallet_rounded, color: palette.primary, size: 19),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                payoutHistory[i].period,
                                style: TextStyle(fontWeight: FontWeight.w500, color: palette.textPrimary),
                              ),
                              Text(
                                '${payoutHistory[i].count} ${payoutHistory[i].count == 1 ? 'delivery' : 'deliveries'}',
                                style: TextStyle(color: palette.textSecondary, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        CurrencyText(
                          payoutHistory[i].amount,
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: palette.textPrimary),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text('Delivery breakdown', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w500)),
          const SizedBox(height: 12),
          if (delivered.isEmpty && history.loading)
            const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()))
          else if (delivered.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: EmptyState(
                icon: Icons.payments_outlined,
                title: 'No deliveries yet',
                subtitle: 'Completed deliveries will show up here with their payout.',
              ),
            )
          else
            for (final entry in byDay.entries) ...[
              _DayHeader(
                day: entry.key,
                today: today,
                total: driverEarningsOf(entry.value),
                count: entry.value.length,
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: palette.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: palette.border),
                ),
                child: Column(
                  children: [
                    for (var i = 0; i < entry.value.length; i++) ...[
                      if (i > 0) Divider(height: 1, indent: 16, endIndent: 16, color: palette.divider),
                      _DeliveryRow(order: entry.value[i]),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
          if (history.hasMore && delivered.isNotEmpty)
            Center(
              child: OutlinedButton(
                onPressed: history.loading
                    ? null
                    : () => ref.read(orderHistoryProvider(OrderHistoryFilter.delivered).notifier).loadMore(),
                child: Text(history.loading ? 'Loading…' : 'Show more deliveries'),
              ),
            ),
        ],
      ),
    );
  }
}

/// The selected period's earnings as one big figure, with its delivery
/// count, cash collected on COD orders, and the per-delivery rate.
class _HeroEarnings extends StatelessWidget {
  const _HeroEarnings({
    required this.periodLabel,
    required this.amount,
    required this.deliveries,
    required this.cashCollected,
  });

  final String periodLabel;
  final double amount;
  final int deliveries;
  final double cashCollected;

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: palette.promoGradient, begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "$periodLabel's earnings",
            style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontWeight: FontWeight.w500, fontSize: 13),
          ),
          const SizedBox(height: 4),
          CurrencyText(
            amount,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 34, height: 1.15),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _HeroStat(icon: Icons.inventory_2_rounded, value: '$deliveries', label: deliveries == 1 ? 'Delivery' : 'Deliveries'),
              _HeroStat(icon: Icons.payments_rounded, value: AppFormat.currency(cashCollected), label: 'Cash collected'),
              _HeroStat(icon: Icons.sell_rounded, value: deliveries == 0 ? '—' : AppFormat.currency(amount / deliveries), label: 'Avg per delivery'),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroStat extends StatelessWidget {
  const _HeroStat({required this.icon, required this.value, required this.label});
  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 17, color: Colors.white.withValues(alpha: 0.85)),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14.5),
          ),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 11),
          ),
        ],
      ),
    );
  }
}

/// Daily earnings for the last 7 days — one series in the brand colour, so
/// no legend (the heading names it); thin bars with rounded tops on the
/// baseline, faint horizontal gridlines only, axis text in text colours,
/// and the exact figure on tap.
class _Last7DaysChart extends StatelessWidget {
  const _Last7DaysChart({required this.days});
  final List<({DateTime day, double amount})> days;

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    final peak = days.fold<double>(0, (m, d) => d.amount > m ? d.amount : m);
    // A round ceiling a little above the best day (never below ₹100 so an
    // all-zero week still draws a sensible empty frame).
    final step = peak <= 100 ? 25.0 : peak <= 300 ? 50.0 : 100.0;
    final maxY = peak <= 100 ? 100.0 : ((peak / step).ceil() + 1) * step;
    final total = days.fold<double>(0, (s, d) => s + d.amount);

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 16, 16, 10),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 12),
            child: Row(
              children: [
                Text('Total ', style: TextStyle(color: palette.textSecondary, fontSize: 12.5)),
                CurrencyText(total, style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
              ],
            ),
          ),
          SizedBox(
            height: 160,
            child: BarChart(
              BarChartData(
                maxY: maxY,
                minY: 0,
                alignment: BarChartAlignment.spaceAround,
                borderData: FlBorderData(show: false),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: step,
                  getDrawingHorizontalLine: (_) => FlLine(color: palette.divider, strokeWidth: 1),
                ),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      interval: step,
                      getTitlesWidget: (value, meta) => SideTitleWidget(
                        axisSide: meta.axisSide,
                        child: Text('₹${value.toInt()}', style: TextStyle(color: palette.textMuted, fontSize: 10.5)),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 26,
                      getTitlesWidget: (value, meta) {
                        final i = value.toInt();
                        if (i < 0 || i >= days.length) return const SizedBox.shrink();
                        final isToday = i == days.length - 1;
                        return SideTitleWidget(
                          axisSide: meta.axisSide,
                          child: Text(
                            isToday ? 'Today' : _weekdays[days[i].day.weekday - 1],
                            style: TextStyle(
                              color: isToday ? palette.textPrimary : palette.textMuted,
                              fontSize: 11,
                              fontWeight: isToday ? FontWeight.w600 : FontWeight.w500,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => palette.textPrimary,
                    tooltipRoundedRadius: 8,
                    tooltipPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final d = days[group.x].day;
                      return BarTooltipItem(
                        '${d.day} ${_months[d.month - 1]}\n',
                        TextStyle(color: palette.surface, fontSize: 11),
                        children: [
                          TextSpan(
                            text: AppFormat.currency(rod.toY),
                            style: TextStyle(color: palette.surface, fontWeight: FontWeight.w700, fontSize: 13),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                barGroups: [
                  for (var i = 0; i < days.length; i++)
                    BarChartGroupData(
                      x: i,
                      barRods: [
                        BarChartRodData(
                          toY: days[i].amount,
                          width: 16,
                          color: palette.primary,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DayHeader extends StatelessWidget {
  const _DayHeader({required this.day, required this.today, required this.total, required this.count});
  final DateTime day;
  final DateTime today;
  final double total;
  final int count;

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    final diff = today.difference(day).inDays;
    final label = diff == 0
        ? 'Today'
        : diff == 1
        ? 'Yesterday'
        : '${_weekdays[day.weekday - 1]}, ${day.day} ${_months[day.month - 1]}';
    return Row(
      children: [
        Text(label, style: TextStyle(fontWeight: FontWeight.w500, color: palette.textPrimary, fontSize: 13.5)),
        const SizedBox(width: 6),
        Text('· $count', style: TextStyle(color: palette.textMuted, fontSize: 12.5)),
        const Spacer(),
        CurrencyText(total, style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w500, fontSize: 13)),
      ],
    );
  }
}

class _DeliveryRow extends StatelessWidget {
  const _DeliveryRow({required this.order});
  final Order order;

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    final at = _deliveredAt(order);
    final hour = at.hour % 12 == 0 ? 12 : at.hour % 12;
    final time = '$hour:${at.minute.toString().padLeft(2, '0')} ${at.hour < 12 ? 'AM' : 'PM'}';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(color: palette.success.withValues(alpha: 0.12), shape: BoxShape.circle),
            child: Icon(Icons.check_rounded, size: 18, color: palette.success),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  order.vendorName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontWeight: FontWeight.w500, color: palette.textPrimary),
                ),
                Text(
                  '#${order.id} · $time${order.isCod ? ' · Cash' : ''}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: palette.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
          CurrencyText(
            driverEarningOf(order),
            style: TextStyle(fontWeight: FontWeight.w600, color: palette.success),
          ),
        ],
      ),
    );
  }
}
