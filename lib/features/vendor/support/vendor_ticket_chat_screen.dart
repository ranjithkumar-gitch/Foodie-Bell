import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/session/session_controller.dart';
import '../../../data/providers/firestore_managers_provider.dart';
import '../../../data/providers/firestore_tickets_provider.dart';
import '../../../shared/ticket_chat_screen.dart';

/// Resolves the signed-in Vendor as the chat's sender and the ticket's
/// assigned Territory Manager as the thread title, then hands off to the
/// shared [TicketChatScreen].
class VendorTicketChatScreen extends ConsumerWidget {
  const VendorTicketChatScreen({super.key, required this.ticketId});

  final String ticketId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final account = ref.watch(sessionControllerProvider.select((s) => s.account));
    final ticket = ref.watch(ticketByIdProvider(ticketId)).valueOrNull;
    if (ticket == null || account == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final managers = ref.watch(firestoreManagersProvider).valueOrNull ?? const [];
    final managerName = managers.where((m) => m.id == ticket.recipientId).firstOrNull?.name ?? 'Manager';
    return TicketChatScreen(
      ticketId: ticketId,
      currentUserId: account.id,
      currentUserName: account.name,
      otherPartyName: managerName,
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
