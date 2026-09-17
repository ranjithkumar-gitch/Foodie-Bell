import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/order.dart';
import '../../../data/providers/firestore_orders_provider.dart';
import '../../../shared/widgets/currency_text.dart';
import '../vendor_session.dart';

const _kWeekdayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

/// Earnings & Settlement (spec §5.15): sums `order.total`/`rebateAmount`
/// across this vendor's delivered orders, a cash-vs-online split
/// (`order.isCod`), rebate deducted per order, and a "download statement"
/// affordance (fake — no file actually leaves the device).
class VendorEarningsScreen extends ConsumerWidget {
  const VendorEarningsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.colors;
    final vendorId = ref.watch(currentVendorIdProvider);
    final delivered = (ref.watch(firestoreOrdersProvider).valueOrNull ?? const [])
        .where((o) => o.vendorId == vendorId && o.status == OrderStatus.delivered)
        .toList();

    final grossEarnings = delivered.fold<double>(0, (sum, o) => sum + o.total);
    final rebateDeducted = delivered.fold<double>(0, (sum, o) => sum + o.rebateAmount);
    final netEarnings = grossEarnings - rebateDeducted;
    final cashTotal = delivered.where((o) => o.isCod).fold<double>(0, (sum, o) => sum + o.total);
    final onlineTotal = delivered.where((o) => !o.isCod).fold<double>(0, (sum, o) => sum + o.total);

    final byWeekday = List<double>.filled(7, 0);
    for (final o in delivered) {
      byWeekday[o.placedAt.weekday - 1] += o.total;
    }
    final maxY = (byWeekday.reduce((a, b) => a > b ? a : b)).clamp(100, double.infinity) * 1.2;

    return Scaffold(
      appBar: AppBar(title: const Text('Earnings & Settlement')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(gradient: LinearGradient(colors: palette.promoGradient), borderRadius: BorderRadius.circular(20)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Net settlement (after rebate)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                CurrencyText(netEarnings, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 34)),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _HeroStat(label: 'Gross earnings', value: grossEarnings),
                    const SizedBox(width: 20),
                    _HeroStat(label: 'Rebate deducted', value: rebateDeducted),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(child: _SplitCard(icon: Icons.payments_rounded, label: 'Cash on Delivery', value: cashTotal)),
              const SizedBox(width: 14),
              Expanded(child: _SplitCard(icon: Icons.qr_code_rounded, label: 'Online (UPI/Card/Wallet)', value: onlineTotal)),
            ],
          ),
          const SizedBox(height: 24),
          Text('Weekly trend', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          SizedBox(
            height: 200,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxY.toDouble(),
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) => Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(_kWeekdayLabels[value.toInt()], style: TextStyle(fontSize: 11, color: palette.textMuted)),
                      ),
                    ),
                  ),
                ),
                barGroups: [
                  for (var i = 0; i < 7; i++)
                    BarChartGroupData(x: i, barRods: [
                      BarChartRodData(toY: byWeekday[i], color: palette.primary, width: 20, borderRadius: BorderRadius.circular(6)),
                    ]),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text('Delivered orders', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          if (delivered.isEmpty)
            Text('No delivered orders yet.', style: TextStyle(color: palette.textMuted))
          else
            for (final order in delivered) _SettlementRow(order: order),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Settlement statement downloaded.'))),
            icon: const Icon(Icons.download_rounded),
            label: const Text('Download statement'),
          ),
        ],
      ),
    );
  }
}

class _HeroStat extends StatelessWidget {
  const _HeroStat({required this.label, required this.value});
  final String label;
  final double value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11.5)),
        const SizedBox(height: 2),
        CurrencyText(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
      ],
    );
  }
}

class _SplitCard extends StatelessWidget {
  const _SplitCard({required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final double value;

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: palette.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: palette.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: palette.primary, size: 20),
          const SizedBox(height: 8),
          CurrencyText(value, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: palette.textPrimary)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 11, color: palette.textSecondary)),
        ],
      ),
    );
  }
}

class _SettlementRow extends StatelessWidget {
  const _SettlementRow({required this.order});
  final Order order;

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: palette.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: palette.border)),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(order.id, style: TextStyle(fontWeight: FontWeight.w700, color: palette.textPrimary)),
                  const SizedBox(height: 2),
                  Text('Rebate ${order.rebatePercent.toStringAsFixed(0)}% · -${AppFormat.currency(order.rebateAmount)}', style: TextStyle(fontSize: 11.5, color: palette.textMuted)),
                ],
              ),
            ),
            CurrencyText(order.total - order.rebateAmount, style: TextStyle(fontWeight: FontWeight.w700, color: palette.primary)),
          ],
        ),
      ),
    );
  }
}
