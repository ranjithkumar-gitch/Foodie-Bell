import 'package:flutter_test/flutter_test.dart';
import 'package:foodiebell/data/models/order.dart';

/// Phase I audit (read-only): pins down how the app's legacy payment flags
/// behave against the order fields the backend writes today
/// (QuickyAdmin `functions/orders.js`). Written for the Phase I audit to
/// pin down defect P1-2; since Phase I.1 they assert the fixed behaviour
/// ([Order.isPaid] reads the server's payment record).
Order _order({
  required PaymentMethod method,
  String? paymentId,
  bool codPaymentReceived = false,
  Map<String, dynamic>? payment,
}) => Order(
  id: 'ORD-TEST0001',
  vendorId: 'v1',
  vendorName: 'Shop',
  userId: 'c1',
  userName: 'Customer',
  userPhone: '+910000000000',
  items: const [],
  deliveryAddressLabel: 'Home',
  paymentMethod: method,
  subtotal: 100,
  deliveryFee: 20,
  platformFee: 5,
  gstAmount: 0,
  total: 125,
  placedAt: DateTime(2026, 10, 29),
  rebatePercent: 10,
  paymentId: paymentId,
  codPaymentReceived: codPaymentReceived,
  payment: OrderPayment.tryParse(payment),
);

void main() {
  group('Order.isPaid vs the server payment state', () {
    test('FIXED (P1-2): a UPI reference the shop has not confirmed is not paid', () {
      // submitUpiReference writes paymentId = reference while payment.status
      // stays awaitingVerification (orders.js).
      final o = _order(method: PaymentMethod.upi, paymentId: 'UTR123456', payment: {'status': 'awaitingVerification'});
      expect(o.paymentStatus, OrderPaymentStatus.awaitingVerification);
      expect(o.isPaid, isFalse);
    });

    test('FIXED (P1-2): a disputed UPI payment is not paid', () {
      final o = _order(method: PaymentMethod.upi, paymentId: 'UTR123456', payment: {'status': 'disputed'});
      expect(o.isPaid, isFalse);
    });

    test('FIXED (P1-2): a photo order (verified UPI, paymentId null) is paid', () {
      // acceptListOrder creates the order with payment verified, paymentId null.
      final o = _order(method: PaymentMethod.upi, payment: {'status': 'verified'});
      expect(o.paymentStatus, OrderPaymentStatus.verified);
      expect(o.isPaid, isTrue);
    });

    test('COD counts as paid only once the cash is recorded', () {
      expect(_order(method: PaymentMethod.cod, payment: {'status': 'payOnDelivery'}).isPaid, isFalse);
      expect(_order(method: PaymentMethod.cod, codPaymentReceived: true, payment: {'status': 'collected'}).isPaid, isTrue);
    });
  });

  test('an unknown server payment status parses to unknown instead of throwing', () {
    expect(OrderPayment.tryParse({'status': 'somethingNew'})!.status, OrderPaymentStatus.unknown);
  });

  test('an unknown order status throws (OrderStatus.values.byName) — the order parser has no fallback', () {
    expect(() => OrderStatus.values.byName('returned'), throwsArgumentError);
  });
}
