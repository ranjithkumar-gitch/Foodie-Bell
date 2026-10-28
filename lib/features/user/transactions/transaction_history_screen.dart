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

/// Transaction History: every payment this User has made, most recent
/// first. There's no separate `transactions` collection — a payment is
/// recorded on the order it paid for ([Order.paymentId]/[Order.paidAt] for
/// an online one, [Order.codPaymentReceived] for cash), so this list is
/// just that User's paid orders and can never drift out of sync with them.
/// A COD order only appears once the Driver has confirmed the cash — until
/// then no money has changed hands, and it may still be cancelled.
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
          final paid =
              withLiveOrders(active, page.orders).where((o) => o.userId == userId && o.isPaid).toList()
                ..sort(
                  (a, b) =>
                      b.paymentCompletedAt.compareTo(a.paymentCompletedAt),
                );
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
    final paidAt = DateFormat('d MMM y, h:mm a').format(order.paymentCompletedAt);
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
                color: palette.success.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                order.isPaidOnline
                    ? Icons.credit_card_rounded
                    : Icons.payments_outlined,
                color: palette.success,
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
                    order.isPaidOnline ? '$paidAt · ${order.paymentId}' : paidAt,
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
