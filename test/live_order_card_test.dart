// Live order card (2026-11-12): one card per order for customers and
// drivers; same wording as the server's pushes so a step alerts once.
import 'package:flutter_test/flutter_test.dart';
import 'package:foodiebell/core/notifications/live_order_card.dart';
import 'package:foodiebell/core/notifications/notification_taps.dart';
import 'package:foodiebell/data/models/order.dart';

Order _order(OrderStatus status, {String? driverName = 'Ravi'}) => Order(
  id: 'ORD-1',
  vendorId: 'v1',
  vendorName: 'Fresh Mart',
  userId: 'c1',
  userName: 'Asha',
  userPhone: '+910000000000',
  items: const [],
  deliveryAddressLabel: 'Home',
  paymentMethod: PaymentMethod.cod,
  status: status,
  subtotal: 100,
  deliveryFee: 20,
  platformFee: 5,
  gstAmount: 0,
  total: 125,
  placedAt: DateTime(2026, 11, 12),
  rebatePercent: 10,
  driverId: 'd1',
  driverName: driverName,
);

void main() {
  test('customer card: server wording at each step, progress over 5 steps', () {
    final steps = {
      OrderStatus.placed: ('Order placed', 'Your order from Fresh Mart has been placed.', 1),
      OrderStatus.vendorAccepted: ('Order confirmed', 'Fresh Mart accepted your order.', 2),
      OrderStatus.driverAssigned: ('Driver assigned', 'Ravi is picking up your order.', 3),
      OrderStatus.pickedUp: ('On the way', 'Ravi has picked up your order.', 4),
    };
    for (final e in steps.entries) {
      final c = LiveOrderCard.forOrder(_order(e.key), 'user')!;
      expect([c.title, c.body, c.step, c.steps, c.terminal], [e.value.$1, e.value.$2, e.value.$3, 5, false]);
    }
    expect(LiveOrderCard.forOrder(_order(OrderStatus.delivered), 'user'), isNull); // the server's final push says it
  });

  test('driver card: pick up, then deliver; nothing before they take it', () {
    expect(LiveOrderCard.forOrder(_order(OrderStatus.driverAssigned), 'driver')!.title, 'Pick up from Fresh Mart');
    final deliver = LiveOrderCard.forOrder(_order(OrderStatus.pickedUp), 'driver')!;
    expect([deliver.title, deliver.step, deliver.steps], ['Deliver to Asha', 2, 3]);
    expect(LiveOrderCard.forOrder(_order(OrderStatus.vendorAccepted), 'driver'), isNull);
  });

  test('a live push becomes the same card; anything else is ignored', () {
    final c = LiveOrderCard.fromPush({'live': '1', 'orderId': 'ORD-1', 'role': 'user', 'type': 'delivered', 'title': 'Order delivered', 'body': 'Done', 'step': '5', 'steps': '5', 'shop': 'Fresh Mart'})!;
    expect([c.terminal, c.step, c.subText], [true, 5, 'Fresh Mart']);
    expect(LiveOrderCard.fromPush({'orderId': 'ORD-1', 'type': 'refund'}), isNull);
  });

  test('one stable notification id per order; taps open the right screen', () {
    expect(liveOrderNotificationId('ORD-1'), liveOrderNotificationId('ORD-1'));
    expect(liveOrderNotificationId('ORD-1'), isNot(liveOrderNotificationId('ORD-2')));
    expect(liveOrderRoute(role: 'user', orderId: 'ORD-1', status: 'pickedUp'), '/user/order/ORD-1');
    expect(liveOrderRoute(role: 'driver', orderId: 'ORD-1', status: 'driverAssigned'), '/driver/delivery/ORD-1/navigate-vendor');
    expect(liveOrderRoute(role: 'driver', orderId: 'ORD-1', status: 'pickedUp'), '/driver/delivery/ORD-1/navigate-customer');
    expect(routeForPushData({'live': '1', 'orderId': 'ORD-1', 'role': 'user', 'type': 'placed'}), '/user/order/ORD-1');
    expect(routeForPushData({'orderId': 'ORD-1'}), isNull);
  });
}
