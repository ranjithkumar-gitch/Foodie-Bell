import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/notifications/order_buzzer.dart';
import '../../core/router/app_router.dart';
import '../../core/session/session_controller.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/account.dart';
import '../../data/models/order.dart';
import '../../data/providers/firestore_orders_provider.dart';
import '../../shared/widgets/currency_text.dart';

/// "New order" pop-up with the buzzer for a signed-in Vendor (2026-11-17),
/// on whatever screen they're on, the same idea as the Driver's
/// `new_offer_alert.dart`. Rings until the Vendor answers it, so an order
/// isn't missed while the phone sits on the counter. Wired once at the
/// app root ([listenForNewVendorOrders]).

/// The Vendor's orders waiting to be accepted — null unless an active
/// Vendor is signed in and the list has loaded, so a first load only takes
/// note of what's already waiting instead of ringing for each of them.
final _waitingOrdersProvider = Provider<List<Order>?>((ref) {
  final session = ref.watch(sessionControllerProvider);
  final account = session.account;
  if (session.role != AppRole.vendor || session.stage != AuthStage.active || account == null) return null;
  final orders = ref.watch(activeOrdersProvider);
  if (!orders.hasValue) return null;
  return [
    for (final o in orders.requireValue)
      if (o.status == OrderStatus.placed && o.vendorId == account.id) o,
  ];
});

bool _dialogOpen = false;

/// Shows [_NewOrderDialog] and rings the buzzer when a new order arrives.
void listenForNewVendorOrders(WidgetRef ref) {
  ref.listen<List<Order>?>(_waitingOrdersProvider, (previous, next) {
    if (previous == null || next == null || _dialogOpen) return;
    final known = {for (final o in previous) o.id};
    final fresh = next.where((o) => !known.contains(o.id)).toList();
    if (fresh.isEmpty) return;
    final order = fresh.last;
    final router = ref.read(appRouterProvider);
    final context = router.routerDelegate.navigatorKey.currentContext;
    if (context == null) return;
    _dialogOpen = true;
    HapticFeedback.heavyImpact();
    OrderBuzzer.start();
    showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _NewOrderDialog(order: order, alsoWaiting: fresh.length - 1),
    ).then((view) {
      OrderBuzzer.stop();
      _dialogOpen = false;
      if (view == true) router.push('/vendor/order/${order.id}');
    });
  });
}

class _NewOrderDialog extends ConsumerWidget {
  const _NewOrderDialog({required this.order, required this.alsoWaiting});

  final Order order;
  final int alsoWaiting;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.colors;
    // The customer may cancel while this is open.
    final stillWaiting = ref.watch(_waitingOrdersProvider)?.any((o) => o.id == order.id) ?? true;
    final items = order.items.fold<int>(0, (n, i) => n + i.quantity);
    return AlertDialog(
      key: const Key('vendorNewOrderDialog'),
      icon: Icon(Icons.notifications_active_rounded, color: stillWaiting ? palette.primary : palette.textMuted, size: 40),
      title: Text(stillWaiting ? 'New order!' : 'Order cancelled'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            stillWaiting ? 'From ${order.userName}' : '${order.userName} cancelled this order.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: palette.textPrimary),
          ),
          if (stillWaiting) ...[
            const SizedBox(height: 12),
            Text(
              '$items item${items == 1 ? '' : 's'} · ${AppFormat.currency(order.total)}',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: palette.success),
            ),
            if (alsoWaiting > 0) ...[
              const SizedBox(height: 6),
              Text(
                '+ $alsoWaiting more new order${alsoWaiting == 1 ? '' : 's'}',
                textAlign: TextAlign.center,
                style: TextStyle(color: palette.textSecondary),
              ),
            ],
          ],
        ],
      ),
      actions: stillWaiting
          ? [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Later')),
              ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('View order')),
            ]
          : [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Close'))],
    );
  }
}
