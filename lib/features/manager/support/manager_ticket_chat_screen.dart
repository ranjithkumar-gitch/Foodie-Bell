import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/account.dart';
import '../../../data/providers/firestore_tickets_provider.dart';
import '../../../shared/ticket_chat_screen.dart';
import '../manager_session.dart';

/// Resolves the signed-in Manager as the chat's sender. The thread title
/// depends on which direction this ticket runs: one this Manager raised
/// themselves (escalated to Admin) shows "Admin" as the other party;
/// one raised *to* them by a User/Vendor/Driver shows that raiser's name.
class ManagerTicketChatScreen extends ConsumerWidget {
  const ManagerTicketChatScreen({super.key, required this.ticketId});

  final String ticketId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final manager = ref.watch(currentManagerAccountProvider);
    final ticket = ref.watch(ticketByIdProvider(ticketId)).valueOrNull;
    if (ticket == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final otherPartyName = ticket.raisedByRole == AppRole.manager ? 'Admin' : ticket.raisedByName;
    return TicketChatScreen(
      ticketId: ticketId,
      currentUserId: manager.id,
      currentUserName: manager.name,
      otherPartyName: otherPartyName,
    );
  }
}
