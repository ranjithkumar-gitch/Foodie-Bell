/// A single message in an order's one-to-one Driver ↔ User chat
/// (`firestore_chat_provider.dart`). Scoped to exactly one order — there's
/// no persistent, cross-order conversation between a given driver and user.
class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.orderId,
    required this.senderId,
    required this.senderName,
    required this.text,
    required this.sentAt,
  });

  final String id;
  final String orderId;
  final String senderId;
  final String senderName;
  final String text;
  final DateTime sentAt;
}
