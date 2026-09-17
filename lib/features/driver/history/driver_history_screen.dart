import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/order.dart';
import '../../../data/providers/firestore_orders_provider.dart';
import '../../../shared/widgets/currency_text.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/order_status_timestamp.dart';
import '../../../shared/widgets/status_chip.dart';
import '../driver_session.dart';

/// Order History (spec §6 item 14): this driver's completed and cancelled
/// deliveries — everything terminal that was ever assigned to them.
class DriverHistoryScreen extends ConsumerWidget {
  const DriverHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.colors;
    final driver = ref.watch(currentDriverAccountProvider);
    final orders = ref.watch(firestoreOrdersProvider).valueOrNull ?? const [];

    final history = orders.where((o) => o.driverId == driver.id && o.status.isTerminal).toList()
      ..sort((a, b) => b.placedAt.compareTo(a.placedAt));

    return Scaffold(
      appBar: AppBar(title: const Text('Order History')),
      body: history.isEmpty
          ? const EmptyState(icon: Icons.history_rounded, title: 'No past deliveries', subtitle: 'Deliveries you complete or cancel will show up here.')
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              itemCount: history.length,
              separatorBuilder: (context, i) => const SizedBox(height: 12),
              itemBuilder: (context, i) {
                final order = history[i];
                final delivered = order.status == OrderStatus.delivered;
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: palette.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: palette.border)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(child: Text(order.id, style: TextStyle(fontWeight: FontWeight.w800, color: palette.textPrimary))),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              StatusChip(label: order.status.label, tone: delivered ? StatusTone.success : StatusTone.error),
                              const SizedBox(height: 3),
                              OrderStatusTimestamp(order.statusReachedAt(order.status)),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text('${order.vendorName} → ${order.userName}', style: TextStyle(color: palette.textSecondary, fontSize: 12.5)),
                      const SizedBox(height: 2),
                      Text(_formatDate(order.placedAt), style: TextStyle(color: palette.textMuted, fontSize: 11.5)),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Order total', style: TextStyle(color: palette.textSecondary, fontSize: 12.5, fontWeight: FontWeight.w600)),
                          CurrencyText(order.total, style: TextStyle(fontWeight: FontWeight.w800, color: palette.textPrimary, fontSize: 13)),
                        ],
                      ),
                      if (order.isCod) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(order.codPaymentReceived ? Icons.check_circle_rounded : Icons.pending_rounded, size: 14, color: order.codPaymentReceived ? palette.success : palette.warning),
                            const SizedBox(width: 4),
                            Text(order.codPaymentReceived ? 'Cash collected' : 'Cash pending', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: order.codPaymentReceived ? palette.success : palette.warning)),
                          ],
                        ),
                      ],
                      const Padding(padding: EdgeInsets.symmetric(vertical: 10), child: Divider()),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(order.paymentMethod.label, style: TextStyle(color: palette.textSecondary, fontSize: 12.5)),
                          if (delivered)
                            Row(
                              children: [
                                Text('Payout ', style: TextStyle(color: palette.textSecondary, fontSize: 12.5)),
                                CurrencyText(20, style: TextStyle(fontWeight: FontWeight.w800, color: palette.success)),
                              ],
                            )
                          else
                            Text(order.cancelReason ?? 'Cancelled', style: TextStyle(color: palette.error, fontSize: 12.5, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }

  String _formatDate(DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year} · ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}
