import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/order.dart';
import '../../../data/providers/firestore_orders_provider.dart';
import '../../../shared/widgets/currency_text.dart';
import '../../../shared/widgets/empty_state.dart';
import '../driver_session.dart';
import '../home/driver_home_screen.dart';

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

enum _Filter { all, delivered, cancelled }

/// When the order finished (delivered / cancelled / rejected), falling back
/// to when it was placed for older orders without status timestamps.
DateTime _finishedAt(Order o) => o.statusReachedAt(o.status) ?? o.placedAt;

DateTime _dayOf(DateTime d) => DateTime(d.year, d.month, d.day);

String _time(DateTime d) {
  final hour = d.hour % 12 == 0 ? 12 : d.hour % 12;
  return '$hour:${d.minute.toString().padLeft(2, '0')} ${d.hour < 12 ? 'AM' : 'PM'}';
}

/// Order History (spec §6 item 14): this driver's completed and cancelled
/// deliveries — everything terminal that was ever assigned to them — with
/// a delivered / cancelled / success-rate summary, All / Delivered /
/// Cancelled filter chips, and the orders grouped by day.
class DriverHistoryScreen extends ConsumerStatefulWidget {
  const DriverHistoryScreen({super.key});

  @override
  ConsumerState<DriverHistoryScreen> createState() => _DriverHistoryScreenState();
}

class _DriverHistoryScreenState extends ConsumerState<DriverHistoryScreen> {
  _Filter _filter = _Filter.all;

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    final driver = ref.watch(currentDriverAccountProvider);
    final orders = ref.watch(firestoreOrdersProvider).valueOrNull ?? const [];

    final history = orders.where((o) => o.driverId == driver.id && o.status.isTerminal).toList()
      ..sort((a, b) => _finishedAt(b).compareTo(_finishedAt(a)));
    final deliveredCount = history.where((o) => o.status == OrderStatus.delivered).length;
    final cancelledCount = history.length - deliveredCount;
    final successRate = history.isEmpty ? null : (deliveredCount / history.length * 100).round();

    final visible = switch (_filter) {
      _Filter.all => history,
      _Filter.delivered => history.where((o) => o.status == OrderStatus.delivered).toList(),
      _Filter.cancelled => history.where((o) => o.status != OrderStatus.delivered).toList(),
    };
    final byDay = <DateTime, List<Order>>{};
    for (final o in visible) {
      byDay.putIfAbsent(_dayOf(_finishedAt(o)), () => []).add(o);
    }
    final today = _dayOf(DateTime.now());

    return Scaffold(
      appBar: AppBar(title: const Text('Order History')),
      body: history.isEmpty
          ? const EmptyState(
              icon: Icons.history_rounded,
              title: 'No past deliveries',
              subtitle: 'Deliveries you complete or cancel will show up here.',
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: palette.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: palette.border),
                  ),
                  child: Row(
                    children: [
                      _SummaryStat(value: '$deliveredCount', label: 'Delivered', color: palette.success),
                      Container(width: 1, height: 34, color: palette.divider),
                      _SummaryStat(value: '$cancelledCount', label: 'Cancelled', color: palette.error),
                      Container(width: 1, height: 34, color: palette.divider),
                      _SummaryStat(
                        value: successRate == null ? '—' : '$successRate%',
                        label: 'Success rate',
                        color: palette.primary,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final f in _Filter.values)
                      ChoiceChip(
                        label: Text(
                          switch (f) {
                            _Filter.all => 'All (${history.length})',
                            _Filter.delivered => 'Delivered ($deliveredCount)',
                            _Filter.cancelled => 'Cancelled ($cancelledCount)',
                          },
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                        selected: _filter == f,
                        showCheckmark: false,
                        onSelected: (_) => setState(() => _filter = f),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                if (visible.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 40),
                    child: Center(
                      child: Text(
                        'Nothing here yet.',
                        style: TextStyle(color: palette.textSecondary),
                      ),
                    ),
                  )
                else
                  for (final entry in byDay.entries) ...[
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        _dayLabel(entry.key, today),
                        style: TextStyle(fontWeight: FontWeight.w500, color: palette.textSecondary, fontSize: 13),
                      ),
                    ),
                    for (final order in entry.value) ...[
                      _HistoryCard(order: order),
                      const SizedBox(height: 10),
                    ],
                    const SizedBox(height: 8),
                  ],
              ],
            ),
    );
  }

  String _dayLabel(DateTime day, DateTime today) {
    final diff = today.difference(day).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    return '${_weekdays[day.weekday - 1]}, ${day.day} ${_months[day.month - 1]} ${day.year}';
  }
}

