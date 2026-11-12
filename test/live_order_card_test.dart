// Live order card (2026-11-12): one card per order for customers and
// drivers; same wording as the server's pushes so a step alerts once.
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodiebell/core/notifications/live_order_card.dart';
import 'package:foodiebell/core/notifications/notification_taps.dart';
import 'package:foodiebell/data/models/order.dart';
import 'package:foodiebell/l10n/generated/app_localizations.dart';

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

final _en = lookupAppLocalizations(const Locale('en'));

void main() {
  LiveOrderCard card(OrderStatus status, String role, {String? otp}) =>
      LiveOrderCard.build(LiveOrderFacts.fromOrder(_order(status), role, otp: otp), _en)!;

  test('customer card: the home card words, 4-step bar, shop with items and total', () {
    final steps = {
      OrderStatus.placed: ('Order placed!', 'Waiting for Fresh Mart to accept your order', 1),
      OrderStatus.vendorAccepted: ('Preparing your order', 'Fresh Mart has accepted and is getting it ready', 2),
      OrderStatus.driverAssigned: ('Partner heading to the vendor', 'Ravi will pick up your order soon', 3),
      OrderStatus.pickedUp: ('On the way to you', 'Ravi has picked up your order', 4),
    };
    for (final e in steps.entries) {
      final c = card(e.key, 'user');
      expect([c.title, c.subtitle, c.step, c.steps, c.terminal, c.footerTitle], [e.value.$1, e.value.$2, e.value.$3, 4, false, 'Fresh Mart']);
      expect(c.footerText, contains('₹125'));
    }
    expect(card(OrderStatus.pickedUp, 'user', otp: '4821').otp, '4821');
    // The stream shows no final card; the server's push does.
    expect(LiveOrderCard.build(LiveOrderFacts.fromOrder(_order(OrderStatus.delivered), 'user'), _en)!.terminal, isTrue);
  });

  test('a push and the app draw the very same card (no double alert)', () {
    final fromApp = card(OrderStatus.pickedUp, 'user', otp: '4821');
    final fromPush = LiveOrderCard.build(LiveOrderFacts.fromPush({
      'live': '1', 'orderId': 'ORD-1', 'role': 'user', 'type': 'pickedUp', 'shop': 'Fresh Mart', 'driverName': 'Ravi',
      'items': '0', 'total': '12500', 'payment': 'cod', 'otp': '4821', 'title': 'On the way', 'body': 'x',
    })!, _en)!;
    expect(fromPush.hash, fromApp.hash);
    expect(fromPush.stage, 'pickedUp:otp');
    expect(LiveOrderFacts.fromPush({'orderId': 'ORD-1', 'type': 'refund'}), isNull);
  });

  test('driver card: pick up, then deliver with cash to collect', () {
    expect(card(OrderStatus.driverAssigned, 'driver').title, 'Pick up from Fresh Mart');
    final deliver = card(OrderStatus.pickedUp, 'driver');
    expect([deliver.title, deliver.step, deliver.steps], ['Deliver to Asha', 2, 2]);
    expect(deliver.footerText, contains('Collect ₹125 cash'));
    expect(LiveOrderCard.build(LiveOrderFacts.fromOrder(_order(OrderStatus.vendorAccepted), 'driver'), _en), isNull);
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
