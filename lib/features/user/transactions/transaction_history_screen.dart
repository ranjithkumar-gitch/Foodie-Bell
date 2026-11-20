import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/session/session_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/order.dart';
import '../../../data/providers/firestore_orders_provider.dart';
import '../../../l10n/app_localizations_context.dart';
import '../../../shared/error_reporting.dart';
import '../../../shared/widgets/currency_text.dart';
import '../../../shared/widgets/empty_state.dart';

/// [userId]'s orders whose money has actually changed hands ([Order.isPaid],
/// from the server's payment record), most recent payment first: UPI the
/// shop confirmed (photo orders included), cash the Driver recorded, and
/// payments now owed back or refunded. A UPI reference the customer only
/// typed, a disputed payment and uncollected COD are left out.
List<Order> paidTransactions(List<Order> active, List<Order> history, String? userId) =>
    withLiveOrders(active, history).where((o) => o.userId == userId && o.isPaid).toList()
      ..sort((a, b) => b.paymentCompletedAt.compareTo(a.paymentCompletedAt));

/// Transaction History: every payment this User has made, most recent
/// first. There's no separate `transactions` collection — a payment is
/// recorded on the order it paid for (`payment` on the order, written only
/// by the server), so this list is just that User's paid orders
/// ([paidTransactions]) and can never drift out of sync with them.
class TransactionHistoryScreen extends ConsumerWidget {
  const TransactionHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userId = ref.watch(
      sessionControllerProvider.select((s) => s.account?.id),
    );
    // Same pages as My Orders (newest first), with in-progress orders live.
    final page = ref.watch(orderHistoryProvider(OrderHistoryFilter.all));
    final active = ref.watch(activeOrdersProvider).valueOrNull ?? const <Order>[];

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.profileTransactionHistory)),
      body: Builder(
        builder: (context) {
          final paid = paidTransactions(active, page.orders, userId);
          if (paid.isEmpty && page.loading) return const Center(child: CircularProgressIndicator());
          if (paid.isEmpty && page.error != null) {
            return Center(child: Text(friendlyError(page.error!, action: 'Loading transactions')));
          }
          if (paid.isEmpty && !page.hasMore) {
            return EmptyState(
              icon: Icons.receipt_long_rounded,
              title: context.l10n.transactionsEmptyTitle,
              subtitle: context.l10n.transactionsEmptySubtitle,
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            itemCount: paid.length + (page.hasMore ? 1 : 0),
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, i) {
              if (i < paid.length) return _TransactionTile(order: paid[i]);
              // Reaching the end loads the next page.
              Future.microtask(() => ref.read(orderHistoryProvider(OrderHistoryFilter.all).notifier).loadMore());
              return const Padding(padding: EdgeInsets.all(12), child: Center(child: CircularProgressIndicator()));
            },
          );
        },
      ),
    );
  }
}

class _TransactionTile extends StatelessWidget {
  const _TransactionTile({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    final paidAt = DateFormat('dd/MM/yyyy, h:mm a').format(order.paymentCompletedAt);
    final tone = order.paymentStatus.tone == PaymentTone.refundOwed ? palette.warning : palette.success;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => context.push('/user/order/${order.id}'),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: palette.border),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: tone.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                order.isPaidOnline
                    ? Icons.qr_code_2_rounded
                    : Icons.payments_outlined,
                color: tone,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.l10n.walletTxnOrderPayment(order.id),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${order.vendorName} · ${context.l10n.transactionPaidVia(order.paymentMethod.label)}',
                    style: TextStyle(
                      color: palette.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    // Every row says which it is: received, refund owed or
                    // refund completed.
                    [
                      order.paymentLabel,
                      paidAt,
                      ?order.paymentReference,
                    ].join(' · '),
                    style: TextStyle(color: palette.textMuted, fontSize: 11.5),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            CurrencyText(
              order.total,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }
}
