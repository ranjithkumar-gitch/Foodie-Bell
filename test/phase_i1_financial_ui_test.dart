import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodiebell/data/models/order.dart';
import 'package:foodiebell/data/models/product.dart';
import 'package:foodiebell/data/providers/cart_provider.dart';
import 'package:foodiebell/data/providers/order_actions.dart';
import 'package:foodiebell/data/providers/settlement_provider.dart';
import 'package:foodiebell/features/user/addresses/add_address_sheet.dart';
import 'package:foodiebell/features/user/cart/cart_screen.dart';
import 'package:foodiebell/features/user/orders/cancel_order_button.dart';
import 'package:foodiebell/features/user/transactions/transaction_history_screen.dart';
import 'package:foodiebell/features/user/wallet/wallet_screen.dart';
import 'package:foodiebell/features/vendor/registration/vendor_rebate_terms_screen.dart';
import 'package:foodiebell/l10n/generated/app_localizations.dart';

/// Phase I.1: payment status from the server's payment record, transaction
/// history and refunds, live commission labels, the address pin, the cart
/// label and the customer's COD cancel — QuickyAdmin `functions/orders.js`
/// is the reference for every payment state used here.
Order _order({
  String id = 'ORD-TEST0001',
  String userId = 'c1',
  PaymentMethod method = PaymentMethod.upi,
  OrderStatus status = OrderStatus.delivered,
  String? paymentId,
  bool codPaymentReceived = false,
  Map<String, dynamic>? payment,
  DateTime? placedAt,
  DateTime? paidAt,
  double rebatePercent = 10,
}) => Order(
  id: id,
  vendorId: 'v1',
  vendorName: 'Shop',
  userId: userId,
  userName: 'Customer',
  userPhone: '+910000000000',
  items: const [],
  deliveryAddressLabel: 'Home',
  paymentMethod: method,
  status: status,
  subtotal: 100,
  deliveryFee: 20,
  platformFee: 5,
  gstAmount: 0,
  total: 125,
  placedAt: placedAt ?? DateTime(2026, 10, 29),
  paidAt: paidAt,
  rebatePercent: rebatePercent,
  paymentId: paymentId,
  codPaymentReceived: codPaymentReceived,
  payment: OrderPayment.tryParse(payment),
);

Widget _app(Widget child, {List<Override> overrides = const []}) => ProviderScope(
  overrides: overrides,
  child: MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: child,
  ),
);

