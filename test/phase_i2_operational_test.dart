import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodiebell/data/models/account.dart';
import 'package:foodiebell/data/models/category.dart';
import 'package:foodiebell/data/models/order.dart';
import 'package:foodiebell/data/models/territory.dart';
import 'package:foodiebell/data/providers/firestore_categories_provider.dart';
import 'package:foodiebell/data/providers/firestore_drivers_provider.dart';
import 'package:foodiebell/data/providers/firestore_orders_provider.dart';
import 'package:foodiebell/data/providers/firestore_products_provider.dart';
import 'package:foodiebell/data/providers/firestore_territories_provider.dart';
import 'package:foodiebell/data/providers/firestore_vendors_provider.dart';
import 'package:foodiebell/data/providers/order_actions.dart';
import 'package:foodiebell/data/providers/settlement_provider.dart';
import 'package:foodiebell/data/providers/trending_provider.dart';
import 'package:foodiebell/features/manager/oversight/reassign_driver_sheet.dart';
import 'package:foodiebell/features/manager/settlement/propose_adjustment_sheet.dart';
import 'package:foodiebell/features/user/home/selected_territory_provider.dart';
import 'package:foodiebell/features/user/search/search_screen.dart';
import 'package:foodiebell/l10n/generated/app_localizations.dart';

/// Phase I.2: the Manager's driver reassignment and adjustment proposals
/// (existing callables `reassignDriver`, `proposeSettlementAdjustment`), and
/// the territory's disabled categories on customer surfaces.
Widget _app(Widget home, {List<Override> overrides = const []}) => ProviderScope(
  overrides: overrides,
  child: MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: home),
  ),
);

Order _order({OrderStatus status = OrderStatus.driverAssigned, String? driverId = 'd1'}) => Order(
  id: 'ORD-TEST0001',
  vendorId: 'v1',
  vendorName: 'Shop',
  userId: 'c1',
  userName: 'Asha',
  userPhone: '9000000006',
  items: const [],
  deliveryAddressLabel: 'Home',
  paymentMethod: PaymentMethod.cod,
  status: status,
  subtotal: 100,
  deliveryFee: 20,
  platformFee: 5,
  gstAmount: 0,
  total: 125,
  placedAt: DateTime(2026, 10, 30),
  rebatePercent: 10,
  territoryId: 't1',
  driverId: driverId,
  driverName: driverId == null ? null : 'Ravi',
);

Account _driver(String id, String name, {AccountStatus status = AccountStatus.active, String territoryId = 't1', bool online = false}) =>
    Account(id: id, role: AppRole.driver, name: name, phone: '9000000000', status: status, territoryId: territoryId, isOnline: online);

