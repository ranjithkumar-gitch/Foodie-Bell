import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/account.dart';
import '../router/app_router.dart';
import '../session/session_controller.dart';

/// Where a notification leads (2026-11-17), for every role — used when a
/// phone notification is tapped (a push, or one the app posted itself)
/// and when a row on a Notifications screen is tapped.
///
/// A notification carries `orderId` and `type` (the order status it's
/// about, `refund`, `offer` for a Driver's new-delivery ping, or `chat`).
/// Null when there's nowhere more specific than the Notifications screen.
String? notificationRoute(AppRole role, {String? orderId, String? type}) {
  final id = (orderId == null || orderId.isEmpty) ? null : orderId;
  switch (role) {
    case AppRole.user:
      if (id == null) return null;
      return type == 'chat' ? '/user/order/$id/chat' : '/user/order/$id';
    case AppRole.vendor:
      if (type == 'refund') return '/vendor/refunds';
      return id == null ? null : '/vendor/order/$id';
    case AppRole.driver:
      if (id == null) return type == 'offer' ? '/driver/home' : null;
      return switch (type) {
        'offer' || 'vendorAccepted' => '/driver/offer/$id',
        'driverAssigned' => '/driver/delivery/$id/navigate-vendor',
        'pickedUp' => '/driver/delivery/$id/navigate-customer',
        'chat' => '/driver/delivery/$id/chat',
        'delivered' => '/driver/history',
        _ => '/driver/home',
      };
    case AppRole.manager:
      if (type == 'refund') return '/manager/refunds';
      return '/manager/orders';
    case AppRole.admin:
      return null;
  }
}

/// Bottom-tab pages: opened with `go` (switching tab), never pushed on top
/// of a page outside their shell — see the shell-branch navigation note
/// in `app_router.dart`. Everything else [notificationRoute] returns is a
/// full-screen page that's pushed, so Back returns to where the User was.
const _shellRoutes = {'/driver/home', '/driver/history'};

/// Opens [route] from anywhere: a tab is switched to, a page pushed.
void openRoute(GoRouter router, String route) {
  if (_shellRoutes.contains(route)) {
    router.go(route);
  } else {
    router.push(route);
  }
}

/// The same for a widget with a [BuildContext] (a Notifications screen row).
void openRouteFrom(BuildContext context, String route) => openRoute(GoRouter.of(context), route);

/// A tapped notification's data waiting to be opened — set from outside the
/// widget tree (FCM's opened-app callback, the local notification plugin's
/// tap callback), opened by [listenForNotificationTaps] once someone is
/// signed in and past the splash screen.
final pendingNotificationTap = ValueNotifier<Map<String, dynamic>?>(null);

/// The payload the app attaches to a notification it posts itself
/// (`local_notifications.dart`), the same keys a push carries.
String notificationPayload(Map<String, dynamic> data) => jsonEncode({
  if (data['orderId'] != null) 'orderId': data['orderId'],
  if (data['type'] != null) 'type': data['type'],
});

/// Records a tapped local notification's [payload] (see [notificationPayload]).
void handleLocalNotificationTap(String? payload) {
  if (payload == null || payload.isEmpty) return;
  try {
    final data = jsonDecode(payload);
    if (data is Map<String, dynamic>) pendingNotificationTap.value = data;
  } catch (e) {
    debugPrint('notification_routes: bad payload: $e');
  }
}

/// Called once from `main()`: catches taps on pushes that open the app,
/// whether it was in the background or closed.
Future<void> captureNotificationLaunch() async {
  FirebaseMessaging.onMessageOpenedApp.listen((m) {
    if (m.data.isNotEmpty) pendingNotificationTap.value = m.data;
  });
  try {
    final initial = await FirebaseMessaging.instance.getInitialMessage();
    if (initial != null && initial.data.isNotEmpty) pendingNotificationTap.value = initial.data;
  } catch (e) {
    debugPrint('notification_routes: getInitialMessage failed: $e');
  }
}

final _pendingTapProvider = ChangeNotifierProvider<ValueNotifier<Map<String, dynamic>?>>((ref) => pendingNotificationTap);

/// Wired once at the app root: opens a tapped notification's page once a
/// session is active and the app has left the splash/login screens (which
/// replace the whole stack and would drop a page pushed earlier).
void listenForNotificationTaps(WidgetRef ref) {
  void open() {
    final data = pendingNotificationTap.value;
    if (data == null) return;
    final session = ref.read(sessionControllerProvider);
    final role = session.role;
    if (role == null || session.account == null || session.stage != AuthStage.active) return;
    final router = ref.read(appRouterProvider);
    final path = router.routerDelegate.currentConfiguration.uri.path;
    if (path.isEmpty || path == '/' || path.startsWith('/splash') || path.startsWith('/auth')) {
      // Try again when navigation settles.
      void retry() {
        router.routerDelegate.removeListener(retry);
        Future.microtask(open);
      }
      router.routerDelegate.addListener(retry);
      return;
    }
    pendingNotificationTap.value = null;
    final route = notificationRoute(role, orderId: data['orderId'] as String?, type: data['type'] as String?);
    if (route == null || route == path) return;
    // After this frame: a tap can arrive while the tree is building.
    Future.microtask(() => openRoute(router, route));
  }

  ref.listen(_pendingTapProvider, (_, _) => open());
  ref.listen(sessionControllerProvider.select((s) => (s.role, s.stage, s.account?.id)), (_, _) => open());
}

/// A Notifications screen row's tap: opens the notification's page, or
/// null (row not tappable) when it has none.
VoidCallback? notificationTap(BuildContext context, AppRole role, {String? orderId, String? type}) {
  final route = notificationRoute(role, orderId: orderId, type: type);
  return route == null ? null : () => openRouteFrom(context, route);
}
