import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/order.dart';
import '../../../data/providers/firestore_orders_provider.dart';
import '../../../data/providers/firestore_vendors_provider.dart';
import '../../../shared/widgets/currency_text.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/mock_map_view.dart';
import '../../../shared/widgets/order_status_timestamp.dart';
import '../../../shared/widgets/status_chip.dart';
import '../manager_session.dart';

/// Order Oversight (spec §7.14) — READ-ONLY. A live-looking list/map of
/// active orders in this territory. Deliberately watches
/// `firestoreOrdersProvider` without ever writing to it — Manager never mutates
/// order state, unlike Vendor/Driver.
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
    final palette = context.colors;
    final managerAccount = ref.watch(currentManagerAccountProvider);
    final vendorIds = (ref.watch(firestoreVendorsProvider).valueOrNull ?? const []).where((v) => v.territory == managerAccount.territory).map((v) => v.id).toSet();
    final orders = (ref.watch(firestoreOrdersProvider).valueOrNull ?? const []).where((o) => vendorIds.contains(o.vendorId)).toList()
      ..sort((a, b) => b.placedAt.compareTo(a.placedAt));
    final activeOrders = orders.where((o) => !o.status.isTerminal).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Order Oversight')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          MockMapView(height: 180, showRoute: true, borderRadius: BorderRadius.circular(16)),
          const SizedBox(height: 8),
          Text('Read-only live view of your territory', style: TextStyle(color: palette.textMuted, fontSize: 11.5)),
          const SizedBox(height: 20),
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
