import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/order.dart';
import '../../../data/models/refund_case.dart';
import '../../../data/providers/refunds_provider.dart';
import '../../../l10n/app_localizations_context.dart';
import '../../../shared/error_reporting.dart';
import '../../../shared/widgets/currency_text.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/refund_cards.dart';

/// [userId]'s cancelled or rejected orders whose payment the server has
/// marked as owed back ([OrderPaymentStatus.refundDue]) or returned
/// ([OrderPaymentStatus.refunded]), newest first.
List<Order> refundOrders(List<Order> history, String? userId) => [
  for (final o in history)
    if (o.userId == userId &&
        (o.paymentStatus == OrderPaymentStatus.refundDue || o.paymentStatus == OrderPaymentStatus.refunded))
      o,
]..sort((a, b) => b.placedAt.compareTo(a.placedAt));

/// Refunds (replaces the old Wallet & Refunds mock): there is no Quicky
/// wallet and no balance. A UPI payment for an order that was cancelled or
/// rejected is owed back by the shop to the customer's own UPI account;
/// this lists those refunds (`refunds/*`, Phase I.7) and where each one is —
/// owed, recorded by the shop and awaiting the customer's confirmation,
/// disputed, under review, or confirmed. Nothing more.
class RefundsScreen extends ConsumerWidget {
  const RefundsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.colors;
    final async = ref.watch(myRefundsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.refundsTitle)),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(friendlyError(e, action: 'Loading refunds')),
            TextButton(onPressed: () => ref.invalidate(myRefundsProvider), child: Text(context.l10n.refundRetry)),
          ]),
        ),
        data: (refunds) {
          if (refunds.isEmpty) {
            return EmptyState(
              icon: Icons.currency_rupee_rounded,
              title: context.l10n.refundsEmptyTitle,
              subtitle: context.l10n.refundsExplainer,
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            itemCount: refunds.length + 1,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, i) {
              if (i == 0) {
                return Text(context.l10n.refundsExplainer, style: TextStyle(color: palette.textSecondary, height: 1.35));
              }
              return _RefundTile(refund: refunds[i - 1]);
            },
          );
        },
      ),
    );
  }
}

class _RefundTile extends StatelessWidget {
  const _RefundTile({required this.refund});
  final RefundCase refund;

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    final done = refund.status.isDone;
    final amount = done ? refund.refundedPaise : (refund.outstandingPaise ?? refund.owedPaise);
    return InkWell(
      key: Key('refundTile_${refund.orderId}'),
      borderRadius: BorderRadius.circular(16),
      onTap: () => context.push('/user/order/${refund.orderId}'),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: palette.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: palette.border)),
        child: Row(
          children: [
            Icon(done ? Icons.check_circle_rounded : Icons.hourglass_top_rounded, color: refundStatusColor(palette, refund.status)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(refund.orderId, style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text('${refund.vendorName ?? ''} · ${customerRefundStatusLabel(context, refund.status)}', style: TextStyle(color: palette.textSecondary, fontSize: 12)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (amount != null) CurrencyText(amount / 100, style: const TextStyle(fontWeight: FontWeight.w800)),
          ],
        ),
      ),
    );
  }
}
