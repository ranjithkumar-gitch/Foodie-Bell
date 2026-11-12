import 'package:cloud_firestore/cloud_firestore.dart' show FirebaseFirestore;
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:order_live_card/order_live_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/models/account.dart';
import '../../data/models/order.dart';
import '../../data/providers/firestore_orders_provider.dart';
import '../../features/user/user_locale.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../shared/widgets/currency_text.dart';
import '../session/access_scope.dart';

/// Live order card (2026-11-12, Swiggy/Zomato style) for customers and
/// drivers: ONE card per order in the Android notification bar, drawn with a
/// native layout that copies the home page's order card (packages/
/// order_live_card): stage icon, title and subtitle, the step progress bar,
/// the shop with items and total, and the delivery code once the order is on
/// its way. Pinned while the order is in progress, updated in place at every
/// step, left as an ordinary notification when it ends.
///
/// Fed from two places that draw the same card (same id, tag and content):
/// - the server's live pushes (`QuickyAdmin/functions/lib/live_order_push.js`),
///   data-only on Android, handled even when the app is closed
///   ([showLiveOrderCardFromPush], from the background handler);
/// - the app's live order stream while it runs ([listenForLiveOrderCards]),
///   which also covers a driver's own steps (they get no push for those).
///
/// iPhone gets the server's alerts with a collapse id instead (each step
/// replaces the last); no card is drawn here on iOS.
bool get _supported => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

/// The brand green (`AppColors.primary`).
const _brandColor = 0xFF1B8A3D;

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

/// What the card is built from — the same facts from an [Order] or a push,
/// so both draw exactly the same card.
class LiveOrderFacts {
  const LiveOrderFacts({
    required this.orderId,
    required this.role,
    required this.status,
    this.shop = '',
    this.driverName = '',
    this.customerName = '',
    this.address = '',
    this.items = 0,
    this.totalPaise = 0,
    this.cod = false,
    this.otp,
    this.serverTitle = '',
    this.serverBody = '',
  });

  final String orderId;
  final String role;
  final String status;
  final String shop;
  final String driverName;
  final String customerName;
  final String address;
  final int items;
  final int totalPaise;
  final bool cod;
  final String? otp;

  /// The push's own wording, used for the final (delivered / cancelled) card.
  final String serverTitle;
  final String serverBody;

  static LiveOrderFacts fromOrder(Order o, String role, {String? otp}) => LiveOrderFacts(
    orderId: o.id,
    role: role,
    status: o.status.name,
    shop: o.vendorName,
    driverName: o.driverName ?? '',
    customerName: o.userName,
    address: o.deliveryAddressFull ?? o.deliveryAddressLabel,
    items: o.items.fold<int>(0, (s, i) => s + i.quantity),
    totalPaise: o.money?.customerTotal ?? (o.total * 100).round(),
    cod: o.paymentMethod == PaymentMethod.cod,
    otp: otp,
  );

  /// From a live push's data; null if it isn't one.
  static LiveOrderFacts? fromPush(Map<String, dynamic> d) {
    if (d['live'] != '1' || d['orderId'] is! String) return null;
    String s(String k) => d[k] is String ? d[k] as String : '';
    final otp = s('otp');
    return LiveOrderFacts(
      orderId: d['orderId'] as String,
      role: s('role').isEmpty ? 'user' : s('role'),
      status: s('type'),
      shop: s('shop'),
      driverName: s('driverName'),
      customerName: s('customer'),
      items: int.tryParse(s('items')) ?? 0,
      totalPaise: int.tryParse(s('total')) ?? 0,
      cod: s('payment') == 'cod',
      otp: otp.isEmpty ? null : otp,
      serverTitle: s('title'),
      serverBody: s('body'),
    );
  }
}

/// One drawn card.
class LiveOrderCard {
  const LiveOrderCard({
    required this.orderId,
    required this.role,
    required this.status,
    required this.title,
    required this.subtitle,
    required this.emoji,
    required this.step,
    required this.steps,
    required this.footerTitle,
    required this.footerText,
    this.otp,
  });

  final String orderId;
  final String role;
  final String status;
  final String title;
  final String subtitle;
  final String emoji;

  /// 1-based current step; past [steps] means all done.
  final int step;
  final int steps;
  final String footerTitle;
  final String footerText;
  final String? otp;

