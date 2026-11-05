import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/account.dart';
import '../../data/models/chat_message.dart';
import '../../data/models/order.dart';
import '../../data/providers/firestore_chat_provider.dart';
import '../../data/providers/firestore_orders_provider.dart';
import '../session/session_controller.dart';
import 'fcm_topics.dart';
import 'local_notifications.dart';

/// Order chat (`order_chat_screen.dart`) as notifications. No Cloud Function
/// sends a push for a chat message, so the app itself watches the chats of
/// the signed-in User's or Driver's deliveries in progress and posts a
/// phone notification when the other side writes ([listenForChatNotifications]),
/// and the Notifications screens list those messages ([incomingChatProvider]).
/// Works while the app is running (the Driver's location service keeps it
/// running during a delivery); a phone that has closed the app gets nothing
/// until it is opened again.

/// The order whose chat screen is open right now — no notification is
/// posted for a message already on screen. Set by `OrderChatScreen`.
String? openChatOrderId;

/// The orders whose chat this account takes part in: a User's or Driver's
/// own orders with a Driver on them and still in progress — the same ones
/// `firestore.rules` lets them read the chat of.
final chatOrdersProvider = Provider<List<Order>>((ref) {
  final session = ref.watch(sessionControllerProvider);
  final me = ref.watch(currentAccountIdProvider);
  if (me == null) return const [];
  final orders = ref.watch(activeOrdersProvider).valueOrNull ?? const <Order>[];
  bool mine(Order o) => switch (session.role) {
    AppRole.user => o.userId == me,
    AppRole.driver => o.driverId == me,
    _ => false,
  };
  return [
    for (final o in orders)
      if (o.driverId != null && !o.status.isTerminal && mine(o)) o,
  ];
});

/// The other side's messages in each chat of [chatOrdersProvider], by order
/// id. A chat still loading has no entry, so [listenForChatNotifications]
/// can tell its first load (old messages) from a message that just arrived.
final incomingChatProvider = Provider<Map<String, List<ChatMessage>>>((ref) {
  final me = ref.watch(currentAccountIdProvider);
  if (me == null) return const {};
  final result = <String, List<ChatMessage>>{};
  for (final order in ref.watch(chatOrdersProvider)) {
    final messages = ref.watch(orderChatProvider(order.id)).valueOrNull;
    if (messages == null) continue;
    result[order.id] = [for (final m in messages) if (m.senderId != me) m];
  }
  return result;
});

/// Wired once at the app root, alongside the push listeners. Posts a phone
/// notification for each new message from the other side — never for the
/// messages already there when a chat first loads, nor for the chat open
/// on screen.
void listenForChatNotifications(WidgetRef ref) {
  ref.listen<Map<String, List<ChatMessage>>>(incomingChatProvider, (previous, next) {
    for (final entry in next.entries) {
      final before = previous?[entry.key];
      if (before == null || entry.key == openChatOrderId) continue;
      final known = {for (final m in before) m.id};
      for (final m in entry.value) {
        if (known.contains(m.id)) continue;
        showLocalNotification(title: 'Message from ${m.senderName}', body: m.text);
      }
    }
  });
}
