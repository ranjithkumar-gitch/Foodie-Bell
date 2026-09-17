import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/session/session_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/order.dart';
import '../../../data/providers/firestore_orders_provider.dart';
import '../../../l10n/app_localizations_context.dart';
import '../../../shared/error_reporting.dart';
import '../../../shared/widgets/currency_text.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/order_status_timestamp.dart';
import '../../../shared/widgets/status_chip.dart';

/// REFERENCE SCREEN — Order History (spec §4.13): a single flat list of
/// every order, most recent first, reading live from `firestoreOrdersProvider`.
/// This is the pattern every other feature screen should imitate: go_router
/// push for navigation, a `context.colors`-driven palette, shared widgets
/// (StatusChip/CurrencyText/EmptyState), and reads scoped to the current
/// session's account id rather than a role-specific copy of order data.
class OrderHistoryScreen extends ConsumerWidget {
  const OrderHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userId = ref.watch(sessionControllerProvider.select((s) => s.account?.id));
    final ordersAsync = ref.watch(firestoreOrdersProvider);

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.myOrdersTitle)),
      body: ordersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text(friendlyError(e, action: 'Loading orders', stackTrace: st))),
        data: (orders) {
          final allOrders = orders.where((o) => o.userId == userId).toList()..sort((a, b) => b.placedAt.compareTo(a.placedAt));
          if (allOrders.isEmpty) {
            return EmptyState(icon: Icons.receipt_long_rounded, title: context.l10n.ordersEmptyTitle, subtitle: context.l10n.ordersEmptySubtitle);
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            itemCount: allOrders.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, i) => _OrderCard(order: allOrders[i]),
          );
        },
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order});

  final Order order;

  StatusTone get _tone => switch (order.status) {
    OrderStatus.delivered => StatusTone.success,
    OrderStatus.cancelled || OrderStatus.rejected => StatusTone.error,
    OrderStatus.placed => StatusTone.info,
    _ => StatusTone.warning,
  };

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => context.push('/user/order/${order.id}'),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: palette.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: palette.border)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(order.vendorName, style: Theme.of(context).textTheme.titleMedium)),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    StatusChip(label: order.status.label, tone: _tone),
                    const SizedBox(height: 3),
                    OrderStatusTimestamp(order.statusReachedAt(order.status)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(context.l10n.orderItemsSummary(order.items.length, order.id), style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                CurrencyText(order.total, style: Theme.of(context).textTheme.titleMedium),
                Icon(Icons.chevron_right_rounded, color: palette.textMuted),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