  static const otpLabel = 'Share this code with your delivery partner';

  bool get terminal => const {'delivered', 'cancelled', 'rejected'}.contains(status);

  /// Alerting is per stage (a new step, or the code arriving); anything
  /// else changing updates the card silently.
  String get stage => '$status${otp == null ? '' : ':otp'}';
  String get hash => [status, title, subtitle, emoji, step, steps, footerTitle, footerText, otp ?? ''].join('|');

  /// The card for [f], in [l10n]'s language for customers (the home card's
  /// own strings); null when there's nothing to show.
  static LiveOrderCard? build(LiveOrderFacts f, AppLocalizations l10n) {
    final shop = f.shop.isEmpty ? 'the shop' : f.shop;
    final total = AppFormat.currency(f.totalPaise / 100);
    final summary = f.items > 0 ? l10n.homeTrackItemsSummary(f.items, total) : total;
    LiveOrderCard card(String title, String subtitle, String emoji, int step, int steps, {String? footerTitle, String? footerText, String? otp}) =>
        LiveOrderCard(
          orderId: f.orderId,
          role: f.role,
          status: f.status,
          title: title,
          subtitle: subtitle,
          emoji: emoji,
          step: step,
          steps: steps,
          footerTitle: footerTitle ?? shop,
          footerText: footerText ?? summary,
          otp: otp,
        );
    final ended = f.status == 'delivered';
    final stopped = f.status == 'cancelled' || f.status == 'rejected';

    if (f.role == 'driver') {
      final pay = f.cod ? 'Collect $total cash' : 'Paid online';
      final customer = f.customerName.isEmpty ? 'the customer' : f.customerName;
      return switch (f.status) {
        'driverAssigned' => card('Pick up from $shop', 'Head to the shop and collect the order.', '🏪', 1, 2, footerText: '$summary · $pay'),
        'pickedUp' => card('Deliver to $customer', f.address.isEmpty ? 'Take the order to the customer.' : f.address, '🛵', 2, 2,
            footerTitle: customer, footerText: '$summary · $pay'),
        _ when ended => card(f.serverTitle.isEmpty ? 'Delivery completed' : f.serverTitle, f.serverBody, '✅', 3, 2),
        _ when stopped => card(f.serverTitle.isEmpty ? 'Delivery cancelled' : f.serverTitle, f.serverBody, '❌', 0, 0),
        _ => null,
      };
    }
    final driver = f.driverName.isEmpty ? l10n.homeTrackDefaultDriver : f.driverName;
    return switch (f.status) {
      'placed' => card(l10n.homeTrackPlacedTitle, l10n.homeTrackPlacedSubtitle(shop), '🧾', 1, 4),
      'vendorAccepted' => card(l10n.homeTrackAcceptedTitle, l10n.homeTrackAcceptedSubtitle(shop), '🍳', 2, 4),
      'driverAssigned' => card(l10n.homeTrackDriverAssignedTitle, l10n.homeTrackDriverAssignedSubtitle(driver), '🏍️', 3, 4),
      'pickedUp' => card(l10n.homeTrackPickedUpTitle, l10n.homeTrackPickedUpSubtitle(driver), '🛵', 4, 4, otp: f.otp),
      _ when ended => card(f.serverTitle.isEmpty ? 'Order delivered' : f.serverTitle, f.serverBody, '✅', 5, 4),
      _ when stopped => card(f.serverTitle.isEmpty ? 'Order cancelled' : f.serverTitle, f.serverBody, '❌', 0, 0),
      _ => null,
    };
  }
}

/// The customer's app language, saved so the background isolate draws the
/// card in it too.
const _langKey = 'live_order_card_language';

Future<AppLocalizations> _savedL10n() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    return lookupAppLocalizations(Locale(prefs.getString(_langKey) == 'te' ? 'te' : 'en'));
  } catch (_) {
    return lookupAppLocalizations(const Locale('en'));
  }
}

/// Sets up taps (no-op off Android).
Future<void> initLiveOrderCards({void Function(String route)? onTap}) async {
  if (!_supported || onTap == null) return;
  OrderLiveCardNative.onTap((route) {
    if (route.startsWith('/')) onTap(route);
  });
}