void main() {
  group('payment status comes from the server payment record', () {
    test('a typed UPI reference is not a payment until the shop confirms it', () {
      // submitUpiReference writes payment.customerReference and the legacy paymentId.
      final o = _order(paymentId: 'UTR123456', payment: {'status': 'awaitingVerification', 'customerReference': 'UTR123456'});
      expect(o.isPaid, isFalse);
      expect(o.paymentStatus.label, 'Waiting for the shop to confirm');
      expect(o.paymentReference, 'UTR123456');
    });

    test('verified UPI (photo orders included), collected COD and refunds count as paid', () {
      expect(_order(payment: {'status': 'verified'}).isPaid, isTrue); // acceptListOrder: paymentId null
      expect(_order(method: PaymentMethod.cod, codPaymentReceived: true, payment: {'status': 'collected'}).isPaid, isTrue);
      expect(_order(payment: {'status': 'refundDue'}).isPaid, isTrue);
      expect(_order(payment: {'status': 'refunded'}).isPaid, isTrue);
    });

    test('disputed, failed, not-yet-collected and cancelled-unpaid do not', () {
      for (final status in ['disputed', 'failed', 'unpaidCancelled']) {
        expect(_order(paymentId: 'UTR1', payment: {'status': status}).isPaid, isFalse, reason: status);
      }
      expect(_order(method: PaymentMethod.cod, payment: {'status': 'payOnDelivery'}).isPaid, isFalse);
    });

    test('orders from before the payment record keep their legacy meaning', () {
      final razorpay = _order(method: PaymentMethod.online, paymentId: 'pay_ABC');
      expect(razorpay.paymentStatus, OrderPaymentStatus.verified);
      expect(razorpay.isPaidOnline, isTrue);
      expect(_order(method: PaymentMethod.cod, codPaymentReceived: true).paymentStatus, OrderPaymentStatus.collected);
      expect(_order(method: PaymentMethod.cod).isPaid, isFalse);
      expect(_order(method: PaymentMethod.online).paymentStatus, OrderPaymentStatus.unknown);
    });

    test('no status is labelled as received unless money has changed hands', () {
      for (final s in OrderPaymentStatus.values) {
        final saysReceived = s.label.startsWith('Payment received');
        expect(saysReceived, s == OrderPaymentStatus.verified || s == OrderPaymentStatus.collected, reason: s.name);
      }
    });
  });

  group('transaction history and refunds', () {
    final upiConfirmed = _order(id: 'A', payment: {'status': 'verified'}, paidAt: DateTime(2026, 10, 29, 10));
    final photoOrder = _order(id: 'B', payment: {'status': 'verified'}, paidAt: DateTime(2026, 10, 29, 12));
    final codCollected = _order(id: 'C', method: PaymentMethod.cod, codPaymentReceived: true, payment: {'status': 'collected'}, paidAt: DateTime(2026, 10, 29, 11));
    final refundDue = _order(id: 'D', status: OrderStatus.rejected, payment: {'status': 'refundDue'}, paidAt: DateTime(2026, 10, 28));
    final typedOnly = _order(id: 'E', status: OrderStatus.placed, paymentId: 'UTR9', payment: {'status': 'awaitingVerification'});
    final disputed = _order(id: 'F', status: OrderStatus.placed, payment: {'status': 'disputed'});
    final codPending = _order(id: 'G', method: PaymentMethod.cod, status: OrderStatus.pickedUp, payment: {'status': 'payOnDelivery'});
    final someoneElse = _order(id: 'H', userId: 'c2', payment: {'status': 'verified'});

    test('lists only confirmed money, newest payment first', () {
      final list = paidTransactions(
        [typedOnly, codPending],
        [upiConfirmed, photoOrder, codCollected, refundDue, disputed, someoneElse],
        'c1',
      );
      expect([for (final o in list) o.id], ['B', 'C', 'A', 'D']);
    });

    test('a live copy replaces the history copy (a UPI order confirmed meanwhile appears)', () {
      final confirmedNow = _order(id: 'E', status: OrderStatus.placed, paymentId: 'UTR9', payment: {'status': 'verified'}, paidAt: DateTime(2026, 10, 30));
      expect(paidTransactions([confirmedNow], [typedOnly], 'c1').single.id, 'E');
    });

    test('refunds: only money owed back or returned, for this customer', () {
      final refunded = _order(id: 'R', status: OrderStatus.cancelled, payment: {'status': 'refunded'}, placedAt: DateTime(2026, 10, 30));
      final unpaidCancel = _order(id: 'U', method: PaymentMethod.cod, status: OrderStatus.cancelled, payment: {'status': 'unpaidCancelled'});
      expect([for (final o in refundOrders([refundDue, refunded, unpaidCancel, someoneElse], 'c1')) o.id], ['R', 'D']);
    });

    testWidgets('the refunds screen shows no wallet balance', (tester) async {
      await tester.pumpWidget(_app(const RefundsScreen()));
      await tester.pump();
      expect(find.text('Refunds'), findsOneWidget);
      expect(find.textContaining('balance', findRichText: true), findsNothing);
      expect(find.textContaining('Wallet'), findsNothing);
    });
  });

  group('live commission and fee labels', () {
    test('rates come from app_config/pricing, with the server defaults when absent', () {
      final defaults = PricingRates.from(null);
      // Phase I.8: no saved pricing → the share isn't quoted (the server's
      // 60/40 built-in default is not the approved 50/50 split).
      expect([defaults.commissionPercent, defaults.managerSharePercent, defaults.quickySharePercent, defaults.lowestDeliveryFeePaise], [10, null, null, 2000]);
      expect(defaults.managerShareLabel, 'not yet set by Quicky');
      final custom = PricingRates.from({
        'commissionBps': 1250,
        'managerShareBps': 5500,
        'deliverySlabs': [
          {'upToMeters': 3000, 'feePaise': 2500},
          {'upToMeters': 6000, 'feePaise': 3500},
        ],
      });
      expect([custom.commissionPercent, custom.managerSharePercent, custom.lowestDeliveryFeePaise], [12.5, 55, 2500]);
      expect([formatPercent(10), formatPercent(12.5), formatPercent(12.25)], ['10', '12.5', '12.25']);
    });

    testWidgets('vendor registration shows the live global commission, not a 15% rebate', (tester) async {
      await tester.pumpWidget(_app(
        const VendorRebateTermsScreen(),
        overrides: [globalPricingProvider.overrideWith((ref) => Stream.value({'commissionBps': 1250, 'managerShareBps': 6000}))],
      ));
      await tester.pump();
      await tester.pump();
      expect(find.text('12.5%'), findsOneWidget);
      expect(find.textContaining('15%'), findsNothing);
      expect(find.textContaining('rebate'), findsNothing);
      expect(find.text('I accept the 12.5% commission terms.'), findsOneWidget);
    });

    testWidgets('the cart calls its figure the items total and says fees come at checkout', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(cartProvider.notifier).addItem(
        const Product(id: 'p1', name: 'Rice', description: '', price: 100, imageUrl: '', subCategory: 'Grocery'),
        vendorId: 'v1',
        vendorName: 'Shop',
        deliveryFee: 20,
        rebatePercent: 10,
      );
      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const CartScreen(),
        ),
      ));
      await tester.pump();
      expect(find.text('Items total'), findsOneWidget);
      expect(find.text('Total'), findsNothing);
      expect(find.textContaining('added at checkout'), findsOneWidget);
    });
  });

  group('address pin', () {
    testWidgets('an address is not saved without a pin the customer confirmed', (tester) async {
      await tester.pumpWidget(_app(const Scaffold(body: AddAddressSheet())));
      await tester.pump();
      expect(find.text('Delivery location'), findsOneWidget);
      // Before any pin: both ways to place one, and the requirement.
      expect(find.text('Use my current location'), findsOneWidget);
      expect(find.text('Find the address above on the map'), findsOneWidget);

      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'Asha');
      await tester.enterText(fields.at(1), '9000000006');
      await tester.enterText(fields.at(2), '12 Main Road');
      await tester.enterText(fields.at(4), '522001');
      await tester.enterText(fields.at(5), 'Guntur');
      await tester.ensureVisible(find.text('Save Address'));
      await tester.tap(find.text('Save Address'));
      await tester.pump();

      // The status line and the error both name the missing pin; nothing was written.
      expect(find.text('Pin the exact delivery location on the map before saving.'), findsNWidgets(2));
      expect(find.byType(AddAddressSheet), findsOneWidget);
    });
  });

  group('customer cancellation (cancelOrder: own order, placed only)', () {
    test('shown for placed COD orders only; UPI cancels from its payment card', () {
      expect(showsCancelOrderButton(_order(method: PaymentMethod.cod, status: OrderStatus.placed)), isTrue);
      expect(showsCancelOrderButton(_order(method: PaymentMethod.upi, status: OrderStatus.placed)), isFalse);
      for (final s in OrderStatus.values.where((s) => s != OrderStatus.placed)) {
        expect(showsCancelOrderButton(_order(method: PaymentMethod.cod, status: s)), isFalse, reason: s.name);
      }
    });

    testWidgets('asks first, then sends the order id and a reason', (tester) async {
      final calls = <(String, String)>[];
      await tester.pumpWidget(_app(Scaffold(
        body: CancelOrderButton(
          order: _order(method: PaymentMethod.cod, status: OrderStatus.placed),
          cancel: (id, reason) async => calls.add((id, reason)),
        ),
      )));
      await tester.tap(find.widgetWithText(OutlinedButton, 'Cancel order'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Keep order'));
      await tester.pumpAndSettle();
      expect(calls, isEmpty);

      await tester.tap(find.widgetWithText(OutlinedButton, 'Cancel order'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Cancel order'));
      await tester.pumpAndSettle();
      expect(calls, [('ORD-TEST0001', 'Cancelled by customer')]);
    });

    testWidgets("shows the server's refusal", (tester) async {
      await tester.pumpWidget(_app(Scaffold(
        body: CancelOrderButton(
          order: _order(method: PaymentMethod.cod, status: OrderStatus.placed),
          cancel: (id, reason) async => throw const OrderActionException("The shop has already accepted this order, so it can't be cancelled here.", code: 'failed-precondition'),
        ),
      )));
      await tester.tap(find.widgetWithText(OutlinedButton, 'Cancel order'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Changed my mind');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Cancel order'));
      await tester.pumpAndSettle();
      expect(find.textContaining('already accepted'), findsOneWidget);
    });
  });
}
