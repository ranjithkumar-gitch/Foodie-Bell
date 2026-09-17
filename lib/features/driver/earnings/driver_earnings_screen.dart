import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/order.dart';
import '../../../data/providers/firestore_orders_provider.dart';
import '../../../shared/widgets/currency_text.dart';
import '../../../shared/widgets/empty_state.dart';
import '../driver_session.dart';
import '../home/driver_home_screen.dart';

/// Earnings Dashboard (spec §6 item 13): a flat ₹20/delivery breakdown,
/// daily/weekly/monthly totals, and a weekly payout history — all derived
/// from this driver's own real delivered orders (`firestoreOrdersProvider`),
/// not fabricated demo rows. There's no real settlement backend to mark a
/// week "Paid" vs pending against, so each row shows what's actually
/// derivable — the period and how many deliveries/how much it adds up to —
/// rather than inventing a payout status nothing in this app tracks.
class DriverEarningsScreen extends ConsumerWidget {
  const DriverEarningsScreen({super.key});

  static const _weeksOfHistory = 4;

  List<({String period, double amount, int count})> _weeklyHistory(List<Order> delivered, DateTime now) {
    final thisMonday = DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday - 1));
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    String label(DateTime d) => '${d.day} ${months[d.month - 1]}';

    return [
      for (var w = 0; w < _weeksOfHistory; w++)
        () {
          final weekStart = thisMonday.subtract(Duration(days: 7 * w));
          final weekEnd = weekStart.add(const Duration(days: 7));
          final count = delivered.where((o) => !o.placedAt.isBefore(weekStart) && o.placedAt.isBefore(weekEnd)).length;
          final period = w == 0 ? 'This week' : 'Week of ${label(weekStart)} – ${label(weekEnd.subtract(const Duration(days: 1)))}';
          return (period: period, amount: count * kDriverFlatPayout, count: count);
        }(),
    ].where((w) => w.count > 0 || w.period == 'This week').toList();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.colors;
    final driver = ref.watch(currentDriverAccountProvider);
    final orders = ref.watch(firestoreOrdersProvider).valueOrNull ?? const [];
    final now = DateTime.now();
    final startOfWeek = DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday - 1));

    final delivered = orders.where((o) => o.driverId == driver.id && o.status == OrderStatus.delivered).toList()
      ..sort((a, b) => b.placedAt.compareTo(a.placedAt));

    final todayCount = delivered.where((o) => o.placedAt.year == now.year && o.placedAt.month == now.month && o.placedAt.day == now.day).length;
    final weekCount = delivered.where((o) => !o.placedAt.isBefore(startOfWeek)).length;
    final monthCount = delivered.where((o) => o.placedAt.year == now.year && o.placedAt.month == now.month).length;
    final payoutHistory = _weeklyHistory(delivered, now);

    return Scaffold(
      appBar: AppBar(title: const Text('Earnings')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: [
          Row(
            children: [
              Expanded(child: _TotalCard(label: 'Today', count: todayCount)),
              const SizedBox(width: 12),
              Expanded(child: _TotalCard(label: 'This week', count: weekCount)),
              const SizedBox(width: 12),
              Expanded(child: _TotalCard(label: 'This month', count: monthCount)),
            ],
          ),
          const SizedBox(height: 24),
          Text('Payout history', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(color: palette.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: palette.border)),
            child: Column(
              children: [
                for (var i = 0; i < payoutHistory.length; i++) ...[
                  if (i > 0) Divider(height: 1, color: palette.divider),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    child: Row(
                      children: [
                        Icon(Icons.account_balance_wallet_rounded, color: palette.primary, size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(payoutHistory[i].period, style: TextStyle(fontWeight: FontWeight.w700, color: palette.textPrimary)),
                              Text(
                                '${payoutHistory[i].count} ${payoutHistory[i].count == 1 ? 'delivery' : 'deliveries'}',
                                style: TextStyle(color: palette.textSecondary, fontSize: 12, fontWeight: FontWeight.w700),
                              ),
                            ],
                          ),
                        ),
                        CurrencyText(payoutHistory[i].amount, style: TextStyle(fontWeight: FontWeight.w800, color: palette.textPrimary)),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text('Delivery breakdown', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 12),
          if (delivered.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 20),
              child: EmptyState(icon: Icons.payments_outlined, title: 'No deliveries yet', subtitle: 'Completed deliveries will show up here with their payout.'),
            )
          else
            Container(
              decoration: BoxDecoration(color: palette.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: palette.border)),
              child: Column(
                children: [
                  for (var i = 0; i < delivered.length; i++) ...[
                    if (i > 0) Divider(height: 1, color: palette.divider),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(delivered[i].id, style: TextStyle(fontWeight: FontWeight.w700, color: palette.textPrimary)),
                                Text('${delivered[i].vendorName} · ${_formatDate(delivered[i].placedAt)}', style: TextStyle(color: palette.textSecondary, fontSize: 12)),
                              ],
                            ),
                          ),
                          CurrencyText(kDriverFlatPayout, style: TextStyle(fontWeight: FontWeight.w800, color: palette.success)),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  String _formatDate(DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}

class _TotalCard extends StatelessWidget {
  const _TotalCard({required this.label, required this.count});
  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(color: palette.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: palette.border)),
      child: Column(
        children: [
          CurrencyText(count * kDriverFlatPayout, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: palette.textPrimary)),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(color: palette.textSecondary, fontSize: 11.5, fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text('$count deliveries', style: TextStyle(color: palette.textMuted, fontSize: 10.5)),
        ],
      ),
    );
  }
}
