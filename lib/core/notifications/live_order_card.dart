import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/account.dart';
import '../../data/models/order.dart';
import '../../data/providers/firestore_orders_provider.dart';
import '../session/access_scope.dart';

/// Live order card (2026-11-12, Swiggy/Zomato style) for customers and
/// drivers: ONE notification per order in the Android notification bar,
/// pinned while the order is in progress and updated in place at every step
/// (title, text, progress bar), then left as an ordinary notification when it
/// is delivered or cancelled.
///
/// Fed from two places, which draw the same card (same id and tag):
/// - the server's live pushes (`QuickyAdmin/functions/lib/live_order_push.js`),
///   data-only on Android, handled even when the app is in the background or
///   closed ([showLiveOrderCardFromPush], from the background handler);
/// - the app's own live order stream while it runs ([listenForLiveOrderCards]),
///   which also covers a driver's own steps (they get no push for those).
///
/// iPhone gets the server's alerts with a collapse id instead (each step
/// replaces the last); no card is drawn here on iOS.
final _plugin = FlutterLocalNotificationsPlugin();

const liveOrderChannel = AndroidNotificationChannel(
  'order_live_v1',
  'Order in progress',
  description: 'Your current order or delivery, updated at every step.',
  importance: Importance.high,
  playSound: true,
  enableVibration: true,
);

bool get _supported => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

/// The same notification id for an order in every isolate (FNV-1a, not
/// [String.hashCode], which isn't guaranteed stable).
int liveOrderNotificationId(String orderId) {
  var h = 0x811c9dc5;
  for (final c in orderId.codeUnits) {
    h ^= c;
    h = (h * 0x01000193) & 0x7fffffff;
  }
  return h;
}

String _tag(String orderId) => 'order_$orderId';

/// Where tapping the card leads.
String liveOrderRoute({required String role, required String orderId, required String status}) {
  if (role == 'driver') {
    return switch (status) {
      'driverAssigned' => '/driver/delivery/$orderId/navigate-vendor',
      'pickedUp' => '/driver/delivery/$orderId/navigate-customer',
      _ => '/driver/home',
    };
  }
  return '/user/order/$orderId';
}

/// What the card says. Matches the server's push wording for the same step,
/// so a push and the app drawing the same step don't alert twice.
class LiveOrderCard {
  const LiveOrderCard({
    required this.orderId,
    required this.role,
    required this.status,
    required this.title,
    required this.body,
    required this.step,
    required this.steps,
    this.subText,
  });

  final String orderId;
  final String role;
  final String status;
  final String title;
  final String body;
  final int step;
  final int steps;
  final String? subText;

  bool get terminal => const {'delivered', 'cancelled', 'rejected'}.contains(status);

  static const userSteps = ['placed', 'vendorAccepted', 'driverAssigned', 'pickedUp', 'delivered'];
  static const driverSteps = ['driverAssigned', 'pickedUp', 'delivered'];

  /// The card for [o] as [role] sees it; null when there's nothing to show.
  static LiveOrderCard? forOrder(Order o, String role) {
    final status = o.status.name;
    final shop = o.vendorName.isEmpty ? 'the shop' : o.vendorName;
    final driver = (o.driverName ?? '').isEmpty ? 'Your driver' : o.driverName!;
    final steps = role == 'driver' ? driverSteps : userSteps;
    final step = steps.indexOf(status) + 1;
    final (String, String)? text = role == 'driver'
        ? switch (o.status) {
            OrderStatus.driverAssigned => ('Pick up from $shop', 'Head to the shop and collect the order.'),
            OrderStatus.pickedUp => ('Deliver to ${o.userName.isEmpty ? 'the customer' : o.userName}', o.deliveryAddressFull ?? o.deliveryAddressLabel),
            _ => null,
          }
        : switch (o.status) {
            OrderStatus.placed => ('Order placed', 'Your order from $shop has been placed.'),
            OrderStatus.vendorAccepted => ('Order confirmed', '$shop accepted your order.'),
            OrderStatus.driverAssigned => ('Driver assigned', '$driver is picking up your order.'),
            OrderStatus.pickedUp => ('On the way', '$driver has picked up your order.'),
            _ => null,
          };
    if (text == null || step == 0) return null;
    return LiveOrderCard(orderId: o.id, role: role, status: status, title: text.$1, body: text.$2, step: step, steps: steps.length, subText: role == 'driver' ? 'Delivery ${o.id}' : shop);
  }

  /// The card from a live push's data (`live_order_push.js`); null if it isn't one.
  static LiveOrderCard? fromPush(Map<String, dynamic> data) {
    if (data['live'] != '1' || data['orderId'] is! String) return null;
    return LiveOrderCard(
      orderId: data['orderId'] as String,
      role: data['role'] as String? ?? 'user',
      status: data['type'] as String? ?? '',
      title: data['title'] as String? ?? 'Your order',
      body: data['body'] as String? ?? '',
      step: int.tryParse('${data['step']}') ?? 0,
      steps: int.tryParse('${data['steps']}') ?? 5,
      subText: (data['shop'] as String?)?.isNotEmpty == true ? data['shop'] as String : null,
    );
  }
}

