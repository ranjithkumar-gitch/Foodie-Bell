import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodiebell/core/session/access_scope.dart';
import 'package:foodiebell/core/session/session_controller.dart';
import 'package:foodiebell/data/models/account.dart';
import 'package:foodiebell/data/providers/firestore_managers_provider.dart';
import 'package:foodiebell/data/providers/firestore_vendors_provider.dart';
import 'package:foodiebell/features/manager/vendors/manager_vendor_list_screen.dart';
import 'package:foodiebell/l10n/generated/app_localizations.dart';

/// Phase I.5: a territory's Managers each run their own shops. The vendor
/// list shows "My Vendors" (full records) by default, and the territory's
/// sanitized directory in the other filters; another Manager's shop opens
/// a read-only summary, never its management screen or contact details.
const _me = Account(id: 'mA', role: AppRole.manager, name: 'Manager A', phone: '9000000001', territoryId: 't1', territory: 'Chityal', managerCode: 'A1');

class _SignedIn extends SessionController {
  _SignedIn(super.ref) {
    state = const SessionState(role: AppRole.manager, stage: AuthStage.active, account: _me);
  }
}

Account _shop(String id, String name, String managerId, {AccountStatus status = AccountStatus.active, String phone = ''}) => Account(
  id: id,
  role: AppRole.vendor,
  name: name,
  phone: phone,
  territoryId: 't1',
  category: 'grocery',
  status: status,
  assignedManagerId: managerId,
  assignmentStatus: 'assigned',
);

final _mine = [_shop('v1', 'Fresh Mart', 'mA', phone: '9000000002'), _shop('v2', 'Corner Store', 'mA', status: AccountStatus.pendingReview, phone: '9000000003')];
// The directory carries no phone numbers.
final _directory = [
  _shop('v1', 'Fresh Mart', 'mA'),
  _shop('v2', 'Corner Store', 'mA', status: AccountStatus.pendingReview),
  _shop('v3', 'Bala Bakery', 'mB'),
  _shop('v4', 'Closed Kirana', 'mC', status: AccountStatus.suspended),
];

Widget _app() => ProviderScope(
  overrides: [
    sessionControllerProvider.overrideWith((ref) => _SignedIn(ref)),
    firestoreVendorsProvider.overrideWith((ref) => Stream.value(_mine)),
    territoryVendorDirectoryProvider.overrideWith((ref) => Stream.value(_directory)),
    firestoreManagersProvider.overrideWith((ref) => Stream.value(const [
      Account(id: 'mB', role: AppRole.manager, name: 'Manager B', phone: '1'),
      Account(id: 'mC', role: AppRole.manager, name: 'Manager C', phone: '2'),
    ])),
  ],
  child: MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: const ManagerVendorListScreen(),
  ),
);

void main() {
  testWidgets('My Vendors is the default: only my shops, with their contact', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    expect(find.text('Fresh Mart'), findsOneWidget);
    expect(find.text('Corner Store'), findsOneWidget);
    expect(find.text('Bala Bakery'), findsNothing);
    expect(find.textContaining('9000000002'), findsOneWidget);
  });

  testWidgets("All Territory and Other Managers' show the directory: who runs each shop, no phone numbers", (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    await tester.tap(find.text('All Territory'));
    await tester.pumpAndSettle();
    for (final name in ['Fresh Mart', 'Corner Store', 'Bala Bakery', 'Closed Kirana']) {
      expect(find.text(name), findsOneWidget);
    }
    expect(find.text('Managed by Manager B'), findsOneWidget);
    expect(find.text('Managed by Manager C'), findsOneWidget);
    expect(find.textContaining('9000000'), findsNothing);

    await tester.tap(find.text("Other Managers'"));
    await tester.pumpAndSettle();
    expect(find.text('Bala Bakery'), findsOneWidget);
    expect(find.text('Closed Kirana'), findsOneWidget);
    expect(find.text('Fresh Mart'), findsNothing);
  });

  testWidgets('Active and Inactive filter the directory by status', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Active'));
    await tester.pumpAndSettle();
    expect(find.text('Bala Bakery'), findsOneWidget);
    expect(find.text('Closed Kirana'), findsNothing);
    await tester.tap(find.text('Inactive'));
    await tester.pumpAndSettle();
    expect(find.text('Closed Kirana'), findsOneWidget);
    expect(find.text('Corner Store'), findsOneWidget);
    expect(find.text('Bala Bakery'), findsNothing);
  });

  testWidgets("another Manager's shop opens a read-only summary", (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    await tester.tap(find.text("Other Managers'"));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bala Bakery'));
    await tester.pumpAndSettle();
    expect(find.textContaining('run by another Manager'), findsOneWidget);
    expect(find.text('Manager B'), findsOneWidget);
  });

  test('isAssignedTo needs an assigned record for that Manager', () {
    expect(_shop('v', 'x', 'mA').isAssignedTo('mA'), isTrue);
    expect(_shop('v', 'x', 'mA').isAssignedTo('mB'), isFalse);
    const pending = Account(id: 'v', role: AppRole.vendor, name: 'x', phone: '', assignedManagerId: 'mA', assignmentStatus: 'pending');
    expect(pending.isAssignedTo('mA'), isFalse);
    // The scope a Manager's queries are built from.
    expect(const AccessScope(role: AppRole.manager, accountId: 'mA', territoryId: 't1', isActive: true).accountId, 'mA');
  });

  test("the shop's orders-paused messages exist in English and Telugu", () {
    for (final code in ['en', 'te']) {
      final l = lookupAppLocalizations(Locale(code));
      expect(l.vendorOrdersPausedTitle, isNotEmpty);
      expect(l.vendorNoManagerBody, isNotEmpty);
      expect(l.vendorManagerInactiveBody, isNotEmpty);
    }
    expect(lookupAppLocalizations(const Locale('te')).vendorNoManagerBody, isNot(lookupAppLocalizations(const Locale('en')).vendorNoManagerBody));
  });
}