void main() {
  group('driver reassignment', () {
    test('only an order assigned and not picked up can be reassigned', () {
      for (final s in OrderStatus.values) {
        expect(canReassignDriver(_order(status: s)), s == OrderStatus.driverAssigned, reason: s.name);
      }
      expect(canReassignDriver(_order(driverId: null)), isFalse);
    });

    test('offered drivers: active, same territory, not the current one; online first', () {
      final drivers = [
        _driver('d1', 'Ravi'),
        _driver('d2', 'Sai'),
        _driver('d3', 'Kiran', online: true),
        _driver('d4', 'Pending', status: AccountStatus.pendingReview),
        _driver('d5', 'Elsewhere', territoryId: 't2'),
      ];
      expect([for (final d in reassignableDrivers(drivers, _order())) d.id], ['d3', 'd2']);
    });

    List<Override> sheetOverrides({List<OrderEvent> events = const []}) => [
      firestoreDriversProvider.overrideWith((ref) => Stream.value([_driver('d1', 'Ravi'), _driver('d2', 'Sai')])),
      orderEventsProvider.overrideWith((ref, id) => Stream.value(events)),
    ];

    testWidgets('needs a choice and a reason, then reassigns to the chosen driver', (tester) async {
      final calls = <(String, String?, String)>[];
      await tester.pumpWidget(_app(
        ReassignDriverSheet(order: _order(), reassign: (id, {driverId, required reason}) async => calls.add((id, driverId, reason))),
        overrides: sheetOverrides(),
      ));
      await tester.pumpAndSettle();
      final button = find.widgetWithText(ElevatedButton, 'Reassign delivery');
      expect(tester.widget<ElevatedButton>(button).onPressed, isNull);
      await tester.tap(find.text('Sai'));
      await tester.pump();
      expect(tester.widget<ElevatedButton>(button).onPressed, isNull, reason: 'reason still missing');
      await tester.enterText(find.byType(TextField), 'Bike broke down');
      await tester.pump();
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(calls, [('ORD-TEST0001', 'd2', 'Bike broke down')]);
    });

    testWidgets('release sends no driver; a refusal is shown as the server says', (tester) async {
      final calls = <String?>[];
      await tester.pumpWidget(_app(
        ReassignDriverSheet(
          order: _order(),
          reassign: (id, {driverId, required reason}) async {
            calls.add(driverId);
            throw const OrderActionException('Only an order waiting for pickup can be reassigned.', code: 'failed-precondition');
          },
        ),
        overrides: sheetOverrides(),
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Release (no driver)'));
      await tester.enterText(find.byType(TextField), 'No driver free');
      await tester.pump();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Release delivery'));
      await tester.pumpAndSettle();
      expect(calls, [null]);
      expect(find.text('Only an order waiting for pickup can be reassigned.'), findsOneWidget);
    });

    testWidgets("shows the order's reassignment history from the server", (tester) async {
      await tester.pumpWidget(_app(
        ReassignDriverSheet(order: _order(), reassign: (id, {driverId, required reason}) async {}),
        overrides: sheetOverrides(events: [
          OrderEvent(type: 'driverReassigned', role: 'manager', details: const {'from': 'd2', 'to': 'd1', 'reason': 'Closer to the shop'}, at: DateTime.now()),
          const OrderEvent(type: 'vendorAccepted', role: 'vendor', details: {}),
        ]),
      ));
      await tester.pumpAndSettle();
      expect(find.text('Reassignment history'), findsOneWidget);
      expect(find.text('Sai → Ravi'), findsOneWidget);
      expect(find.textContaining('Closer to the shop'), findsOneWidget);
    });
  });

  group('settlement adjustment proposals', () {
    const managerKey = 'manager:m1';
    const statement = SettlementStatement({
      'territoryId': 't1',
      'settlementDay': '2026-10-30',
      'remainingBalances': {'driver:d1': 12000, 'vendor:v1': -9000, 'quicky': -1000},
      'orders': [
        {'orderId': 'ORD-A', 'vendorId': 'v1', 'driverId': 'd1', 'paymentMethod': 'cod'},
      ],
      'discrepancies': [
        {'type': 'codShortfall', 'orderId': 'ORD-A', 'amountPaise': 500},
        {'type': 'disputedTransfer', 'amountPaise': 300},
      ],
    });

    test("a COD shortfall suggests the order's driver paying the Manager the shortfall", () {
      final draft = adjustmentDraftFor(statement.discrepancies.first, statement, managerKey)!;
      expect([draft.from, draft.to, draft.amountPaise, draft.orderId], ['driver:d1', managerKey, 500, 'ORD-A']);
      expect(adjustmentDraftFor(statement.discrepancies.last, statement, managerKey), isNull);
      expect(adjustmentParties(statement, managerKey), containsAll([managerKey, 'quicky', 'driver:d1', 'vendor:v1']));
    });

    Widget sheet(ProposeAdjustmentSheet Function() build) => _app(Builder(builder: (_) => build()));

    testWidgets('prefilled from the shortfall, shows the server balances, sends one keyed proposal', (tester) async {
      final keys = <String?>[];
      var attempt = 0;
      await tester.pumpWidget(sheet(() => ProposeAdjustmentSheet(
        statement: statement,
        territoryId: 't1',
        managerKey: managerKey,
        partyName: (p) => p,
        draft: adjustmentDraftFor(statement.discrepancies.first, statement, managerKey),
        propose: ({required territoryId, required day, required fromParty, required toParty, required amountPaise, required reason, orderId, idempotencyKey}) async {
          keys.add(idempotencyKey);
          expect([territoryId, day, fromParty, toParty, amountPaise, orderId], ['t1', '2026-10-30', 'driver:d1', managerKey, 500, 'ORD-A']);
          if (attempt++ == 0) throw const OrderActionException("We couldn't reach the server. Check your connection and try again.", code: 'unavailable');
          return (adjustmentId: 'adj1', duplicate: false);
        },
      )));
      await tester.pump();
      expect(find.textContaining('owes ₹120'), findsOneWidget, reason: "the driver's balance from the statement");
      final send = find.widgetWithText(ElevatedButton, 'Send to Super Admin');
      await tester.tap(send);
      await tester.pump();
      expect(find.textContaining('Say what happened'), findsOneWidget);
      await tester.enterText(find.byType(TextField).last, 'Gave ₹5 less change');
      await tester.tap(send);
      await tester.pumpAndSettle();
      expect(find.textContaining("couldn't reach the server"), findsOneWidget);
      await tester.tap(send);
      await tester.pumpAndSettle();
      expect(keys.length, 2);
      expect(keys.first, keys.last, reason: 'a retry reuses the idempotency key');
      expect(keys.first, matches(RegExp(r'^[a-z0-9]{20}$')));
    });

    testWidgets('refuses the same party on both sides, before calling the server', (tester) async {
      var called = false;
      await tester.pumpWidget(sheet(() => ProposeAdjustmentSheet(
        statement: statement,
        territoryId: 't1',
        managerKey: managerKey,
        partyName: (p) => p,
        draft: (from: managerKey, to: managerKey, amountPaise: 100, orderId: null),
        propose: ({required territoryId, required day, required fromParty, required toParty, required amountPaise, required reason, orderId, idempotencyKey}) async {
          called = true;
          return (adjustmentId: 'x', duplicate: false);
        },
      )));
      await tester.enterText(find.byType(TextField).last, 'x');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Send to Super Admin'));
      await tester.pump();
      expect(find.text('Choose two different parties.'), findsOneWidget);
      expect(called, isFalse);
    });
  });

  group('territory category restrictions', () {
    const territory = Territory(id: 't1', name: 'Guntur', zipcodes: ['522001'], isActive: true, disabledCategoryIds: ['pharmacy']);
    Account vendor(String id, String name, String category) =>
        Account(id: id, role: AppRole.vendor, name: name, phone: '9000000000', status: AccountStatus.active, territoryId: 't1', territory: 'Guntur', category: category, isOpen: true);

    test('a vendor in a switched-off category is not shown or orderable', () {
      expect(vendorCategoryEnabled(vendor('v1', 'A', 'pharmacy'), territory), isFalse);
      expect(vendorCategoryEnabled(vendor('v2', 'B', 'food'), territory), isTrue);
      expect(vendorCategoryEnabled(vendor('v1', 'A', 'pharmacy'), null), isTrue, reason: 'territory not loaded yet');
    });

    testWidgets('search hides shops from a switched-off category', (tester) async {
      await tester.pumpWidget(_app(
        const SearchScreen(),
        overrides: [
          firestoreTerritoriesProvider.overrideWith((ref) => Stream.value(const [territory])),
          selectedTerritoryProvider.overrideWith((ref) => territory),
          activeCategoriesProvider.overrideWith((ref) => const AsyncValue<List<Category>>.data([])),
          firestoreVendorsProvider.overrideWith((ref) => Stream.value([vendor('v1', 'City Mart Pharmacy', 'pharmacy'), vendor('v2', 'City Mart Tiffins', 'food')])),
          catalogIndexProvider.overrideWith((ref, id) => Stream.value(const [])),
          trendingDishesProvider.overrideWith((ref, id) => Stream.value(const [])),
        ],
      ));
      await tester.pump();
      await tester.enterText(find.byType(TextField).first, 'city mart');
      await tester.pump();
      await tester.pump();
      expect(find.text('City Mart Tiffins'), findsWidgets);
      expect(find.text('City Mart Pharmacy'), findsNothing);
    });
  });
}
