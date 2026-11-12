import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../router/app_router.dart';
import '../session/access_scope.dart';
import 'live_order_card.dart';

/// Where a tapped notification wants to go — set from outside the widget
/// tree (the notification plugin's tap callback, FCM's opened-app message),
/// opened by [listenForNotificationTaps] once someone is signed in.
final pendingNotificationRoute = ValueNotifier<String?>(null);

final _pendingRouteProvider = ChangeNotifierProvider<ValueNotifier<String?>>((ref) => pendingNotificationRoute);

/// The route of an order push's data (an iPhone tap on a live order alert).
String? routeForPushData(Map<String, dynamic> data) {
  final orderId = data['orderId'];
  if (data['live'] != '1' || orderId is! String) return null;
  return liveOrderRoute(role: data['role'] as String? ?? 'user', orderId: orderId, status: data['type'] as String? ?? '');
}

/// Catches taps that open the app: a live order card (Android) or a live
/// order alert (iPhone), whether the app was running or closed.
Future<void> captureNotificationLaunch() async {
  FirebaseMessaging.onMessageOpenedApp.listen((m) {
    final route = routeForPushData(m.data);
    if (route != null) pendingNotificationRoute.value = route;
  });
  final initial = await FirebaseMessaging.instance.getInitialMessage();
  final route = (initial == null ? null : routeForPushData(initial.data)) ?? await liveOrderLaunchRoute();
  if (route != null) pendingNotificationRoute.value = route;
}

/// Opens a tapped notification's screen once a session is ready.
void listenForNotificationTaps(WidgetRef ref) {
  void open() {
    final route = pendingNotificationRoute.value;
    if (route == null || ref.read(accessScopeProvider) == null) return;
    pendingNotificationRoute.value = null;
    // After this frame: a tap can arrive while the tree is building.
    Future.microtask(() => ref.read(appRouterProvider).push(route));
  }

  ref.listen(_pendingRouteProvider, (_, _) => open());
  ref.listen(accessScopeProvider, (_, _) => open());
}
