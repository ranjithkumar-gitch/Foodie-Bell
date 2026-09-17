import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/account.dart';
import '../../../data/models/order.dart';
import '../../../data/providers/firestore_orders_provider.dart';
import '../../../data/providers/firestore_settlement_reconciliation_provider.dart';
import '../../../data/providers/firestore_vendors_provider.dart';
import '../../../shared/error_reporting.dart';
import '../../../shared/widgets/currency_text.dart';
import '../../../shared/widgets/empty_state.dart';
import '../manager_constants.dart';
import '../manager_session.dart';

class _VendorSettlement {
  _VendorSettlement({required this.vendor, required this.orders});
  final Account vendor;
  final List<Order> orders;

  double get onlineGmv => orders.where((o) => !o.isCod).fold<double>(0, (sum, o) => sum + o.subtotal);
  double get codGmv => orders.where((o) => o.isCod).fold<double>(0, (sum, o) => sum + o.subtotal);
  double get totalRebate => orders.fold<double>(0, (sum, o) => sum + o.rebateAmount);
  double get managerShare => totalRebate * ManagerConstants.managerRebateSharePercent / 100;
  double get companyShare => totalRebate * ManagerConstants.companyRebateSharePercent / 100;
  bool get needsCashReconciliation => orders.any((o) => o.isCod);
}

bool _isSameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

/// Daily Settlement — 10 PM Reconciliation (spec §7.9): per-vendor breakdown
/// of *today's* online GMV routed, the Manager/Company rebate split, and a
/// cash-collected-by-vendor reconciliation checkbox. The reconciled flag is
/// now real and persisted (`firestoreReconciledSettlementsProvider`, keyed
/// per vendor per calendar day) instead of screen-local `State` that reset
/// on every navigation — a Manager can leave and come back and still see
/// what they already checked off today.
class ManagerDailySettlementScreen extends ConsumerWidget {
  const ManagerDailySettlementScreen({super.key});

  Future<void> _toggleReconciled(BuildContext context, WidgetRef ref, String vendorId, DateTime today, bool wasReconciled, String? managerId) async {
    try {
      await setSettlementReconciled(vendorId, today, reconciled: !wasReconciled, managerId: managerId);
    } catch (e, st) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e, action: 'Updating reconciliation', stackTrace: st))));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.colors;
    final managerAccount = ref.watch(currentManagerAccountProvider);
    final vendors = (ref.watch(firestoreVendorsProvider).valueOrNull ?? const []).where((v) => v.territory == managerAccount.territory).toList();
    final today = DateTime.now();
    final orders = (ref.watch(firestoreOrdersProvider).valueOrNull ?? const []).where((o) => _isSameDay(o.placedAt, today)).toList();
    final reconciledIds = ref.watch(firestoreReconciledSettlementsProvider).valueOrNull ?? const {};

    final settlements = [
      for (final vendor in vendors)
        _VendorSettlement(vendor: vendor, orders: orders.where((o) => o.vendorId == vendor.id && o.status == OrderStatus.delivered).toList()),
    ].where((s) => s.orders.isNotEmpty).toList();

    final totalGmv = settlements.fold<double>(0, (sum, s) => sum + s.onlineGmv + s.codGmv);
    final totalManagerShare = settlements.fold<double>(0, (sum, s) => sum + s.managerShare);
    final totalCompanyShare = settlements.fold<double>(0, (sum, s) => sum + s.companyShare);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Daily Settlement'),
        actions: [
          IconButton(icon: const Icon(Icons.history_rounded), tooltip: 'Settlement history', onPressed: () => context.push('/manager/settlement/history')),
        ],
      ),
      body: settlements.isEmpty
          ? const EmptyState(icon: Icons.receipt_long_outlined, title: 'Nothing to reconcile', subtitle: 'No delivered orders yet today.')
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: palette.surfaceMuted, borderRadius: BorderRadius.circular(16)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('10 PM Reconciliation', style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 4),
                      Text('Rebate split: Manager ${ManagerConstants.managerRebateSharePercent}% · Company ${ManagerConstants.companyRebateSharePercent}%', style: TextStyle(color: palette.textSecondary, fontSize: 12.5)),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(child: _SummaryStat(label: 'Total GMV', value: AppFormat.currency(totalGmv))),
                          Expanded(child: _SummaryStat(label: 'Manager share', value: AppFormat.currency(totalManagerShare))),
                          Expanded(child: _SummaryStat(label: 'Company share', value: AppFormat.currency(totalCompanyShare))),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Text('Per-vendor breakdown', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 12),
                for (final s in settlements)
                  _VendorSettlementCard(
                    settlement: s,
                    reconciled: reconciledIds.contains(reconciliationDocId(s.vendor.id, today)),
                    onToggleReconciled: (wasReconciled) => _toggleReconciled(context, ref, s.vendor.id, today, wasReconciled, managerAccount.id),
                  ),
              ],
            ),
    );
  }
}

class _SummaryStat extends StatelessWidget {
  const _SummaryStat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: palette.textPrimary)),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 11, color: palette.textMuted)),
      ],
    );
  }
}

class _VendorSettlementCard extends StatelessWidget {
  const _VendorSettlementCard({required this.settlement, required this.reconciled, required this.onToggleReconciled});
  final _VendorSettlement settlement;
  final bool reconciled;
  final ValueChanged<bool> onToggleReconciled;

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: palette.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: palette.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(settlement.vendor.name, style: TextStyle(fontWeight: FontWeight.w800, color: palette.textPrimary))),
              Text('${settlement.orders.length} orders', style: TextStyle(color: palette.textMuted, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _MiniStat(label: 'Online GMV', value: AppFormat.currency(settlement.onlineGmv))),
              Expanded(child: _MiniStat(label: 'Manager share', value: AppFormat.currency(settlement.managerShare))),
              Expanded(child: _MiniStat(label: 'Company share', value: AppFormat.currency(settlement.companyShare))),
            ],
          ),
          if (settlement.needsCashReconciliation) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(color: palette.warning.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
              child: Row(
                children: [
                  Icon(Icons.payments_outlined, size: 16, color: palette.warning),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Cash collected by vendor (COD): ${AppFormat.currency(settlement.codGmv)} — needs reconciliation',
                      style: TextStyle(color: palette.warning, fontSize: 11.5, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => onToggleReconciled(reconciled),
            child: Row(
              children: [
                Checkbox(value: reconciled, onChanged: (_) => onToggleReconciled(reconciled)),
                Text(reconciled ? 'Reconciled' : 'Mark as reconciled', style: TextStyle(fontWeight: FontWeight.w700, color: reconciled ? palette.success : palette.textSecondary, fontSize: 12.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: palette.textPrimary)),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 10.5, color: palette.textMuted)),
      ],
    );
  }
}