class _SummaryStat extends StatelessWidget {
  const _SummaryStat({required this.value, required this.label, required this.color});
  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    return Expanded(
      child: Column(
        children: [
          Text(value, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18, color: color)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(color: palette.textSecondary, fontSize: 11.5, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

/// One finished delivery: a status badge, the order id and time, the
/// vendor → customer route, how it was paid, and the payout (delivered) or
/// the cancel reason.
class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.order});
  final Order order;

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    final delivered = order.status == OrderStatus.delivered;
    final tone = delivered ? palette.success : palette.error;
    final itemCount = order.items.fold<int>(0, (sum, i) => sum + i.quantity);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(color: tone.withValues(alpha: 0.12), shape: BoxShape.circle),
                child: Icon(delivered ? Icons.check_rounded : Icons.close_rounded, size: 19, color: tone),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '#${order.id}',
                      style: TextStyle(fontWeight: FontWeight.w500, color: palette.textPrimary),
                    ),
                    Text(
                      '${order.status.label} · ${_time(_finishedAt(order))}',
                      style: TextStyle(color: tone, fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
              if (delivered)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    CurrencyText(
                      kDriverFlatPayout,
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: palette.success),
                    ),
                    Text('Payout', style: TextStyle(color: palette.textMuted, fontSize: 11)),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 12),
          _RouteLine(
            icon: Icons.storefront_rounded,
            color: Colors.deepOrange,
            text: order.vendorName,
          ),
          Padding(
            padding: const EdgeInsets.only(left: 9),
            child: Container(width: 2, height: 10, color: palette.border),
          ),
          _RouteLine(
            icon: Icons.home_rounded,
            color: const Color(0xFF2E7D32),
            text: '${order.userName} · ${order.deliveryAddressLabel}',
          ),
          const Padding(padding: EdgeInsets.symmetric(vertical: 10), child: Divider(height: 1)),
          Row(
            children: [
              Icon(Icons.shopping_bag_outlined, size: 15, color: palette.textMuted),
              const SizedBox(width: 4),
              Text(
                '$itemCount item${itemCount == 1 ? '' : 's'} · ',
                style: TextStyle(color: palette.textSecondary, fontSize: 12),
              ),
              CurrencyText(order.total, style: TextStyle(color: palette.textSecondary, fontSize: 12, fontWeight: FontWeight.w500)),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  '· ${order.paymentMethod.label}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: palette.textSecondary, fontSize: 12),
                ),
              ),
              const Spacer(),
              if (order.isCod && delivered)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      order.codPaymentReceived ? Icons.check_circle_rounded : Icons.pending_rounded,
                      size: 14,
                      color: order.codPaymentReceived ? palette.success : palette.warning,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      order.codPaymentReceived ? 'Cash collected' : 'Cash pending',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                        color: order.codPaymentReceived ? palette.success : palette.warning,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          if (!delivered) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(color: palette.error.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10)),
              child: Text(
                order.cancelReason ?? 'Cancelled',
                style: TextStyle(color: palette.error, fontSize: 12, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _RouteLine extends StatelessWidget {
  const _RouteLine({required this.icon, required this.color, required this.text});
  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    return Row(
      children: [
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(color: color.withValues(alpha: 0.14), shape: BoxShape.circle),
          child: Icon(icon, size: 12, color: color),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: palette.textPrimary, fontSize: 13, fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }
}
