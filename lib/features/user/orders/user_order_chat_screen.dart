import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/session/session_controller.dart';
import '../../../data/providers/firestore_orders_provider.dart';
import '../../../l10n/app_localizations_context.dart';
import '../../../shared/order_chat_screen.dart';

/// Resolves the signed-in User as the chat's sender and the order's driver
/// as the thread title, then hands off to the shared [OrderChatScreen] both
/// roles use.
class UserOrderChatScreen extends ConsumerWidget {
  const UserOrderChatScreen({super.key, required this.orderId});

  final String orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final account = ref.watch(sessionControllerProvider.select((s) => s.account));
    final order = ref.watch(orderByIdProvider(orderId)).valueOrNull;
    if (order == null || account == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return OrderChatScreen(orderId: orderId, currentUserId: account.id, currentUserName: account.name, otherPartyName: order.driverName ?? context.l10n.chatDriverFallback);
  }
}
