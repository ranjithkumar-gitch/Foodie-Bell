import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_colors.dart';
import '../data/models/ticket.dart';
import '../data/providers/firestore_ticket_chat_provider.dart';
import '../data/providers/firestore_tickets_provider.dart';
import 'error_reporting.dart';
import 'widgets/status_chip.dart';

/// One-to-one chat on a support ticket, shared by every role's ticket-chat
/// wrapper screen — same shape/UI as `order_chat_screen.dart`'s
/// `OrderChatScreen`. Closes for new messages once the ticket reaches
/// [TicketStatus.closed]; either participant can close it from here (the
/// widget itself is role-agnostic — it doesn't know or care which side is
/// "the handler").
class TicketChatScreen extends ConsumerStatefulWidget {
  const TicketChatScreen({
    super.key,
    required this.ticketId,
    required this.currentUserId,
    required this.currentUserName,
    required this.otherPartyName,
  });

  final String ticketId;
  final String currentUserId;
  final String currentUserName;
  final String otherPartyName;

  @override
  ConsumerState<TicketChatScreen> createState() => _TicketChatScreenState();
}

class _TicketChatScreenState extends ConsumerState<TicketChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  bool _sending = false;

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  String _formatTime(DateTime dt) {
    final hour12 = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour < 12 ? 'AM' : 'PM';
    return '$hour12:$minute $period';
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    _controller.clear();
    try {
      await sendTicketMessage(
        widget.ticketId,
        widget.currentUserId,
        widget.currentUserName,
        text,
      );
    } catch (e, st) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            friendlyError(e, action: 'Sending message', stackTrace: st),
          ),
        ),
      );
    }
    if (!mounted) return;
    setState(() => _sending = false);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _closeTicket() async {
    try {
      await updateTicketStatus(widget.ticketId, TicketStatus.closed);
    } catch (e, st) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            friendlyError(e, action: 'Closing ticket', stackTrace: st),
          ),
        ),
      );
    }
  }

  StatusTone _tone(TicketStatus status) => switch (status) {
    TicketStatus.open => StatusTone.warning,
    TicketStatus.inProgress => StatusTone.info,
    TicketStatus.closed => StatusTone.neutral,
  };

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    final messagesAsync = ref.watch(ticketChatProvider(widget.ticketId));
    final ticket = ref.watch(ticketByIdProvider(widget.ticketId)).valueOrNull;
    final closed = ticket != null && ticket.status == TicketStatus.closed;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.otherPartyName),
        actions: [
          if (ticket != null) ...[
            StatusChip(label: ticket.status.label, tone: _tone(ticket.status)),
            const SizedBox(width: 8),
            if (!closed)
              IconButton(
                tooltip: 'Close ticket',
                onPressed: _closeTicket,
                icon: const Icon(Icons.check_circle_outline_rounded),
              ),
          ],
        ],
      ),
      body: Column(
        children: [
          if (ticket != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              color: palette.surfaceMuted,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      ticket.subject,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 12.5,
                        color: palette.textSecondary,
                      ),
                    ),
                  ),
                  // Shown right in the header, not just in the raiser's own
                  // ticket list — this is the handler's (Manager/Admin)
                  // first look at the thread, and knowing which order it's
                  // about up front is the whole point of attaching one.
                  if (ticket.orderId != null) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: palette.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Order #${ticket.orderId}',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 11,
                          color: palette.primary,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          Expanded(
            child: messagesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, st) => Center(
                child: Text(
                  friendlyError(e, action: 'Loading chat', stackTrace: st),
                ),
              ),
              data: (messages) {
                if (messages.isEmpty) {
                  return Center(
                    child: Text(
                      'Say hello to ${widget.otherPartyName} about this ticket.',
                      style: TextStyle(color: palette.textMuted),
                    ),
                  );
                }
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (_scrollController.hasClients) {
                    _scrollController.jumpTo(
                      _scrollController.position.maxScrollExtent,
                    );
                  }
                });
                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  itemCount: messages.length,
                  itemBuilder: (context, i) {
                    final message = messages[i];
                    final isMine = message.senderId == widget.currentUserId;
                    return Align(
                      alignment: isMine
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.72,
                        ),
                        decoration: BoxDecoration(
                          color: isMine
                              ? palette.primary
                              : palette.surfaceMuted,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              message.text,
                              style: TextStyle(
                                color: isMine
                                    ? Colors.white
                                    : palette.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              _formatTime(message.sentAt),
                              style: TextStyle(
                                fontSize: 10.5,
                                color: isMine
                                    ? Colors.white.withValues(alpha: 0.75)
                                    : palette.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: closed
                ? Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'This ticket is closed — you can no longer send messages.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: palette.textMuted,
                        fontSize: 12.5,
                      ),
                    ),
                  )
                : Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _controller,
                            textInputAction: TextInputAction.send,
                            onSubmitted: (_) => _send(),
                            decoration: const InputDecoration(
                              hintText: 'Type a message…',
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton.filled(
                          onPressed: _sending ? null : _send,
                          icon: _sending
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2.2,
                                  ),
                                )
                              : const Icon(Icons.send_rounded),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
