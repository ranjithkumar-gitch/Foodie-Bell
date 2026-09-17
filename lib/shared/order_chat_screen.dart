import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_colors.dart';
import '../data/models/order.dart';
import '../data/providers/firestore_chat_provider.dart';
import '../data/providers/firestore_orders_provider.dart';
import 'error_reporting.dart';

/// One-to-one chat about a single order, shared between the Driver's
/// Navigate to Customer screen and the User's Order Tracking screen — each
/// role's own id/name is the sender, the other role's name is shown as the
/// thread title. Closes for new messages once the order reaches a terminal
/// status (delivered/cancelled/rejected); the entry points on both sides
/// already stop offering it past that point, this is just the same rule
/// enforced here too in case someone's still on the screen when it flips.
class OrderChatScreen extends ConsumerStatefulWidget {
  const OrderChatScreen({
    super.key,
    required this.orderId,
    required this.currentUserId,
    required this.currentUserName,
    required this.otherPartyName,
  });

  final String orderId;
  final String currentUserId;
  final String currentUserName;
  final String otherPartyName;

  @override
  ConsumerState<OrderChatScreen> createState() => _OrderChatScreenState();
}

class _OrderChatScreenState extends ConsumerState<OrderChatScreen> {
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
      await sendChatMessage(widget.orderId, widget.currentUserId, widget.currentUserName, text);
    } catch (e, st) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e, action: 'Sending message', stackTrace: st))));
    }
    if (!mounted) return;
    setState(() => _sending = false);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) _scrollController.animateTo(_scrollController.position.maxScrollExtent, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    final messagesAsync = ref.watch(orderChatProvider(widget.orderId));
    final order = ref.watch(orderByIdProvider(widget.orderId)).valueOrNull;
    final closed = order != null && order.status.isTerminal;

    return Scaffold(
      appBar: AppBar(title: Text(widget.otherPartyName)),
      body: Column(
        children: [
          Expanded(
            child: messagesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, st) => Center(child: Text(friendlyError(e, action: 'Loading chat', stackTrace: st))),
              data: (messages) {
                if (messages.isEmpty) {
                  return Center(
                    child: Text('Say hello to ${widget.otherPartyName} about this order.', style: TextStyle(color: palette.textMuted)),
                  );
                }
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (_scrollController.hasClients) _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
                });
                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  itemCount: messages.length,
                  itemBuilder: (context, i) {
                    final message = messages[i];
                    final isMine = message.senderId == widget.currentUserId;
                    return Align(
                      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
                        decoration: BoxDecoration(
                          color: isMine ? palette.primary : palette.surfaceMuted,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(message.text, style: TextStyle(color: isMine ? Colors.white : palette.textPrimary)),
                            const SizedBox(height: 3),
                            Text(
                              _formatTime(message.sentAt),
                              style: TextStyle(fontSize: 10.5, color: isMine ? Colors.white.withValues(alpha: 0.75) : palette.textMuted),
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
                    child: Text('This order is closed — you can no longer send messages.', textAlign: TextAlign.center, style: TextStyle(color: palette.textMuted, fontSize: 12.5)),
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
                            decoration: const InputDecoration(hintText: 'Type a message…'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton.filled(
                          onPressed: _sending ? null : _send,
                          icon: _sending
                              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.2))
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
