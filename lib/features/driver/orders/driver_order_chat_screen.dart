import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/providers/firestore_orders_provider.dart';
import '../../../shared/order_chat_screen.dart';
import '../driver_session.dart';

/// Resolves the signed-in Driver as the chat's sender and the order's
/// customer as the thread title, then hands off to the shared
/// [OrderChatScreen] both roles use.
class DriverOrderChatScreen extends ConsumerWidget {
  const DriverOrderChatScreen({super.key, required this.orderId});

  final String orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final driver = ref.watch(currentDriverAccountProvider);
    final order = ref.watch(orderByIdProvider(orderId)).valueOrNull;
    if (order == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return OrderChatScreen(orderId: orderId, currentUserId: driver.id, currentUserName: driver.name, otherPartyName: order.userName);
  }
}
