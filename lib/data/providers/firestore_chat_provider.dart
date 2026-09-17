import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/chat_message.dart';

/// One-to-one Driver ↔ User chat, scoped to a single order — a flat
/// `chat_messages` collection filtered by `orderId`, same pattern as
/// `products`/`orders` filtering by their own foreign key.
const chatMessagesCollectionPath = 'chat_messages';

CollectionReference<Map<String, dynamic>> get chatMessagesCollection =>
    FirebaseFirestore.instance.collection(chatMessagesCollectionPath);

ChatMessage _messageFromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
  final data = doc.data();
  return ChatMessage(
    id: doc.id,
    orderId: data['orderId'] as String? ?? '',
    senderId: data['senderId'] as String? ?? '',
    senderName: data['senderName'] as String? ?? '',
    text: data['text'] as String? ?? '',
    sentAt: (data['sentAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
  );
}

/// This order's chat thread, live, oldest first. Sorted client-side (like
/// `vendorProductsProvider`) rather than via a Firestore `orderBy` on a
/// different field than the `where`, so a single-field index covers it
/// without needing a composite index.
final orderChatProvider = StreamProvider.family<List<ChatMessage>, String>((ref, orderId) {
  return chatMessagesCollection.where('orderId', isEqualTo: orderId).snapshots().map((snapshot) {
    final messages = snapshot.docs.map(_messageFromDoc).toList();
    messages.sort((a, b) => a.sentAt.compareTo(b.sentAt));
    return messages;
  });
});

Future<void> sendChatMessage(String orderId, String senderId, String senderName, String text) => chatMessagesCollection.add({
  'orderId': orderId,
  'senderId': senderId,
  'senderName': senderName,
  'text': text,
  'sentAt': FieldValue.serverTimestamp(),
});
