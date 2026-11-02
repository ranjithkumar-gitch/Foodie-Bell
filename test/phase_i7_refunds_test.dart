// Phase I.7: customer UPI refunds in the app — the customer's card and
// refunds list, the shop's card and "Record refund", and the Manager's list.
// Server state comes from overridden providers; actions go to a fake.
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodiebell/data/models/order.dart';
import 'package:foodiebell/data/models/refund_case.dart';
import 'package:foodiebell/data/providers/order_actions.dart' show OrderActionException;
import 'package:foodiebell/data/providers/refunds_provider.dart';
import 'package:foodiebell/features/manager/refunds/manager_refunds_screen.dart';
import 'package:foodiebell/features/user/wallet/wallet_screen.dart';
import 'package:foodiebell/l10n/generated/app_localizations.dart';
import 'package:foodiebell/shared/widgets/currency_text.dart';
import 'package:foodiebell/shared/widgets/refund_cards.dart';

class FakeRefundActions extends RefundActions {
  final calls = <Map<String, Object?>>[];
  Object? failNext;

  void _maybeFail() {
    final f = failNext;
    failNext = null;
    if (f != null) throw f;
  }

  @override
  Future<({String transferId, bool duplicate})> record({required String orderId, required String requestId, required int amountPaise, required String upiReference, required String paidOn, String? evidencePath, String? note}) async {
    calls.add({'fn': 'record', 'orderId': orderId, 'requestId': requestId, 'amountPaise': amountPaise, 'upiReference': upiReference, 'paidOn': paidOn});
    _maybeFail();
    return (transferId: 't1', duplicate: false);
  }

  @override
  Future<void> respond({required String orderId, required String transferId, required String response, int? receivedAmountPaise, String? note}) async {
    calls.add({'fn': 'respond', 'orderId': orderId, 'transferId': transferId, 'response': response, 'receivedAmountPaise': receivedAmountPaise, 'note': note});
    _maybeFail();
  }

  @override
  Future<void> setDestination({required String orderId, required String upiId}) async => calls.add({'fn': 'setDestination', 'upiId': upiId});

  @override
  Future<void> escalate({required String orderId, required String reason}) async => calls.add({'fn': 'escalate', 'orderId': orderId, 'reason': reason});

  @override
  Future<void> recordFollowUp({required String orderId, required String requestId, required String remark}) async =>
      calls.add({'fn': 'followUp', 'orderId': orderId, 'remark': remark, 'requestId': requestId});

  @override
  Future<String> uploadEvidence({required String orderId, required String party, required Uint8List bytes, required String contentType}) async => 'refund_evidence/$orderId/$party/x.jpg';
}

RefundCase _case({String status = 'refundDue', Map<String, dynamic> extra = const {}}) => RefundCase.fromMap('ORD-1', {
  'orderId': 'ORD-1',
  'vendorId': 'v1',
  'vendorName': 'Fresh Mart',
  'userId': 'c1',
  'managerId': 'mA',
  'territoryId': 't1',
  'status': status,
  'owedPaise': 12500,
  'refundedPaise': 0,
  'pendingPaise': 0,
  'outstandingPaise': 12500,
  'cause': 'customerCancelled',
  'destination': {'kind': 'originalPayment', 'customerReference': 'CUST123456'},
  ...extra,
});

const _attempt = {'transferId': 'rf_1', 'amountPaise': 12500, 'reference': '412345678901', 'paidOn': '2026-11-02', 'byQuicky': false};

// A fresh ProviderScope per pump (UniqueKey), so each pump's overrides apply.
Widget _app(Widget child, {List<Override> overrides = const [], Locale locale = const Locale('en')}) => ProviderScope(
  key: UniqueKey(),
  overrides: overrides,
  child: MaterialApp(
    locale: locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: SingleChildScrollView(child: child)),
  ),
);

List<Override> _withCase(RefundCase? k, FakeRefundActions actions) => [
  refundCaseProvider('ORD-1').overrideWith((ref) => Stream.value(k)),
  refundActionsProvider.overrideWithValue(actions),
];

