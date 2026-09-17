import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/ticket.dart';

/// One-to-one chat on a support ticket thread — a flat `ticket_messages`
/// collection filtered by `ticketId`, same pattern as `chat_messages`
/// filtered by `orderId` (`firestore_chat_provider.dart`).
const ticketMessagesCollectionPath = 'ticket_messages';

CollectionReference<Map<String, dynamic>> get ticketMessagesCollection =>
    FirebaseFirestore.instance.collection(ticketMessagesCollectionPath);

TicketMessage _messageFromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
  final data = doc.data();
  return TicketMessage(
    id: doc.id,
    ticketId: data['ticketId'] as String? ?? '',
    senderId: data['senderId'] as String? ?? '',
    senderName: data['senderName'] as String? ?? '',
    text: data['text'] as String? ?? '',
    sentAt: (data['sentAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
  );
}

/// This ticket's chat thread, live, oldest first. Sorted client-side (like
/// `orderChatProvider`) rather than via a Firestore `orderBy` on a different
/// field than the `where`, so a single-field index covers it without
/// needing a composite index.
final ticketChatProvider = StreamProvider.family<List<TicketMessage>, String>((ref, ticketId) {
  return ticketMessagesCollection.where('ticketId', isEqualTo: ticketId).snapshots().map((snapshot) {
    final messages = snapshot.docs.map(_messageFromDoc).toList();
    messages.sort((a, b) => a.sentAt.compareTo(b.sentAt));
    return messages;
  });
});

Future<void> sendTicketMessage(String ticketId, String senderId, String senderName, String text) =>
    ticketMessagesCollection.add({
      'ticketId': ticketId,
      'senderId': senderId,
      'senderName': senderName,
      'text': text,
      'sentAt': FieldValue.serverTimestamp(),
    });
