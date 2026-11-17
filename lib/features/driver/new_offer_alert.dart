import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/notifications/order_buzzer.dart';
import '../../core/router/app_router.dart';
import '../../core/session/session_controller.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/account.dart';
import '../../data/models/order.dart';
import '../../data/providers/firestore_drivers_provider.dart';
import '../../data/providers/firestore_orders_provider.dart';
import '../../shared/widgets/currency_text.dart';
import 'home/driver_home_screen.dart' show driverEarningOf;

/// "New delivery order" pop-up for an online Driver, on whatever screen
/// they're on — Home lists open orders too, but a Driver out on another
/// delivery or in Earnings/Profile would otherwise miss one until they
/// came back. Wired once at the app root ([listenForNewDriverOffers]).

/// The open orders (`vendorAccepted`, no Driver yet) in the signed-in
/// Driver's territory — null unless an active Driver is online and the
/// list has loaded, so going online or a first load only takes note of
/// what's already waiting instead of popping up for each of them.
final _openOffersProvider = Provider<List<Order>?>((ref) {
  final session = ref.watch(sessionControllerProvider);
  final account = session.account;
  if (session.role != AppRole.driver || session.stage != AuthStage.active || account == null) return null;
  final online = ref.watch(liveDriverAccountProvider(account.id))?.isOnline ?? account.isOnline;
  if (!online) return null;
  final orders = ref.watch(activeOrdersProvider);
  if (!orders.hasValue) return null;
  return [
    for (final o in orders.requireValue)
      if (o.status == OrderStatus.vendorAccepted && o.driverId == null) o,
  ];
});

bool _dialogOpen = false;

/// Shows [_NewOfferDialog] when an order the Driver hasn't seen yet opens
/// up — one at a time, and not when they're already looking at that offer.
void listenForNewDriverOffers(WidgetRef ref) {
  ref.listen<List<Order>?>(_openOffersProvider, (previous, next) {
    if (previous == null || next == null || _dialogOpen) return;
    final known = {for (final o in previous) o.id};
    final fresh = next.where((o) => !known.contains(o.id)).toList();
    if (fresh.isEmpty) return;
    final order = fresh.last;
    final router = ref.read(appRouterProvider);
    final context = router.routerDelegate.navigatorKey.currentContext;
    if (context == null) return;
    if (router.routerDelegate.currentConfiguration.uri.path == '/driver/offer/${order.id}') return;
    _dialogOpen = true;
    HapticFeedback.heavyImpact();
    // Rings until the Driver answers (2026-11-17, `order_buzzer.dart`).
    OrderBuzzer.start();
    showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _NewOfferDialog(order: order),
    ).then((view) {
      OrderBuzzer.stop();
      _dialogOpen = false;
      if (view == true) router.push('/driver/offer/${order.id}');
    });
  });
}

class _NewOfferDialog extends ConsumerWidget {
  const _NewOfferDialog({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.colors;
    // Another Driver may take it while this is open.
    final stillOpen = ref.watch(_openOffersProvider)?.any((o) => o.id == order.id) ?? false;
    return AlertDialog(
      icon: Icon(Icons.delivery_dining_rounded, color: stillOpen ? palette.primary : palette.textMuted, size: 40),
      title: Text(stillOpen ? 'New delivery order' : 'Order already taken'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            stillOpen ? 'Pick up from ${order.vendorName}' : 'Another driver accepted the order from ${order.vendorName}.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: palette.textPrimary),
          ),
          if (stillOpen) ...[
            const SizedBox(height: 12),
            Text(
              'You earn ${AppFormat.currency(driverEarningOf(order))}',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: palette.success),
            ),
            const SizedBox(height: 4),
            Text(
              order.isCod ? 'Cash on delivery' : 'Paid online',
              textAlign: TextAlign.center,
              style: TextStyle(color: palette.textSecondary),
            ),
          ],
        ],
      ),
      actions: stillOpen
          ? [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Later')),
              ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('View order')),
            ]
          : [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Close'))],
    );
  }
}
