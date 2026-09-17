import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/order.dart';
import '../../../data/providers/firestore_orders_provider.dart';
import '../../../data/providers/firestore_vendors_provider.dart';
import '../../../shared/widgets/currency_text.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/status_chip.dart';
import '../manager_session.dart';

final _dateFormat = DateFormat('d MMM yyyy');

class _DailyTotals {
  double gmv = 0;
  double rebate = 0;
}

/// Settlement History / Statements (spec §7.10) — one row per day with
/// delivered orders across this Manager's territory, real GMV/rebate totals
/// off `firestoreOrdersProvider` (same vendor-by-territory filter
/// `manager_daily_settlement_screen.dart` uses for the live 10 PM
/// reconciliation). A day counts as Settled once it's fully in the past —
/// there's no separate persisted "reconciled" flag per historical day, so
/// today's still-accumulating total reads as Pending until it ends. The
/// "export" button stays a fake no-op (confirmation snackbar) since there's
/// no real backend to generate a file against.
class ManagerSettlementHistoryScreen extends ConsumerWidget {
  const ManagerSettlementHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final managerAccount = ref.watch(currentManagerAccountProvider);
    final vendorIds = (ref.watch(firestoreVendorsProvider).valueOrNull ?? const [])
        .where((v) => v.territory == managerAccount.territory)
        .map((v) => v.id)
        .toSet();
    final delivered = (ref.watch(firestoreOrdersProvider).valueOrNull ?? const [])
        .where((o) => vendorIds.contains(o.vendorId) && o.status == OrderStatus.delivered)
        .toList();

    final byDate = <DateTime, _DailyTotals>{};
    for (final o in delivered) {
      final day = DateTime(o.placedAt.year, o.placedAt.month, o.placedAt.day);
      final totals = byDate.putIfAbsent(day, () => _DailyTotals());
      totals.gmv += o.subtotal;
      totals.rebate += o.rebateAmount;
    }
    final today = DateTime.now();
    final todayKey = DateTime(today.year, today.month, today.day);
    final dates = byDate.keys.toList()..sort((a, b) => b.compareTo(a));

    return Scaffold(
      appBar: AppBar(title: const Text('Settlement History')),
      body: dates.isEmpty
          ? const EmptyState(icon: Icons.receipt_long_outlined, title: 'No settlements yet', subtitle: 'Delivered orders across your territory will show up here once you have some.')
          : ListView.separated(
              padding: const EdgeInsets.all(20),
              itemCount: dates.length,
              separatorBuilder: (context, _) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final date = dates[i];
                final totals = byDate[date]!;
                return _StatementRow(dateLabel: _dateFormat.format(date), gmv: totals.gmv, rebate: totals.rebate, settled: date.isBefore(todayKey));
              },
            ),
    );
  }
}

class _StatementRow extends StatelessWidget {
  const _StatementRow({required this.dateLabel, required this.gmv, required this.rebate, required this.settled});
  final String dateLabel;
  final double gmv;
  final double rebate;
  final bool settled;

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: palette.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: palette.border)),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(color: palette.primaryLight.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(12)),
            child: Icon(Icons.description_outlined, color: palette.primary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(dateLabel, style: TextStyle(fontWeight: FontWeight.w700, color: palette.textPrimary)),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Text('GMV ', style: TextStyle(fontSize: 12, color: palette.textMuted)),
                    CurrencyText(gmv, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: palette.textSecondary)),
                    Text('  ·  Rebate ', style: TextStyle(fontSize: 12, color: palette.textMuted)),
                    CurrencyText(rebate, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: palette.textSecondary)),
                  ],
                ),
              ],
            ),
          ),
          StatusChip(label: settled ? 'SETTLED' : 'PENDING', tone: settled ? StatusTone.success : StatusTone.warning),
          const SizedBox(width: 8),
          IconButton(
            icon: Icon(Icons.ios_share_rounded, color: palette.textSecondary, size: 20),
            tooltip: 'Export',
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Exported statement for $dateLabel (demo).')),
            ),
          ),
        ],
      ),
    );
  }
}
