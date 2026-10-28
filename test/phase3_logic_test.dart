import 'package:flutter_test/flutter_test.dart';

import 'package:foodiebell/data/models/order.dart';
import 'package:foodiebell/data/providers/earnings_provider.dart';
import 'package:foodiebell/data/providers/firestore_orders_provider.dart';
import 'package:foodiebell/data/providers/settlement_provider.dart';

Order _order(String id, OrderStatus status, DateTime placedAt) => Order(
  id: id,
  vendorId: 'v',
  vendorName: 'Shop',
  userId: 'u',
  userName: 'C',
  userPhone: '9',
  items: const [],
  deliveryAddressLabel: 'Home',
  paymentMethod: PaymentMethod.cod,
  subtotal: 100,
  deliveryFee: 20,
  platformFee: 0,
  gstAmount: 0,
  total: 120,
  placedAt: placedAt,
  rebatePercent: 0,
  status: status,
);

void main() {
  group('settlement day (same rule as functions/money.js settlementDayFor)', () {
    test('before the 22:00 IST cut-off counts to the same IST day', () {
      // 21:59 IST = 16:29 UTC.
      expect(currentSettlementDay(now: DateTime.utc(2026, 10, 28, 16, 29)), '2026-10-28');
    });
    test('at and after the cut-off counts to the next day', () {
      expect(currentSettlementDay(now: DateTime.utc(2026, 10, 28, 16, 30)), '2026-10-29');
      expect(currentSettlementDay(now: DateTime.utc(2026, 10, 28, 18, 31)), '2026-10-29'); // 00:01 IST
    });
    test('a midnight cut-off is the plain IST date', () {
      expect(currentSettlementDay(cutoffMinutes: 0, now: DateTime.utc(2026, 10, 28, 18, 29)), '2026-10-28');
      expect(currentSettlementDay(cutoffMinutes: 0, now: DateTime.utc(2026, 10, 28, 18, 30)), '2026-10-29');
    });
  });

  group('order history with live in-progress orders', () {
    test('a live copy replaces its stale history copy; newest first; no duplicates', () {
      final t = DateTime(2026, 10, 28, 10);
      final history = [
        _order('a', OrderStatus.placed, t),
        _order('b', OrderStatus.delivered, t.subtract(const Duration(hours: 1))),
      ];
      final active = [
        _order('a', OrderStatus.pickedUp, t),
        _order('c', OrderStatus.placed, t.add(const Duration(minutes: 5))),
      ];
      final merged = withLiveOrders(active, history);
      expect(merged.map((o) => o.id), ['c', 'a', 'b']);
      expect(merged.firstWhere((o) => o.id == 'a').status, OrderStatus.pickedUp);
    });
  });

  group('history filters', () {
    test('cover exactly the finished statuses', () {
      expect(OrderHistoryFilter.all.statuses, isNull);
      expect(OrderHistoryFilter.finished.statuses, unorderedEquals(['delivered', 'cancelled', 'rejected']));
      expect(OrderHistoryFilter.cancelled.statuses, unorderedEquals(['cancelled', 'rejected']));
      expect(activeOrderStatusNames, unorderedEquals(['placed', 'vendorAccepted', 'driverAssigned', 'pickedUp']));
    });
  });

  group('server earnings figures', () {
    test('paise become rupees; weekday totals Monday first; missing = 0', () {
      const f = EarningsFigures({'orders': 3, 'earningsPaise': 27000, 'codTotalPaise': 12000, 'weekday1Paise': 500, 'weekday7Paise': 250});
      expect(f.orders, 3);
      expect(f.earnings, 270.0);
      expect(f.codTotal, 120.0);
      expect(f.upiTotal, 0.0);
      expect(f.weekdayTotals, [5.0, 0, 0, 0, 0, 0, 2.5]);
    });
    test('earningsOn picks the day or returns zeros', () {
      const days = [EarningsDay({'settlementDay': '2026-10-28', 'earningsPaise': 2000, 'orders': 1})];
      expect(earningsOn(days, '2026-10-28').earnings, 20.0);
      expect(earningsOn(days, '2026-10-27').orders, 0);
    });
  });

  group('platform fee in the order snapshot', () {
    test('parsed from money; absent on old orders = 0', () {
      final withFee = OrderMoney.tryParse({'customerTotal': 12500, 'platformFee': 500, 'vendorEntitlement': 9000})!;
      expect([withFee.platformFee, withFee.customerTotal, withFee.vendorEntitlement], [500, 12500, 9000]);
      expect(OrderMoney.tryParse({'customerTotal': 12000})!.platformFee, 0);
    });
  });
}