/// Creates the channel; safe to call more than once and from a background isolate.
Future<void> initLiveOrderCards({void Function(String route)? onTap}) async {
  if (!_supported) return;
  await _plugin.initialize(
    const InitializationSettings(android: AndroidInitializationSettings('@mipmap/ic_launcher'), iOS: DarwinInitializationSettings()),
    onDidReceiveNotificationResponse: onTap == null
        ? null
        : (r) {
            final route = r.payload;
            if (route != null && route.startsWith('/')) onTap(route);
          },
  );
  await _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.createNotificationChannel(liveOrderChannel);
}

/// The route of the card that launched the app, if one did.
Future<String?> liveOrderLaunchRoute() async {
  if (!_supported) return null;
  final details = await _plugin.getNotificationAppLaunchDetails();
  final route = details?.didNotificationLaunchApp == true ? details!.notificationResponse?.payload : null;
  return route != null && route.startsWith('/') ? route : null;
}

/// The title of the card currently showing for [orderId], if any.
Future<String?> _showingTitle(String orderId) async {
  final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
  final active = await android?.getActiveNotifications() ?? const <ActiveNotification>[];
  return active.where((n) => n.id == liveOrderNotificationId(orderId) && n.tag == _tag(orderId)).firstOrNull?.title;
}

/// Draws or updates [card]. Unchanged cards are left alone (no repeat
/// sound); a new step alerts once.
Future<void> showLiveOrderCard(LiveOrderCard card) async {
  if (!_supported) return;
  if (await _showingTitle(card.orderId) == card.title) return;
  await _plugin.show(
    liveOrderNotificationId(card.orderId),
    card.title,
    card.body,
    NotificationDetails(
      android: AndroidNotificationDetails(
        liveOrderChannel.id,
        liveOrderChannel.name,
        channelDescription: liveOrderChannel.description,
        importance: Importance.high,
        priority: Priority.high,
        tag: _tag(card.orderId),
        ongoing: !card.terminal,
        autoCancel: card.terminal,
        showProgress: !card.terminal && card.steps > 0,
        maxProgress: card.steps,
        progress: card.step.clamp(0, card.steps),
        onlyAlertOnce: false,
        category: AndroidNotificationCategory.status,
        subText: card.subText,
        styleInformation: BigTextStyleInformation(card.body),
      ),
    ),
    payload: liveOrderRoute(role: card.role, orderId: card.orderId, status: card.status),
  );
}

/// A live push (foreground or background): draws its card. True if it was one.
Future<bool> showLiveOrderCardFromPush(Map<String, dynamic> data) async {
  // iPhone: the alert itself is the card (collapsed per order) — not handled here.
  if (!_supported) return false;
  final card = LiveOrderCard.fromPush(data);
  if (card == null) return false;
  await showLiveOrderCard(card);
  return true;
}

/// Removes [orderId]'s card if it is still the pinned in-progress one this
/// app drew ([pinnedTitle]) — never a final "Delivered" / "Cancelled" one.
Future<void> _clearIfStillPinned(String orderId, String pinnedTitle) async {
  if (await _showingTitle(orderId) == pinnedTitle) await _plugin.cancel(liveOrderNotificationId(orderId), tag: _tag(orderId));
}

/// While the app runs: keeps a card for every order of the signed-in
/// customer, or delivery of the signed-in driver, in progress; drops it
/// when the order leaves the in-progress list (the server's final push then
/// says how it ended). Vendors and Managers get no card.
void listenForLiveOrderCards(WidgetRef ref) {
  if (!_supported) return;
  ref.listen<AsyncValue<List<Order>>>(activeOrdersProvider, (previous, next) {
    final scope = ref.read(accessScopeProvider);
    final orders = next.valueOrNull;
    if (scope == null || orders == null) return;
    final role = switch (scope.role) {
      AppRole.user => 'user',
      AppRole.driver => 'driver',
      _ => null,
    };
    if (role == null) return;
    final cards = <String, LiveOrderCard>{
      for (final o in orders)
        if (role == 'user' ? o.userId == scope.accountId : o.driverId == scope.accountId)
          o.id: ?LiveOrderCard.forOrder(o, role),
    };
    for (final card in cards.values) {
      _pinned[card.orderId] = card.title;
      showLiveOrderCard(card);
    }
    for (final id in _pinned.keys.toList()) {
      if (cards.containsKey(id)) continue;
      final title = _pinned.remove(id)!;
      _clearIfStillPinned(id, title);
    }
  });
}

/// Cards this app instance drew, by order id → title.
final _pinned = <String, String>{};
