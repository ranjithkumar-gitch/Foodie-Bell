// "Delete all" on the Notifications screens: asks first; personal
// notifications are deleted on the server, and shared rows (Admin
// broadcasts, chat messages) from before then are hidden on this device.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodiebell/core/notifications/fcm_topics.dart';
import 'package:foodiebell/shared/widgets/notification_wall.dart';
import 'package:shared_preferences/shared_preferences.dart';

WallItem _item(String id, DateTime at, {bool deletable = true}) =>
    WallItem(id: id, title: 'Title $id', body: 'Body', createdAt: at, deletable: deletable);

void main() {
  final t0 = DateTime(2026, 11, 12, 10);

  test('after Delete all, older shared rows are hidden; newer ones and personal rows stay', () {
    final items = [
      _item('old-broadcast', t0, deletable: false),
      _item('new-broadcast', t0.add(const Duration(hours: 2)), deletable: false),
      _item('personal', t0),
    ];
    expect(visibleWallItems(items, null).length, 3);
    expect(visibleWallItems(items, t0.add(const Duration(hours: 1))).map((i) => i.id), ['new-broadcast', 'personal']);
  });

  testWidgets('Delete all asks first; Cancel deletes nothing', (tester) async {
    SharedPreferences.setMockInitialValues({});
    var deleted = 0;
    await tester.pumpWidget(ProviderScope(
      overrides: [currentAccountIdProvider.overrideWithValue('d1')],
      child: MaterialApp(
        home: Scaffold(
          body: NotificationWall(items: [_item('a', DateTime.now())], onDelete: (_) => deleted++),
        ),
      ),
    ));
    expect(find.byKey(const Key('deleteAllNotifications')), findsOneWidget);
    await tester.tap(find.byKey(const Key('deleteAllNotifications')));
    await tester.pumpAndSettle();
    expect(find.text('Delete all notifications?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Title a'), findsOneWidget);
    expect(deleted, 0);
  });

  testWidgets('an empty wall has no Delete all button', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [currentAccountIdProvider.overrideWithValue('d1')],
      child: const MaterialApp(home: Scaffold(body: NotificationWall(items: [], onDelete: _noop))),
    ));
    expect(find.byKey(const Key('deleteAllNotifications')), findsNothing);
  });
}

void _noop(WallItem _) {}
