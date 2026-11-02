import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodiebell/data/models/account.dart';
import 'package:foodiebell/data/models/order.dart';
import 'package:foodiebell/data/providers/earnings_provider.dart';
import 'package:foodiebell/data/providers/firestore_vendors_provider.dart';
import 'package:foodiebell/data/providers/order_actions.dart';
import 'package:foodiebell/data/providers/settlement_provider.dart';
import 'package:foodiebell/data/providers/vendor_incidents_provider.dart';
import 'package:foodiebell/features/manager/incidents/manager_incidents_screen.dart';
import 'package:foodiebell/features/manager/settlement/cancellation_settlement_section.dart';
import 'package:foodiebell/features/manager/settlement/manager_daily_settlement_screen.dart';
import 'package:foodiebell/features/manager/vendors/vendor_reliability_card.dart';
import 'package:foodiebell/features/user/orders/shop_cancelled_banner.dart';
import 'package:foodiebell/features/vendor/orders/vendor_cancellation_sheets.dart';
import 'package:foodiebell/l10n/generated/app_localizations.dart';
import 'package:foodiebell/shared/cancellation_reasons.dart';
import 'package:foodiebell/shared/widgets/cancellation_money_cards.dart';
import 'package:foodiebell/shared/widgets/currency_text.dart';

/// Phase I.4 mobile: shop-cancellation money on the Vendor, Driver and
/// Manager screens, the customer's "the shop cancelled" message, the
/// Vendor's cancel/reject/accept sheets and the Manager's incident review.
/// Every amount comes from a server document or callable result; nothing
/// here is computed by the app.
final en = lookupAppLocalizations(const Locale('en'));

Widget _app(Widget home, {List<Override> overrides = const []}) => ProviderScope(
  overrides: overrides,
  child: MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: home),
  ),
);

String rs(int paise) => AppFormat.currency(paise / 100);

Order _order({OrderStatus status = OrderStatus.vendorAccepted, PaymentMethod method = PaymentMethod.cod}) => Order(
  id: 'ORD-TEST0001',
  vendorId: 'v1',
  vendorName: 'Shop',
  userId: 'c1',
  userName: 'Asha',
  userPhone: '9000000006',
  items: const [],
  deliveryAddressLabel: 'Home',
  paymentMethod: method,
  status: status,
  subtotal: 100,
  deliveryFee: 40,
  platformFee: 5,
  gstAmount: 0,
  total: 145,
  placedAt: DateTime(2026, 10, 30),
  rebatePercent: 10,
  territoryId: 't1',
);

const _quoteA = VendorCancellationQuote(
  scenario: 'A',
  chargePaise: 1000,
  driverSharePaise: 0,
  quickySharePaise: 1000,
  policyVersion: 1,
  driverAssigned: false,
  upiCancellationAllowed: true,
  deliveryFeePaise: 4000,
  bps: 2500,
);

const _quoteB = VendorCancellationQuote(
  scenario: 'B',
  chargePaise: 2000,
  driverSharePaise: 1000,
  quickySharePaise: 1000,
  policyVersion: 1,
  driverAssigned: true,
  upiCancellationAllowed: true,
  deliveryFeePaise: 4000,
  bps: 5000,
  driverShareBps: 5000,
);

