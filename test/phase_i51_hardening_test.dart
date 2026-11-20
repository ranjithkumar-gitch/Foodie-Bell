import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodiebell/core/session/session_controller.dart';
import 'package:foodiebell/data/models/account.dart';
import 'package:foodiebell/data/models/category.dart';
import 'package:foodiebell/data/models/territory.dart';
import 'package:foodiebell/data/providers/firestore_categories_provider.dart';
import 'package:foodiebell/data/providers/firestore_territories_provider.dart';
import 'package:foodiebell/features/manager/categories/manager_categories_screen.dart';

/// Phase I.5.1: a territory's category settings are the Super Admin's. A
/// Manager sees which categories are available but can't change them (the
/// rules refuse it too).
const _me = Account(id: 'mA', role: AppRole.manager, name: 'Manager A', phone: '9000000001', territoryId: 't1', territory: 'Chityal');

class _SignedIn extends SessionController {
  _SignedIn(super.ref) {
    state = const SessionState(role: AppRole.manager, stage: AuthStage.active, account: _me);
  }
}

void main() {
  testWidgets('Manager category screen: read-only, says who can change it', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        sessionControllerProvider.overrideWith((ref) => _SignedIn(ref)),
        firestoreTerritoriesProvider.overrideWith((ref) => Stream.value(const [Territory(id: 't1', name: 'Chityal', zipcodes: [], disabledCategoryIds: ['meat'])])),
        activeCategoriesProvider.overrideWithValue(const AsyncData([
          Category(id: 'grocery', name: 'Grocery', iconKey: 'store'),
          Category(id: 'meat', name: 'Meat', iconKey: 'store'),
        ])),
      ],
      child: const MaterialApp(home: ManagerCategoriesScreen()),
    ));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('categoriesReadOnlyNotice')), findsOneWidget);
    expect(find.textContaining('Only QuickMandi (the Super Admin)'), findsOneWidget);
    final switches = tester.widgetList<SwitchListTile>(find.byType(SwitchListTile)).toList();
    expect(switches, hasLength(2));
    expect(switches.every((s) => s.onChanged == null), isTrue, reason: 'no Manager toggles');
    expect(find.text('Off in this territory'), findsOneWidget);
    expect(find.text('Available'), findsOneWidget);
  });
}
