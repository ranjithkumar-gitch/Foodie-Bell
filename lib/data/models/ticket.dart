import 'account.dart';

enum TicketStatus { open, inProgress, closed }

extension TicketStatusX on TicketStatus {
  String get label => switch (this) {
    TicketStatus.open => 'Open',
    TicketStatus.inProgress => 'In Progress',
    TicketStatus.closed => 'Closed',
  };
}

/// A support ticket raised by one role to another — User/Vendor/Driver raise
/// to their Territory Manager (see [recipientId]'s resolution in each
/// raise-a-ticket screen: `managerCode` match for Vendor/Driver, current
/// Home territory for User), and a Manager escalates to Admin. Once raised,
/// it behaves like a live 1:1 chat (`ticket_chat_screen.dart`,
/// `firestore_ticket_chat_provider.dart`) between [raisedById] and
/// [recipientId]/Admin until [status] reaches [TicketStatus.closed].
class SupportTicket {
  const SupportTicket({
    required this.id,
    required this.raisedByRole,
    required this.raisedById,
    required this.raisedByName,
    required this.recipientRole,
    required this.subject,
    required this.description,
    required this.createdAt,
    this.recipientId,
    this.orderId,
    this.status = TicketStatus.open,
    this.closedAt,
  });

  final String id;
  final AppRole raisedByRole;
  final String raisedById;
  final String raisedByName;

  /// Who this ticket is addressed to — [AppRole.manager] (User/Vendor/Driver
  /// raising to their Territory Manager) or [AppRole.admin] (Manager
  /// escalating). Never any other role.
  final AppRole recipientRole;

  /// The specific Manager's account id when [recipientRole] is
  /// [AppRole.manager] — resolved once at raise time and frozen on the
  /// ticket, so it keeps routing to the same Manager even if the raiser's
  /// territory/managerCode later changes. Null when [recipientRole] is
  /// [AppRole.admin] — there's a single global Admin queue, same as before.
  final String? recipientId;

  final String subject;
  final String description;

  /// The order this ticket is about, if the raiser picked one — set from
  /// their own recent orders at raise time (`help_screen.dart`'s "Related
  /// order" picker), not free-typed, so it's always a real, valid order id
  /// rather than whatever the FAQ used to tell people to paste into
  /// [description] by hand. Null for a ticket that isn't about a specific
  /// order.
  final String? orderId;

  final TicketStatus status;
  final DateTime createdAt;
  final DateTime? closedAt;

  SupportTicket copyWith({TicketStatus? status, DateTime? closedAt}) =>
      SupportTicket(
        id: id,
        raisedByRole: raisedByRole,
        raisedById: raisedById,
        raisedByName: raisedByName,
        recipientRole: recipientRole,
        recipientId: recipientId,
        subject: subject,
        description: description,
        orderId: orderId,
        createdAt: createdAt,
        status: status ?? this.status,
        closedAt: closedAt ?? this.closedAt,
      );
}

/// One message on a [SupportTicket]'s chat thread — same shape as
/// `ChatMessage` (`chat_message.dart`, order chat) but scoped by [ticketId]
/// instead of an order id, via its own `ticket_messages` collection
/// (`firestore_ticket_chat_provider.dart`).
class TicketMessage {
  const TicketMessage({
    required this.id,
    required this.ticketId,
    required this.senderId,
    required this.senderName,
    required this.text,
    required this.sentAt,
  });

  final String id;
  final String ticketId;
  final String senderId;
  final String senderName;
  final String text;
  final DateTime sentAt;
}