void main() {
  // ---------------------------------------------------------------- cards
  group('vendor cancellation charges card', () {
    testWidgets('loading', (tester) async {
      await tester.pumpWidget(_app(const VendorCancellationChargesCard(totals: AsyncLoading())));
      expect(find.text(en.vendorCancellationCharges), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('error', (tester) async {
      await tester.pumpWidget(_app(VendorCancellationChargesCard(totals: AsyncError(Exception('offline'), StackTrace.empty))));
      expect(find.textContaining('Something went wrong'), findsOneWidget);
    });

    testWidgets('empty', (tester) async {
      await tester.pumpWidget(_app(const VendorCancellationChargesCard(totals: AsyncData(EarningsFigures({'earningsPaise': 50000})))));
      expect(find.text(en.cancelChargesNone), findsOneWidget);
    });

    testWidgets("charged / paid / owed are the server's figures, apart from earnings", (tester) async {
      await tester.pumpWidget(_app(const VendorCancellationChargesCard(
        totals: AsyncData(EarningsFigures({
          'earningsPaise': 50000,
          'cancellationCharges': 2,
          'cancellationChargesPaise': 3000,
          'cancellationChargesCollectedPaise': 1000,
          'cancellationChargesOutstandingPaise': 2000,
        })),
      )));
      expect(find.text(en.cancelChargesCharged), findsOneWidget);
      expect(find.text(rs(3000)), findsOneWidget);
      expect(find.text(rs(1000)), findsOneWidget);
      expect(find.text(rs(2000)), findsOneWidget);
      // Earnings aren't shown (or mixed in) here.
      expect(find.text(rs(50000)), findsNothing);
      // No reversal line unless the Super Admin reversed something.
      expect(find.text(en.cancelChargesReversed), findsNothing);
    });

    testWidgets('a reversal is shown when there is one', (tester) async {
      await tester.pumpWidget(_app(const VendorCancellationChargesCard(
        totals: AsyncData(EarningsFigures({'cancellationCharges': 1, 'cancellationChargesPaise': 1000, 'cancellationChargesReversedPaise': 1000})),
      )));
      expect(find.text(en.cancelChargesReversed), findsOneWidget);
    });
  });

  group('driver cancellation compensation card', () {
    testWidgets('loading / empty', (tester) async {
      await tester.pumpWidget(_app(const DriverCancellationCompCard(totals: AsyncLoading())));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.pumpWidget(_app(const DriverCancellationCompCard(totals: AsyncData(EarningsFigures({'earningsPaise': 9000})))));
      expect(find.text(en.driverCompNone), findsOneWidget);
    });

    testWidgets('error', (tester) async {
      await tester.pumpWidget(_app(DriverCancellationCompCard(totals: AsyncError(Exception('x'), StackTrace.empty))));
      expect(find.textContaining('Something went wrong'), findsOneWidget);
    });

    testWidgets('earned / paid / pending, apart from delivery fees', (tester) async {
      await tester.pumpWidget(_app(const DriverCancellationCompCard(
        totals: AsyncData(EarningsFigures({
          'earningsPaise': 9000,
          'cancellationCompensations': 2,
          'cancellationCompPaise': 1500,
          'cancellationCompPaidPaise': 500,
          'cancellationCompPendingPaise': 1000,
        })),
      )));
      expect(find.text(en.driverCompEarned), findsOneWidget);
      expect(find.text(en.driverCompPending), findsOneWidget);
      expect(find.text(rs(1500)), findsOneWidget);
      expect(find.text(rs(500)), findsOneWidget);
      expect(find.text(rs(1000)), findsOneWidget);
      expect(find.text(rs(9000)), findsNothing);
    });
  });

  // ------------------------------------------------------------- customer
  group('customer: the shop cancelled', () {
    testWidgets("shows who and why, never the shop's remark", (tester) async {
      final c = OrderCancellation.tryParse({
        'by': 'vendor',
        'cause': 'vendor',
        'stage': 'vendorAccepted',
        'reasonCode': postAcceptanceReasons.first,
        'remark': 'internal: owner went home early',
        'penalty': {'chargePaise': 1000, 'scenario': 'A'},
      })!;
      expect(c.byVendor, isTrue);
      await tester.pumpWidget(_app(ShopCancelledBanner(cancellation: c)));
      expect(find.text(en.orderCancelledByShop), findsOneWidget);
      expect(find.text(en.orderCancelledReason(reasonLabel(en, postAcceptanceReasons.first))), findsOneWidget);
      expect(find.textContaining('owner went home'), findsNothing);
      // The shop's charge is the shop's business, not the customer's.
      expect(find.text(rs(1000)), findsNothing);
    });

    testWidgets('no reason line without a reason code', (tester) async {
      await tester.pumpWidget(_app(const ShopCancelledBanner(cancellation: OrderCancellation(by: 'vendor', cause: 'vendor'))));
      expect(find.text(en.orderCancelledByShop), findsOneWidget);
      expect(find.textContaining(en.orderCancelledReason('').trim()), findsNothing);
    });
  });

  // --------------------------------------------------------- vendor sheets
  group('vendor accept / reject sheets', () {
    testWidgets('accept needs the availability confirmation', (tester) async {
      await tester.pumpWidget(_app(AvailabilityConfirmSheet(order: _order(status: OrderStatus.placed))));
      final button = find.widgetWithText(ElevatedButton, en.vendorAcceptButton);
      expect(tester.widget<ElevatedButton>(button).onPressed, isNull);
      await tester.tap(find.text(en.vendorAcceptConfirmCheckbox));
      await tester.pump();
      expect(tester.widget<ElevatedButton>(button).onPressed, isNotNull);
    });

    testWidgets('reject: "other" needs a remark', (tester) async {
      await tester.pumpWidget(_app(const RejectReasonSheet()));
      final button = find.widgetWithText(ElevatedButton, en.vendorRejectButton);
      expect(tester.widget<ElevatedButton>(button).onPressed, isNull);
      await tester.tap(find.text(reasonLabel(en, 'other')));
      await tester.pump();
      expect(tester.widget<ElevatedButton>(button).onPressed, isNull);
      await tester.enterText(find.byType(TextField), 'Gas cylinder ran out');
      await tester.pump();
      expect(tester.widget<ElevatedButton>(button).onPressed, isNotNull);
    });
  });

  group('vendor cancel sheet', () {
    Future<void> fill(WidgetTester tester) async {
      await tester.tap(find.text(reasonLabel(en, postAcceptanceReasons.first)));
      await tester.enterText(find.byType(TextField), 'Oven broke down, cannot cook today');
      await tester.pump();
    }

    testWidgets('loading while the server quotes the charge', (tester) async {
      final pending = Completer<VendorCancellationQuote>();
      await tester.pumpWidget(_app(VendorCancelOrderSheet(order: _order(), quote: (_) => pending.future, cancel: (_, {required quote, required reasonCode, required remark, required idempotencyKey}) async {})));
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text(en.vendorCancelConfirm), findsNothing);
      pending.complete(_quoteA);
      await tester.pumpAndSettle();
      expect(find.text(en.vendorCancelChargeNoDriver(rs(1000), '25', rs(4000))), findsOneWidget);
    });

    testWidgets('a quote error is shown, with no way to cancel', (tester) async {
      await tester.pumpWidget(_app(VendorCancelOrderSheet(
        order: _order(),
        quote: (_) async => throw const OrderActionException("This order can't be cancelled now."),
        cancel: (_, {required quote, required reasonCode, required remark, required idempotencyKey}) async {},
      )));
      await tester.pumpAndSettle();
      expect(find.text("This order can't be cancelled now."), findsOneWidget);
      expect(find.byType(ElevatedButton), findsNothing);
    });

    testWidgets('scenario B shows the driver share from the server', (tester) async {
      await tester.pumpWidget(_app(VendorCancelOrderSheet(order: _order(status: OrderStatus.driverAssigned), quote: (_) async => _quoteB, cancel: (_, {required quote, required reasonCode, required remark, required idempotencyKey}) async {})));
      await tester.pumpAndSettle();
      expect(find.text(en.vendorCancelChargeWithDriver(rs(2000), '50', rs(4000), rs(1000))), findsOneWidget);
    });

    testWidgets('a changed charge is re-shown and the retry sends the new quote with the same key', (tester) async {
      final calls = <({VendorCancellationQuote quote, String key})>[];
      await tester.pumpWidget(_app(VendorCancelOrderSheet(
        order: _order(),
        quote: (_) async => _quoteA,
        cancel: (_, {required quote, required reasonCode, required remark, required idempotencyKey}) async {
          calls.add((quote: quote, key: idempotencyKey));
          if (calls.length == 1) {
            throw const OrderActionException('The charge changed.', code: 'failed-precondition', details: {
              'quote': {'scenario': 'B', 'chargePaise': 2000, 'driverSharePaise': 1000, 'quickySharePaise': 1000, 'policyVersion': 1, 'driverAssigned': true, 'deliveryFeePaise': 4000, 'bps': 5000, 'driverShareBps': 5000},
            });
          }
        },
      )));
      await tester.pumpAndSettle();
      await fill(tester);
      await tester.ensureVisible(find.text(en.vendorCancelConfirm));
      await tester.tap(find.text(en.vendorCancelConfirm));
      await tester.pumpAndSettle();
      expect(find.text(en.vendorCancelChargeChanged), findsOneWidget);
      expect(find.text(en.vendorCancelChargeWithDriver(rs(2000), '50', rs(4000), rs(1000))), findsOneWidget);
      await tester.ensureVisible(find.text(en.vendorCancelConfirm));
      await tester.tap(find.text(en.vendorCancelConfirm));
      await tester.pumpAndSettle();
      expect(calls, hasLength(2));
      expect(calls[0].quote.chargePaise, 1000);
      expect(calls[1].quote.chargePaise, 2000);
      expect(calls[1].quote.scenario, 'B');
      expect(calls[1].key, calls[0].key);
    });

    testWidgets('UPI cancellation blocked by the server: no cancel button', (tester) async {
      const blocked = VendorCancellationQuote(scenario: 'A', chargePaise: 1000, driverSharePaise: 0, quickySharePaise: 1000, policyVersion: 1, driverAssigned: false, upiCancellationAllowed: false);
      await tester.pumpWidget(_app(VendorCancelOrderSheet(order: _order(method: PaymentMethod.upi), quote: (_) async => blocked, cancel: (_, {required quote, required reasonCode, required remark, required idempotencyKey}) async {})));
      await tester.pumpAndSettle();
      expect(find.text(en.vendorCancelUpiBlocked), findsOneWidget);
      expect(find.text(en.vendorCancelConfirm), findsNothing);
    });

    testWidgets('a short remark is refused before calling the server', (tester) async {
      var called = 0;
      await tester.pumpWidget(_app(VendorCancelOrderSheet(order: _order(), quote: (_) async => _quoteA, cancel: (_, {required quote, required reasonCode, required remark, required idempotencyKey}) async => called++)));
      await tester.pumpAndSettle();
      await tester.tap(find.text(reasonLabel(en, postAcceptanceReasons.first)));
      await tester.enterText(find.byType(TextField), 'too short');
      await tester.ensureVisible(find.text(en.vendorCancelConfirm));
      await tester.tap(find.text(en.vendorCancelConfirm));
      await tester.pump();
      expect(find.text(en.vendorCancelRemarkTooShort), findsOneWidget);
      expect(called, 0);
    });

    testWidgets('busy: a second tap does not cancel twice', (tester) async {
      var called = 0;
      final pending = Completer<void>();
      await tester.pumpWidget(_app(VendorCancelOrderSheet(order: _order(), quote: (_) async => _quoteA, cancel: (_, {required quote, required reasonCode, required remark, required idempotencyKey}) {
        called++;
        return pending.future;
      })));
      await tester.pumpAndSettle();
      await fill(tester);
      await tester.ensureVisible(find.text(en.vendorCancelConfirm));
      await tester.tap(find.text(en.vendorCancelConfirm));
      await tester.pump();
      final button = find.byType(ElevatedButton);
      expect(tester.widget<ElevatedButton>(button).onPressed, isNull);
      await tester.tap(button, warnIfMissed: false);
      await tester.pump();
      expect(called, 1);
      pending.complete();
      await tester.pumpAndSettle();
    });

    testWidgets('a refusal (e.g. not your order) is shown as the server says', (tester) async {
      await tester.pumpWidget(_app(VendorCancelOrderSheet(
        order: _order(),
        quote: (_) async => _quoteA,
        cancel: (_, {required quote, required reasonCode, required remark, required idempotencyKey}) async =>
            throw const OrderActionException("That order isn't yours.", code: 'permission-denied'),
      )));
      await tester.pumpAndSettle();
      await fill(tester);
      await tester.ensureVisible(find.text(en.vendorCancelConfirm));
      await tester.tap(find.text(en.vendorCancelConfirm));
      await tester.pumpAndSettle();
      expect(find.text("That order isn't yours."), findsOneWidget);
    });
  });

  // ------------------------------------------------------ manager incidents
  group('manager incident queue', () {
    final incident = VendorIncident('ORD-1_postAcceptanceCancellation', {
      'orderId': 'ORD-1',
      'vendorId': 'v1',
      'territoryId': 't1',
      'kind': 'postAcceptanceCancellation',
      'reasonCode': postAcceptanceReasons.first,
      'remark': 'Oven broke down mid-shift',
      'driverAssigned': true,
      'settlementDay': '2026-10-30',
      'reviewFlags': ['recentDriverRelease'],
      'penalty': {'scenario': 'B', 'chargePaise': 2000, 'driverSharePaise': 1000},
    });
    final legacy = VendorIncident('ORD-2_postAcceptanceCancellation', {
      'orderId': 'ORD-2',
      'vendorId': 'v1',
      'kind': 'postAcceptanceCancellation',
      'reasonCode': postAcceptanceReasons.first,
      'penalty': {'chargePaise': 0, 'noChargeReason': 'legacyOrderNoMoneySnapshot'},
    });
    final shop = Account(id: 'v1', role: AppRole.vendor, name: 'Ganesh Tiffins', phone: '9000000001', status: AccountStatus.active, territoryId: 't1');

    List<Override> overrides(Stream<List<VendorIncident>> incidents, {List<IncidentReview> reviews = const []}) => [
      territoryIncidentsProvider.overrideWith((ref) => incidents),
      incidentReviewsProvider.overrideWith((ref, id) => Stream.value(reviews)),
      firestoreVendorsProvider.overrideWith((ref) => Stream.value([shop])),
    ];

    Future<({String reviewId, bool duplicate})> never(String id, {required String outcome, String? note, String? requestId}) async => (reviewId: 'r', duplicate: false);

    testWidgets('loading', (tester) async {
      final c = StreamController<List<VendorIncident>>();
      await tester.pumpWidget(_app(ManagerIncidentsScreen(review: never), overrides: overrides(c.stream)));
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await c.close();
    });

    testWidgets('empty', (tester) async {
      await tester.pumpWidget(_app(ManagerIncidentsScreen(review: never), overrides: overrides(Stream.value(const []))));
      await tester.pumpAndSettle();
      expect(find.text('No shop has cancelled an accepted order.'), findsOneWidget);
    });

    testWidgets('unauthorized: another territory is refused by the rules', (tester) async {
      await tester.pumpWidget(_app(
        ManagerIncidentsScreen(review: never),
        overrides: overrides(Stream.error(FirebaseException(plugin: 'cloud_firestore', code: 'permission-denied'))),
      ));
      await tester.pumpAndSettle();
      expect(find.text('You can only see cancellations in your own territory.'), findsOneWidget);
    });

    testWidgets('other errors', (tester) async {
      await tester.pumpWidget(_app(ManagerIncidentsScreen(review: never), overrides: overrides(Stream.error(Exception('offline')))));
      await tester.pumpAndSettle();
      expect(find.textContaining('Something went wrong'), findsOneWidget);
    });

    testWidgets("list: shop, reason, remark, the server's charge, flags", (tester) async {
      await tester.pumpWidget(_app(ManagerIncidentsScreen(review: never), overrides: overrides(Stream.value([incident, legacy]))));
      await tester.pumpAndSettle();
      expect(find.text('Ganesh Tiffins'), findsNWidgets(2));
      expect(find.text(reasonLabel(en, postAcceptanceReasons.first)), findsNWidgets(2));
      expect(find.text('“Oven broke down mid-shift”'), findsOneWidget);
      expect(find.text('Charge ${rs(2000)} · driver gets ${rs(1000)}'), findsOneWidget);
      expect(find.text('No charge (order placed before charges applied)'), findsOneWidget);
      expect(find.text('Driver released just before'), findsOneWidget);
      expect(find.text('Not reviewed yet'), findsNWidgets(2));
    });

    testWidgets('shows the latest review', (tester) async {
      await tester.pumpWidget(_app(
        ManagerIncidentsScreen(review: never),
        overrides: overrides(Stream.value([incident]), reviews: [const IncidentReview('r1', {'outcome': 'excused', 'note': 'Power cut in the area', 'byRole': 'manager'})]),
      ));
      await tester.pumpAndSettle();
      expect(find.text('Reviewed: Excused — Power cut in the area'), findsOneWidget);
      expect(find.text('Review again'), findsOneWidget);
    });

    testWidgets('review: outcome required, excuse needs a note, success', (tester) async {
      final calls = <({String id, String outcome, String? note, String? requestId})>[];
      await tester.pumpWidget(_app(
        ManagerIncidentsScreen(review: (id, {required outcome, note, requestId}) async {
          calls.add((id: id, outcome: outcome, note: note, requestId: requestId));
          return (reviewId: 'r1', duplicate: false);
        }),
        overrides: overrides(Stream.value([incident])),
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Review'));
      await tester.pumpAndSettle();
      final save = find.widgetWithText(ElevatedButton, 'Save review');
      expect(tester.widget<ElevatedButton>(save).onPressed, isNull);
      await tester.tap(find.text('Excused'));
      await tester.pump();
      expect(find.text('Note (required)'), findsOneWidget);
      expect(find.textContaining('doesn’t refund the charge'), findsOneWidget);
      expect(tester.widget<ElevatedButton>(save).onPressed, isNull);
      await tester.enterText(find.byType(TextField), 'Power cut in the area');
      await tester.pump();
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(calls, hasLength(1));
      expect(calls.single.id, incident.id);
      expect(calls.single.outcome, 'excused');
      expect(calls.single.note, 'Power cut in the area');
      expect(calls.single.requestId, isNotEmpty);
      expect(find.text('Review saved.'), findsOneWidget);
    });

    testWidgets('a duplicate request returns the first review', (tester) async {
      await tester.pumpWidget(_app(
        ManagerIncidentsScreen(review: (id, {required outcome, note, requestId}) async => (reviewId: 'r1', duplicate: true)),
        overrides: overrides(Stream.value([incident])),
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Review'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Acknowledged'));
      await tester.pump();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Save review'));
      await tester.pumpAndSettle();
      expect(find.text('This review was already saved.'), findsOneWidget);
    });

    testWidgets('unauthorized review: shown in the sheet; the retry keeps the same request id', (tester) async {
      final ids = <String?>[];
      await tester.pumpWidget(_app(
        ManagerIncidentsScreen(review: (id, {required outcome, note, requestId}) async {
          ids.add(requestId);
          throw const OrderActionException("That incident isn't in your territory.", code: 'permission-denied');
        }),
        overrides: overrides(Stream.value([incident])),
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Review'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Warned'));
      await tester.pump();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Save review'));
      await tester.pumpAndSettle();
      expect(find.text("That incident isn't in your territory."), findsOneWidget);
      expect(find.text('Save review'), findsOneWidget); // still open
      await tester.tap(find.widgetWithText(ElevatedButton, 'Save review'));
      await tester.pumpAndSettle();
      expect(ids, hasLength(2));
      expect(ids[1], ids[0]);
    });

    testWidgets('busy: a second tap does not file a second review', (tester) async {
      var called = 0;
      final pending = Completer<({String reviewId, bool duplicate})>();
      await tester.pumpWidget(_app(IncidentReviewSheet(
        incident: incident,
        review: (id, {required outcome, note, requestId}) {
          called++;
          return pending.future;
        },
      )));
      await tester.tap(find.text('Acknowledged'));
      await tester.pump();
      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();
      expect(tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed, isNull);
      await tester.tap(find.byType(ElevatedButton), warnIfMissed: false);
      await tester.pump();
      expect(called, 1);
      pending.complete((reviewId: 'r', duplicate: false));
      await tester.pumpAndSettle();
    });
  });

  group('vendor reliability card', () {
    testWidgets('loading / none yet / error', (tester) async {
      await tester.pumpWidget(_app(const VendorReliabilityCard(reliability: AsyncLoading())));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.pumpWidget(_app(const VendorReliabilityCard(reliability: AsyncData(null))));
      expect(find.text('No cancellations or rejections recorded.'), findsOneWidget);
      await tester.pumpWidget(_app(VendorReliabilityCard(reliability: AsyncError(Exception('x'), StackTrace.empty))));
      expect(find.textContaining('Something went wrong'), findsOneWidget);
    });

    testWidgets("rolling figures, the server's rate and flags, marked provisional", (tester) async {
      await tester.pumpWidget(_app(const VendorReliabilityCard(
        reliability: AsyncData(VendorReliability({
          'rolling7': {'accepted': 10, 'cancellations': 3, 'rejections': 1},
          'rolling30': {'accepted': 40, 'cancellations': 4, 'rejections': 2, 'excused': 1, 'rate': 0.1},
          'flags': {'warning': true, 'reviewRequired': true, 'escalation': false, 'rules': ['review:7day'], 'reviewRequiredWeeks': [true, false, false], 'provisionalThresholds': false, 'thresholdsVersion': 'beta-2026-10-30'},
        })),
      )));
      expect(find.text('3 cancelled · 1 rejected · 10 accepted'), findsOneWidget);
      expect(find.text('4 cancelled · 2 rejected · 40 accepted'), findsOneWidget);
      expect(find.text('10.0%'), findsOneWidget);
      expect(find.text('Review needed'), findsOneWidget);
      expect(find.text('Escalated to Quicky'), findsNothing);
      expect(find.text('Flags are for information only — they never suspend, rank or charge a shop.'), findsOneWidget);
      expect(find.text('3 weeks running'), findsNothing);
    });

    testWidgets('review needed three weeks running, and an escalation', (tester) async {
      await tester.pumpWidget(_app(const VendorReliabilityCard(
        reliability: AsyncData(VendorReliability({
          'rolling30': {'accepted': 40, 'cancellations': 4, 'rate': 0.1},
          'flags': {'reviewRequired': true, 'escalation': true, 'rules': ['review:rate30', 'escalation:review3Weeks'], 'reviewRequiredWeeks': [true, true, true], 'provisionalThresholds': false},
        })),
      )));
      expect(find.text('Escalated to Quicky'), findsOneWidget);
      expect(find.text('3 weeks running'), findsOneWidget);
    });

    testWidgets('a record from before the approval says its thresholds were provisional', (tester) async {
      await tester.pumpWidget(_app(const VendorReliabilityCard(reliability: AsyncData(VendorReliability({'flags': {'provisionalThresholds': true}})))));
      expect(find.textContaining('provisional thresholds'), findsOneWidget);
    });
  });

  // ------------------------------------------------------ manager settlement
  group('settlement: cancellation section', () {
    const manager = 'manager:m1';
    Map<String, dynamic> statement({bool finance = true, List<Map<String, dynamic>> obligations = const []}) => {
      'settlementDay': '2026-10-30',
      'territoryId': 't1',
      // Net of everything, as the server keeps it: the shop owes 2000
      // charge + 500 order money; the Manager passes 1000 to the driver and
      // 1000 to Quicky.
      'remainingBalances': {'vendor:v1': 2500, manager: -500, 'driver:d1': -1000, 'quicky': -1000},
      'obligations': obligations,
      if (finance)
        'cancellationFinance': {
          'assessedPaise': 2000,
          'driverCompAssessedPaise': 1000,
          'quickyShareAssessedPaise': 1000,
          'collectedPaise': 0,
          'driverCompPaidPaise': 0,
          'remittedPaise': 0,
          'outstandingChargePaise': 2000,
          'outstandingDriverCompPaise': 1000,
          'outstandingRemittancePaise': 1000,
          'quickyRealizedPaise': 0,
          'disputedPaise': 0,
        },
    };
    Map<String, dynamic> ob(String from, String to, String purpose, int outstanding) =>
        {'from': from, 'to': to, 'purpose': purpose, 'openingPaise': 0, 'assessedPaise': outstanding, 'settledPaise': 0, 'disputedPaise': 0, 'outstandingPaise': outstanding};
    final rows = [
      ob('vendor:v1', manager, 'cancellationCharge', 2000),
      ob(manager, 'driver:d1', 'cancellationDriverComp', 1000),
      ob(manager, 'quicky', 'cancellationRemittance', 1000),
      ob('vendor:v1', manager, 'general', 500),
    ];

    Widget section(Map<String, dynamic> data, {RecordSettlementTransfer? record, Future<void> Function()? onRecorded}) => CancellationSettlementSection(
      statement: SettlementStatement(data),
      territoryId: 't1',
      managerKey: manager,
      partyName: (p) => p,
      onRecorded: onRecorded ?? () async {},
      record: record ?? ({required idempotencyKey, required territoryId, required day, required fromParty, required toParty, required amountPaise, required upi, reference, purpose}) async {},
      pickPayment: (context, title, suggested) async => (amountPaise: suggested, upi: true, reference: 'UTR123'),
    );

    test('order balances leave the cancellation obligations out', () {
      final s = SettlementStatement(statement(obligations: rows));
      expect(s.generalBalances, {'vendor:v1': 500, manager: -500});
      expect(s.obligations.where((o) => o.isCancellation), hasLength(3));
      expect(s.cancellationFinance!.outstandingChargePaise, 2000);
    });

    test('a statement from before Phase I.4 has no cancellation figures', () {
      final s = SettlementStatement(const {'settlementDay': '2026-01-01', 'remainingBalances': {'vendor:v1': 100}});
      expect(s.obligations, isEmpty);
      expect(s.cancellationFinance, isNull);
      expect(s.generalBalances, {'vendor:v1': 100});
    });

    testWidgets('a statement from before Phase I.4 shows nothing', (tester) async {
      await tester.pumpWidget(_app(section(statement(finance: false))));
      expect(find.text('Shop cancellations'), findsNothing);
    });

    testWidgets('empty day', (tester) async {
      await tester.pumpWidget(_app(section({...statement(), 'cancellationFinance': <String, dynamic>{'assessedPaise': 0}})));
      expect(find.text('No cancellation charges this day.'), findsOneWidget);
    });

    testWidgets("finance lines and one row per cancellation obligation, from the server's statement", (tester) async {
      await tester.pumpWidget(_app(SingleChildScrollView(child: section(statement(obligations: rows)))));
      expect(find.text('Charged to shops'), findsOneWidget);
      expect(find.text('Still owed by shops'), findsOneWidget);
      expect(find.text('Still to send Quicky'), findsOneWidget);
      expect(find.text('Cancellation charge'), findsOneWidget);
      expect(find.text('Driver cancellation compensation'), findsOneWidget);
      expect(find.text('Quicky’s share of cancellation charges'), findsOneWidget);
      // The general obligation is not in this section.
      expect(find.text('Order settlement'), findsNothing);
      expect(find.text('Got paid'), findsOneWidget);
      expect(find.text('Paid'), findsNWidgets(2));
    });

    testWidgets('a charge Quicky collects directly is shown but not recordable', (tester) async {
      await tester.pumpWidget(_app(section(statement(obligations: [ob('vendor:v1', 'quicky', 'cancellationCharge', 1000)]))));
      expect(find.text('Quicky settles this directly.'), findsOneWidget);
      expect(find.text('Got paid'), findsNothing);
      expect(find.text('Paid'), findsNothing);
    });

    testWidgets('records with the obligation purpose and parties; a retry reuses the key; success clears it', (tester) async {
      final calls = <Map<String, Object?>>[];
      var reloads = 0;
      await tester.pumpWidget(_app(SingleChildScrollView(child: section(
        statement(obligations: [rows.first]),
        onRecorded: () async => reloads++,
        record: ({required idempotencyKey, required territoryId, required day, required fromParty, required toParty, required amountPaise, required upi, reference, purpose}) async {
          calls.add({'key': idempotencyKey, 'from': fromParty, 'to': toParty, 'amount': amountPaise, 'purpose': purpose, 'day': day, 'territory': territoryId, 'ref': reference});
          if (calls.length == 1) throw const OrderActionException('Network timeout');
        },
      ))));
      await tester.tap(find.text('Got paid'));
      await tester.pumpAndSettle();
      expect(find.text('Network timeout'), findsOneWidget);
      await tester.tap(find.text('Got paid'));
      await tester.pumpAndSettle();
      expect(calls, hasLength(2));
      expect(calls[0], {'key': calls[0]['key'], 'from': 'vendor:v1', 'to': manager, 'amount': 2000, 'purpose': 'cancellationCharge', 'day': '2026-10-30', 'territory': 't1', 'ref': 'UTR123'});
      expect(calls[1]['key'], calls[0]['key']);
      expect(reloads, 1);
      // A later payment against the same obligation is a new one.
      await tester.tap(find.text('Got paid'));
      await tester.pumpAndSettle();
      expect(calls[2]['key'], isNot(calls[0]['key']));
    });

    testWidgets('busy: a second tap does not record twice', (tester) async {
      var called = 0;
      final pending = Completer<void>();
      await tester.pumpWidget(_app(section(
        statement(obligations: [rows[1]]),
        record: ({required idempotencyKey, required territoryId, required day, required fromParty, required toParty, required amountPaise, required upi, reference, purpose}) {
          called++;
          return pending.future;
        },
      )));
      await tester.tap(find.text('Paid'));
      await tester.pump();
      expect(find.text('Paid'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(called, 1);
      pending.complete();
      await tester.pumpAndSettle();
    });

    testWidgets('a refusal (not your territory) is shown as the server says', (tester) async {
      await tester.pumpWidget(_app(section(
        statement(obligations: [rows[2]]),
        record: ({required idempotencyKey, required territoryId, required day, required fromParty, required toParty, required amountPaise, required upi, reference, purpose}) async =>
            throw const OrderActionException("That territory isn't yours.", code: 'permission-denied'),
      )));
      await tester.tap(find.text('Paid'));
      await tester.pumpAndSettle();
      expect(find.text("That territory isn't yours."), findsOneWidget);
    });
  });

  group('settlement discrepancy labels', () {
    test("a disputed payment uses the server's type and says what it was for", () {
      final text = settlementDiscrepancyText(
        {'type': 'disputedPayment', 'transferId': 't', 'amountPaise': 1000, 'from': 'vendor:v1', 'to': 'manager:m1', 'purpose': 'cancellationCharge'},
        (p) => p,
      );
      expect(text, 'Cancellation charge payment of ${rs(1000)} was disputed (vendor:v1 → manager:m1)');
      expect(settlementDiscrepancyText({'type': 'disputedPayment', 'amountPaise': 500, 'from': 'a', 'to': 'b'}, (p) => p), startsWith('Order settlement payment'));
      expect(settlementDiscrepancyText({'type': 'noManager', 'amountPaise': 0}, (p) => p), 'This territory had no active manager on this day');
      expect(settlementDiscrepancyText({'type': 'codShortfall', 'amountPaise': 200, 'orderId': 'O1'}, (p) => p), contains('O1'));
    });
  });
}
