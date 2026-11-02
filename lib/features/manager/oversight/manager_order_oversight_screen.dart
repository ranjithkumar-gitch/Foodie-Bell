import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'reassign_driver_sheet.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/order.dart';
import '../../../data/providers/firestore_orders_provider.dart';
import '../../../shared/widgets/currency_text.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/order_status_timestamp.dart';
import '../../../shared/widgets/status_chip.dart';

/// Order Oversight (spec §7.14): this territory's orders, in-progress ones
/// live. The Manager writes nothing here directly; the one action is moving
/// a waiting delivery to another Driver (or releasing it) through the
/// server's `reassignDriver` ([ReassignDriverSheet]).
class ManagerOrderOversightScreen extends ConsumerWidget {
  const ManagerOrderOversightScreen({super.key});

  static ({String label, StatusTone tone}) _statusMeta(OrderStatus status) => switch (status) {
    OrderStatus.placed => (label: 'PLACED', tone: StatusTone.info),
    OrderStatus.vendorAccepted => (label: 'VENDOR ACCEPTED', tone: StatusTone.info),
    OrderStatus.driverAssigned => (label: 'DRIVER ASSIGNED', tone: StatusTone.warning),
    OrderStatus.pickedUp => (label: 'PICKED UP', tone: StatusTone.warning),
    OrderStatus.delivered => (label: 'DELIVERED', tone: StatusTone.success),
    OrderStatus.cancelled => (label: 'CANCELLED', tone: StatusTone.error),
    OrderStatus.rejected => (label: 'REJECTED', tone: StatusTone.error),
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // In-progress orders live (queried by territory ID); finished ones a
    // page at a time, newest first.
    final activeOrders = (ref.watch(activeOrdersProvider).valueOrNull ?? const <Order>[]).toList()
      ..sort((a, b) => b.placedAt.compareTo(a.placedAt));
    final history = ref.watch(orderHistoryProvider(OrderHistoryFilter.finished));
    final orders = [...activeOrders, ...history.orders.where((o) => o.status.isTerminal)];

    return Scaffold(
      appBar: AppBar(title: const Text('Order Oversight')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Active orders (${activeOrders.length})', style: Theme.of(context).textTheme.titleLarge),
            ],
          ),
          const SizedBox(height: 12),
          if (orders.isEmpty)
            const EmptyState(icon: Icons.delivery_dining_outlined, title: 'No orders yet', subtitle: 'Orders from vendors in your territory will show up here.')
          else
            for (final order in orders) _OrderTile(order: order, meta: _statusMeta(order.status)),
          if (history.hasMore && orders.isNotEmpty)
            Center(
              child: OutlinedButton(
                onPressed: history.loading
                    ? null
                    : () => ref.read(orderHistoryProvider(OrderHistoryFilter.finished).notifier).loadMore(),
                child: Text(history.loading ? 'Loading…' : 'Show older orders'),
              ),
            ),
        ],
      ),
    );
  }
}

class _OrderTile extends StatelessWidget {
  const _OrderTile({required this.order, required this.meta});
  final Order order;
  final ({String label, StatusTone tone}) meta;

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: palette.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: palette.border)),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: palette.primaryLight.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(10)),
            child: Icon(Icons.receipt_long_rounded, color: palette.primary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${order.id} · ${order.vendorName}', style: TextStyle(fontWeight: FontWeight.w700, color: palette.textPrimary)),
                const SizedBox(height: 3),
                Text(order.driverName == null ? 'No driver assigned yet' : 'Driver: ${order.driverName}', style: TextStyle(fontSize: 12, color: palette.textMuted)),
                if (canReassignDriver(order))
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () => showReassignDriverSheet(context, order),
                      style: TextButton.styleFrom(padding: EdgeInsets.zero, visualDensity: VisualDensity.compact),
                      icon: const Icon(Icons.swap_horiz_rounded, size: 18),
                      label: const Text('Reassign driver'),
                    ),
                  ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              CurrencyText(order.total, style: TextStyle(fontWeight: FontWeight.w800, color: palette.textPrimary, fontSize: 13)),
              const SizedBox(height: 6),
              StatusChip(label: meta.label, tone: meta.tone),
              const SizedBox(height: 3),
              OrderStatusTimestamp(order.statusReachedAt(order.status)),
            ],
          ),
        ],
      ),
    );
  }
}