void main() {
  group('labels: initiated is never refunded', () {
    test('the same five labels everywhere', () {
      expect([for (final s in RefundStatus.values.take(5)) s.label], [
        'Refund owed',
        'Refund initiated — awaiting confirmation',
        'Refund disputed',
        'Review required',
        'Refund confirmed',
      ]);
      for (final s in RefundStatus.values) {
        expect(s.label.contains('successful'), isFalse);
        expect(s.isDone, s == RefundStatus.refunded);
      }
    });

    test('an order shows its refund progress, not just "Refund owed"', () {
      Order order(String payment, String? refund) => Order(
        id: 'o', vendorId: 'v', vendorName: 'V', userId: 'c', userName: 'C', userPhone: '', items: const [], subtotal: 100, deliveryFee: 20, platformFee: 5, gstAmount: 0, total: 125, rebatePercent: 10,
        status: OrderStatus.cancelled, placedAt: DateTime(2026, 11, 2), deliveryAddressLabel: '', paymentMethod: PaymentMethod.upi,
        payment: OrderPayment(status: OrderPaymentStatus.values.byName(payment)),
        refundStatus: refund == null ? null : refundStatusFrom(refund),
      );
      expect(order('refundDue', 'awaitingCustomerConfirmation').paymentLabel, 'Refund initiated — awaiting confirmation');
      expect(order('refundDue', 'refundDisputed').paymentLabel, 'Refund disputed');
      expect(order('refundDue', null).paymentLabel, 'Refund owed');
      expect(order('refunded', 'refunded').paymentLabel, 'Refund confirmed');
      expect(order('verified', 'refundDue').paymentLabel, 'Payment received');
    });
  });

  group('35: customer', () {
    testWidgets('a refund owed: the amount, the shop, where it goes; no confirmation yet', (tester) async {
      final actions = FakeRefundActions();
      await tester.pumpWidget(_app(const CustomerRefundCard(orderId: 'ORD-1'), overrides: _withCase(_case(), actions)));
      await tester.pumpAndSettle();
      expect(find.text('Refund owed'), findsOneWidget);
      expect(find.text('Owed to you: ₹125.00'), findsOneWidget);
      expect(find.text('From Fresh Mart'), findsOneWidget);
      expect(find.text("The shop hasn't sent this refund yet."), findsOneWidget);
      expect(find.text('Refund to: the UPI account you paid from'), findsOneWidget);
      expect(find.byKey(const Key('refundReceived')), findsNothing);
      expect(find.text('Refund confirmed'), findsNothing);
      // Choosing a UPI ID for the refund.
      await tester.tap(find.byKey(const Key('refundChangeUpi')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('refundUpiId')), 'asha@okhdfc');
      await tester.pump();
      await tester.tap(find.byKey(const Key('refundUpiSave')));
      await tester.pumpAndSettle();
      expect(actions.calls.single, {'fn': 'setDestination', 'upiId': 'asha@okhdfc'});
    });

    testWidgets('a recorded refund asks for confirmation; "I received it" is the customer\'s own answer', (tester) async {
      final actions = FakeRefundActions();
      final k = _case(status: 'awaitingCustomerConfirmation', extra: {'activeAttempt': _attempt, 'pendingPaise': 12500});
      await tester.pumpWidget(_app(const CustomerRefundCard(orderId: 'ORD-1'), overrides: _withCase(k, actions)));
      await tester.pumpAndSettle();
      expect(find.text('Refund initiated — awaiting confirmation'), findsOneWidget);
      expect(find.text('The shop says it sent ₹125.00 on 2026-11-02 (UPI ref 412345678901). Did you receive it?'), findsOneWidget);
      expect(find.text('Refund confirmed'), findsNothing);
      expect(find.byKey(const Key('refundChangeUpi')), findsNothing, reason: "the destination can't change under a payment already sent");
      await tester.tap(find.byKey(const Key('refundReceived')));
      await tester.pumpAndSettle();
      expect(actions.calls.single, {'fn': 'respond', 'orderId': 'ORD-1', 'transferId': 'rf_1', 'response': 'received', 'receivedAmountPaise': null, 'note': null});
    });

    testWidgets('not received, and a different amount, are disputes with the customer\'s details', (tester) async {
      final actions = FakeRefundActions();
      final k = _case(status: 'awaitingCustomerConfirmation', extra: {'activeAttempt': _attempt, 'pendingPaise': 12500});
      await tester.pumpWidget(_app(const CustomerRefundCard(orderId: 'ORD-1'), overrides: _withCase(k, actions)));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('refundNotReceived')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('refundAnswerNote')), 'Nothing in my account');
      await tester.tap(find.byKey(const Key('refundAnswerSubmit')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('refundDifferentAmount')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('refundReceivedAmount')), '40');
      await tester.pump();
      await tester.tap(find.byKey(const Key('refundAnswerSubmit')));
      await tester.pumpAndSettle();
      expect([for (final c in actions.calls) (c['response'], c['receivedAmountPaise'], c['note'])], [
        ('notReceived', null, 'Nothing in my account'),
        ('differentAmount', 4000, null),
      ]);
    });

    testWidgets('disputed, under review and confirmed each say so', (tester) async {
      final actions = FakeRefundActions();
      for (final (status, text) in [
        ('refundDisputed', "You reported this refund didn't arrive as recorded. Quicky is reviewing it."),
        ('refundReviewRequired', 'Quicky is reviewing this refund.'),
      ]) {
        await tester.pumpWidget(_app(const CustomerRefundCard(orderId: 'ORD-1'), overrides: _withCase(_case(status: status), actions)));
        await tester.pumpAndSettle();
        expect(find.text(text), findsOneWidget, reason: status);
      }
      final done = _case(status: 'refunded', extra: {'refundedPaise': 12500, 'outstandingPaise': 0});
      await tester.pumpWidget(_app(const CustomerRefundCard(orderId: 'ORD-1'), overrides: _withCase(done, actions)));
      await tester.pumpAndSettle();
      expect(find.text('Refund confirmed'), findsOneWidget);
      expect(find.text('Refund confirmed: ₹125.00 returned.'), findsOneWidget);
      expect(find.byKey(const Key('refundReceived')), findsNothing);
    });

    testWidgets('no refund owed: nothing shown; a failed load offers retry', (tester) async {
      final actions = FakeRefundActions();
      await tester.pumpWidget(_app(const CustomerRefundCard(orderId: 'ORD-1'), overrides: _withCase(null, actions)));
      await tester.pumpAndSettle();
      expect(find.byType(RefundStatusChip), findsNothing);
      await tester.pumpWidget(_app(const CustomerRefundCard(orderId: 'ORD-1'), overrides: [
        refundCaseProvider('ORD-1').overrideWith((ref) => Stream<RefundCase?>.error('offline')),
        refundActionsProvider.overrideWithValue(actions),
      ]));
      await tester.pumpAndSettle();
      expect(find.text("Couldn't load the refund."), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('Telugu: the same states in the customer\'s language', (tester) async {
      final k = _case(status: 'awaitingCustomerConfirmation', extra: {'activeAttempt': _attempt, 'pendingPaise': 12500});
      await tester.pumpWidget(_app(const CustomerRefundCard(orderId: 'ORD-1'), overrides: _withCase(k, FakeRefundActions()), locale: const Locale('te')));
      await tester.pumpAndSettle();
      expect(find.text('రీఫండ్ పంపబడింది — మీ నిర్ధారణ కోసం వేచి ఉంది'), findsOneWidget);
      expect(find.text('నాకు అందింది'), findsOneWidget);
    });

    testWidgets('the refunds list: each refund with its own status and amount', (tester) async {
      final list = [
        _case(status: 'awaitingCustomerConfirmation', extra: {'orderId': 'ORD-A', 'pendingPaise': 12500}),
        _case(status: 'refunded', extra: {'orderId': 'ORD-B', 'refundedPaise': 9000, 'outstandingPaise': 0}),
      ];
      await tester.pumpWidget(ProviderScope(
        overrides: [myRefundsProvider.overrideWith((ref) => Stream.value(list))],
        child: const MaterialApp(localizationsDelegates: AppLocalizations.localizationsDelegates, supportedLocales: AppLocalizations.supportedLocales, home: RefundsScreen()),
      ));
      await tester.pumpAndSettle();
      expect(find.text('Fresh Mart · Refund initiated — awaiting confirmation'), findsOneWidget);
      expect(find.text('Fresh Mart · Refund confirmed'), findsOneWidget);
      expect(find.text(AppFormat.currency(125)), findsOneWidget);
      expect(find.text(AppFormat.currency(90)), findsOneWidget);
      expect(find.textContaining('balance'), findsNothing);
    });
  });

  group('36: shop', () {
    testWidgets('the refund owed, where to send it, and "Record refund" with the UTR, date and amount', (tester) async {
      final actions = FakeRefundActions();
      await tester.pumpWidget(_app(const VendorRefundCard(orderId: 'ORD-1'), overrides: _withCase(_case(), actions)));
      await tester.pumpAndSettle();
      expect(find.text('Refund owed to the customer: ₹125.00'), findsOneWidget);
      expect(find.text('Send it back to the UPI account that paid you (their payment ref CUST123456).'), findsOneWidget);
      await tester.tap(find.byKey(const Key('recordRefund')));
      await tester.pumpAndSettle();
      expect(find.text('Record refund'), findsWidgets);
    });

    testWidgets('the sheet checks the amount and UTR, records once, and reuses the request id on retry', (tester) async {
      final actions = FakeRefundActions();
      await tester.pumpWidget(_app(RecordRefundSheet(refund: _case(), today: DateTime(2026, 11, 2)), overrides: _withCase(_case(), actions)));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('refundAmount')), '200');
      await tester.enterText(find.byKey(const Key('refundUtr')), '4123 4567 8901');
      await tester.tap(find.byKey(const Key('refundSubmit')));
      await tester.pumpAndSettle();
      expect(find.text('That\'s more than the ₹125.00 still owed.'), findsOneWidget);
      expect(actions.calls, isEmpty);
      await tester.enterText(find.byKey(const Key('refundAmount')), '125');
      actions.failNext = const OrderActionException("We couldn't reach the server. Check your connection and try again.");
      await tester.tap(find.byKey(const Key('refundSubmit')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('refundError')), findsOneWidget);
      await tester.tap(find.byKey(const Key('refundSubmit')));
      await tester.pumpAndSettle();
      expect(actions.calls.length, 2);
      expect(actions.calls[0]['requestId'], actions.calls[1]['requestId'], reason: 'a retry is the same request');
      expect([actions.calls[1]['amountPaise'], actions.calls[1]['upiReference'], actions.calls[1]['paidOn']], [12500, '4123 4567 8901', '2026-11-02']);
    });

    testWidgets('awaiting, disputed, and an amount Quicky is still checking: no "Record refund"', (tester) async {
      final actions = FakeRefundActions();
      final cases = [
        _case(status: 'awaitingCustomerConfirmation', extra: {'activeAttempt': _attempt, 'pendingPaise': 12500}),
        _case(status: 'refundDisputed', extra: {'openDispute': {'transferId': 'rf_1', 'response': 'notReceived', 'amountPaise': 12500}}),
        _case(status: 'refundReviewRequired', extra: {'owedPaise': null, 'outstandingPaise': null, 'reviewReasons': ['legacyNoMoneySnapshot']}),
      ];
      for (final k in cases) {
        await tester.pumpWidget(_app(const VendorRefundCard(orderId: 'ORD-1'), overrides: _withCase(k, actions)));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('recordRefund')), findsNothing, reason: k.status.name);
      }
      expect(find.text('Quicky is checking the amount for this older order before a refund can be recorded.'), findsOneWidget);
      await tester.pumpWidget(_app(const VendorRefundCard(orderId: 'ORD-1'), overrides: _withCase(cases[1], actions)));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('vendorRefundDispute')), findsOneWidget);
      expect(find.text('Refund disputed'), findsOneWidget);
    });
  });

  group('37: Manager', () {
    testWidgets('their orders\' refunds with what\'s owed; they escalate, never confirm', (tester) async {
      final actions = FakeRefundActions();
      final list = [
        _case(extra: {'orderId': 'ORD-A'}),
        _case(status: 'refundReviewRequired', extra: {'orderId': 'ORD-B', 'escalation': {'open': true, 'reason': 'Shop not answering'}}),
        _case(status: 'refunded', extra: {'orderId': 'ORD-C', 'refundedPaise': 12500, 'outstandingPaise': 0}),
      ];
      await tester.pumpWidget(ProviderScope(
        overrides: [managerRefundsProvider.overrideWith((ref) => Stream.value(list)), refundActionsProvider.overrideWithValue(actions)],
        child: const MaterialApp(home: ManagerRefundsScreen()),
      ));
      await tester.pumpAndSettle();
      expect(find.text('2 open · ₹250.00 still owed to customers by shops'), findsOneWidget);
      expect(find.text('Escalated to Quicky: Shop not answering'), findsOneWidget);
      expect(find.byKey(const Key('escalateRefund_ORD-B')), findsNothing);
      expect(find.byKey(const Key('escalateRefund_ORD-C')), findsNothing);
      expect(find.text('I received it'), findsNothing);
      await tester.tap(find.byKey(const Key('escalateRefund_ORD-A')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('escalateReason')), 'Shop has not refunded for 5 days');
      await tester.pump();
      await tester.tap(find.byKey(const Key('escalateSubmit')));
      await tester.pumpAndSettle();
      expect(actions.calls.single, {'fn': 'escalate', 'orderId': 'ORD-A', 'reason': 'Shop has not refunded for 5 days'});
    });
  });

  group('Phase I.7.1: overdue refunds', () {
    Map<String, dynamic> overdue(String stage, {int hours = 30, Map<String, dynamic> extra = const {}}) => {
      'dueAt': Timestamp.fromDate(DateTime.now().subtract(Duration(hours: hours, minutes: 5))),
      'escalationStage': stage,
      'overdue': {'stage': stage, ...extra},
    };

    test('age and escalation wording: awaiting confirmation is never "unpaid"; confirmed stops it', () {
      expect(ageLabel(5), '5 h');
      expect(ageLabel(49), '2 d 1 h');
      expect(istLabel(DateTime.utc(2026, 11, 2, 9, 35)), '2 Nov, 3:05 PM IST');
      expect(_case(extra: overdue('managerFollowUp')).escalationLabel, 'Over 24 h · Manager following up');
      expect(_case(status: 'awaitingCustomerConfirmation', extra: overdue('adminReview', hours: 50)).escalationLabel, 'Over 48 h, awaiting confirmation · with Quicky for review');
      expect(_case(status: 'refunded', extra: overdue('adminReview', hours: 50)).escalationLabel, 'Was overdue; now confirmed');
      expect(_case().escalationLabel, '');
      expect(_case(extra: overdue('managerFollowUp')).ageHours(), 30);
    });

    testWidgets('the shop sees how long it has owed and that its Manager is following up', (tester) async {
      final k = _case(extra: overdue('managerFollowUp', extra: {'lastNotifiedAt': Timestamp.fromDate(DateTime.utc(2026, 11, 2, 9, 35))}));
      await tester.pumpWidget(_app(const VendorRefundCard(orderId: 'ORD-1'), overrides: _withCase(k, FakeRefundActions())));
      await tester.pumpAndSettle();
      expect(find.textContaining('Owed for 1 d 6 h'), findsOneWidget);
      expect(find.textContaining('Over 24 h · Manager following up'), findsOneWidget);
      expect(find.byKey(const Key('recordRefund')), findsOneWidget, reason: 'overdue changes nothing about what the shop can do');
    });

    testWidgets('the Manager: overdue first, a follow-up note (never a confirmation), last notified', (tester) async {
      final actions = FakeRefundActions();
      final list = [
        _case(extra: {'orderId': 'ORD-NEW', 'dueAt': Timestamp.fromDate(DateTime.now().subtract(const Duration(hours: 3)))}),
        _case(status: 'awaitingCustomerConfirmation', extra: {'orderId': 'ORD-OLD', ...overdue('managerFollowUp', extra: {'lastNotifiedAt': Timestamp.fromDate(DateTime.utc(2026, 11, 2, 9, 35))})}),
      ];
      await tester.pumpWidget(ProviderScope(
        overrides: [managerRefundsProvider.overrideWith((ref) => Stream.value(list)), refundActionsProvider.overrideWithValue(actions)],
        child: const MaterialApp(home: ManagerRefundsScreen()),
      ));
      await tester.pumpAndSettle();
      expect(find.text('1 overdue (24 h or more): please follow up with the shop.'), findsOneWidget);
      expect(find.text('Over 24 h, awaiting confirmation · Manager following up'), findsOneWidget);
      expect(find.textContaining('Last notified 2 Nov, 3:05 PM IST'), findsOneWidget);
      expect(tester.getTopLeft(find.byKey(const Key('refundListTile_ORD-OLD'))).dy, lessThan(tester.getTopLeft(find.byKey(const Key('refundListTile_ORD-NEW'))).dy));
      expect(find.byKey(const Key('followUpRefund_ORD-NEW')), findsNothing, reason: 'not overdue yet');
      expect(find.text('I received it'), findsNothing);
      await tester.tap(find.byKey(const Key('followUpRefund_ORD-OLD')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('escalateReason')), 'Called the shop; refund promised today');
      await tester.pump();
      await tester.tap(find.byKey(const Key('escalateSubmit')));
      await tester.pumpAndSettle();
      expect([actions.calls.single['fn'], actions.calls.single['orderId'], actions.calls.single['remark']], ['followUp', 'ORD-OLD', 'Called the shop; refund promised today']);
      expect((actions.calls.single['requestId'] as String).length, 24);
    });
  });
}
