import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/account.dart';
import '../models/ticket.dart';

/// Support tickets — one flat `tickets` collection, same pattern as
/// `promotions`/`coupons`/`orders`: every role's screen filters this
/// client-side by its own field (`raisedById` for "my tickets",
/// `recipientId`/`recipientRole` for a Manager's/Admin's inbox).
const ticketsCollectionPath = 'tickets';

CollectionReference<Map<String, dynamic>> get ticketsCollection =>
    FirebaseFirestore.instance.collection(ticketsCollectionPath);

Map<String, dynamic> _ticketToDoc(SupportTicket ticket) => {
  'raisedByRole': ticket.raisedByRole.name,
  'raisedById': ticket.raisedById,
  'raisedByName': ticket.raisedByName,
  'recipientRole': ticket.recipientRole.name,
  'recipientId': ticket.recipientId,
  'subject': ticket.subject,
  'description': ticket.description,
  'orderId': ticket.orderId,
  'status': ticket.status.name,
  'createdAt': Timestamp.fromDate(ticket.createdAt),
  'closedAt': ticket.closedAt == null
      ? null
      : Timestamp.fromDate(ticket.closedAt!),
};

SupportTicket _ticketFromDoc(String id, Map<String, dynamic> data) =>
    SupportTicket(
      id: id,
      raisedByRole: AppRole.values.byName(
        data['raisedByRole'] as String? ?? 'user',
      ),
      raisedById: data['raisedById'] as String? ?? '',
      raisedByName: data['raisedByName'] as String? ?? '',
      recipientRole: AppRole.values.byName(
        data['recipientRole'] as String? ?? 'admin',
      ),
      recipientId: data['recipientId'] as String?,
      subject: data['subject'] as String? ?? '',
      description: data['description'] as String? ?? '',
      orderId: data['orderId'] as String?,
      status: TicketStatus.values.byName(data['status'] as String? ?? 'open'),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      closedAt: (data['closedAt'] as Timestamp?)?.toDate(),
    );

/// Every support ticket on the platform, live — every role's screen filters
/// this client-side by its own field, same convention as
/// `firestorePromotionsProvider`/`firestoreCouponsProvider`.
final firestoreTicketsProvider = StreamProvider<List<SupportTicket>>((ref) {
  return ticketsCollection.snapshots().map(
    (snapshot) => [
      for (final doc in snapshot.docs) _ticketFromDoc(doc.id, doc.data()),
    ],
  );
});

/// A single ticket, live — used by the ticket-chat screen and its per-role
/// wrappers so they don't depend on the unfiltered stream having synced yet
/// (same reasoning as `orderByIdProvider`).
final ticketByIdProvider = StreamProvider.family<SupportTicket?, String>((
  ref,
  ticketId,
) {
  return ticketsCollection.doc(ticketId).snapshots().map((doc) {
    final data = doc.data();
    return data == null ? null : _ticketFromDoc(doc.id, data);
  });
});

/// Raises a ticket and returns it with its Firestore-assigned id, so the
/// raising screen can navigate straight into the chat thread rather than
/// waiting for `firestoreTicketsProvider`'s stream to catch up.
Future<SupportTicket> raiseTicket({
  required AppRole raisedByRole,
  required String raisedById,
  required String raisedByName,
  required AppRole recipientRole,
  required String subject,
  required String description,
  String? recipientId,
  String? orderId,
}) async {
  final ticket = SupportTicket(
    id: '',
    raisedByRole: raisedByRole,
    raisedById: raisedById,
    raisedByName: raisedByName,
    recipientRole: recipientRole,
    recipientId: recipientId,
    subject: subject,
    description: description,
    orderId: orderId,
    createdAt: DateTime.now(),
  );
  final doc = await ticketsCollection.add(_ticketToDoc(ticket));
  return SupportTicket(
    id: doc.id,
    raisedByRole: ticket.raisedByRole,
    raisedById: ticket.raisedById,
    raisedByName: ticket.raisedByName,
    recipientRole: ticket.recipientRole,
    recipientId: ticket.recipientId,
    subject: ticket.subject,
    description: ticket.description,
    orderId: ticket.orderId,
    createdAt: ticket.createdAt,
  );
}

/// Updates a ticket's status — stamps `closedAt` the moment it's closed,
/// left untouched otherwise (never cleared once set, mirroring how
/// `Order.statusTimestamps` records are only ever added, not rewritten).
Future<void> updateTicketStatus(String ticketId, TicketStatus status) =>
    ticketsCollection.doc(ticketId).update({
      'status': status.name,
      if (status == TicketStatus.closed) 'closedAt': Timestamp.now(),
    });