/// The route of the card that launched the app, if one did.
Future<String?> liveOrderLaunchRoute() async {
  if (!_supported) return null;
  try {
    return await OrderLiveCardNative.takeLaunchRoute();
  } catch (_) {
    return null;
  }
}

/// Draws or updates [card]. An unchanged card is left alone; a new stage
/// alerts once; other changes update it silently.
Future<void> showLiveOrderCard(LiveOrderCard card) async {
  if (!_supported) return;
  final id = liveOrderNotificationId(card.orderId);
  final showing = await OrderLiveCardNative.active(id, _tag(card.orderId));
  if (showing?.hash == card.hash) return;
  await OrderLiveCardNative.show(
    id: id,
    tag: _tag(card.orderId),
    stage: card.stage,
    hash: card.hash,
    title: card.title,
    subtitle: card.subtitle,
    emoji: card.emoji,
    step: card.step,
    steps: card.steps,
    footerTitle: card.footerTitle,
    footerText: card.footerText,
    otp: card.otp,
    otpLabel: LiveOrderCard.otpLabel,
    ongoing: !card.terminal,
    alert: showing?.stage != card.stage,
    route: liveOrderRoute(role: card.role, orderId: card.orderId, status: card.status),
    color: _brandColor,
  );
}

/// A live push (foreground or background): draws its card. True if it was
/// one (Android only — on iPhone the alert itself is the card).
Future<bool> showLiveOrderCardFromPush(Map<String, dynamic> data) async {
  if (!_supported) return false;
  final facts = LiveOrderFacts.fromPush(data);
  if (facts == null) return false;
  final card = LiveOrderCard.build(facts, await _savedL10n());
  if (card != null) await showLiveOrderCard(card);
  return true;
}

/// Delivery codes already fetched, by order id.
final _otps = <String, String>{};

/// Cards this app instance drew, by order id → hash.
final _pinned = <String, String>{};

/// While the app runs: keeps a card for every order of the signed-in
/// customer, or delivery of the signed-in driver, in progress; drops it when
/// the order leaves the in-progress list (the server's final push then says
/// how it ended). Vendors and Managers get no card.
void listenForLiveOrderCards(WidgetRef ref) {
  if (!_supported) return;

  void sync() {
    final scope = ref.read(accessScopeProvider);
    final orders = ref.read(activeOrdersProvider).valueOrNull;
    if (scope == null || orders == null) return;
    final role = switch (scope.role) {
      AppRole.user => 'user',
      AppRole.driver => 'driver',
      _ => null,
    };
    if (role == null) return;
    final locale = ref.read(userLocaleProvider);
    SharedPreferences.getInstance().then((p) => p.setString(_langKey, locale.languageCode)).catchError((_) => false);
    final l10n = lookupAppLocalizations(locale);
    final cards = <String, LiveOrderCard>{};
    for (final o in orders) {
      if (role == 'user' ? o.userId != scope.accountId : o.driverId != scope.accountId) continue;
      if (role == 'user' && o.status == OrderStatus.pickedUp && !_otps.containsKey(o.id)) {
        // The delivery code, once, for the card's code strip.
        FirebaseFirestore.instance.doc('orders/${o.id}/codes/delivery').get().then((d) {
          final code = d.data()?['code'];
          if (code is String && code.isNotEmpty) {
            _otps[o.id] = code;
            sync();
          }
        }).catchError((_) {});
      }
      final card = LiveOrderCard.build(LiveOrderFacts.fromOrder(o, role, otp: _otps[o.id]), l10n);
      if (card != null && !card.terminal) cards[o.id] = card;
    }
    for (final card in cards.values) {
      _pinned[card.orderId] = card.hash;
      showLiveOrderCard(card);
    }
    for (final id in _pinned.keys.toList()) {
      if (cards.containsKey(id)) continue;
      final hash = _pinned.remove(id)!;
      _otps.remove(id);
      OrderLiveCardNative.active(liveOrderNotificationId(id), _tag(id)).then((showing) {
        if (showing?.hash == hash) OrderLiveCardNative.cancel(liveOrderNotificationId(id), _tag(id));
      }).catchError((_) {});
    }
  }

  ref.listen<AsyncValue<List<Order>>>(activeOrdersProvider, (_, _) => sync());
}
