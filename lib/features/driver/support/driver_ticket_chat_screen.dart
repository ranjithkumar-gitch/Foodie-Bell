import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/providers/firestore_managers_provider.dart';
import '../../../data/providers/firestore_tickets_provider.dart';
import '../../../shared/ticket_chat_screen.dart';
import '../driver_session.dart';

/// Resolves the signed-in Driver as the chat's sender and the ticket's
/// assigned Territory Manager as the thread title, then hands off to the
/// shared [TicketChatScreen].
class DriverTicketChatScreen extends ConsumerWidget {
  const DriverTicketChatScreen({super.key, required this.ticketId});

  final String ticketId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final driver = ref.watch(currentDriverAccountProvider);
    final ticket = ref.watch(ticketByIdProvider(ticketId)).valueOrNull;
    if (ticket == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final managers = ref.watch(firestoreManagersProvider).valueOrNull ?? const [];
    final managerName = managers.where((m) => m.id == ticket.recipientId).firstOrNull?.name ?? 'Manager';
    return TicketChatScreen(
      ticketId: ticketId,
      currentUserId: driver.id,
      currentUserName: driver.name,
      otherPartyName: managerName,
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
