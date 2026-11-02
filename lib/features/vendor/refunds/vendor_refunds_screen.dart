import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/refund_case.dart';
import '../../../data/providers/refunds_provider.dart';
import '../../../shared/error_reporting.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/refund_cards.dart';

/// Customer refunds this shop owes (Phase I.7): open ones first, then the
/// rest. Each opens the order, where the refund is recorded.
class VendorRefundsScreen extends ConsumerWidget {
  const VendorRefundsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(vendorRefundsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Customer refunds')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(friendlyError(e, action: 'Loading refunds')),
            TextButton(onPressed: () => ref.invalidate(vendorRefundsProvider), child: const Text('Retry')),
          ]),
        ),
        data: (refunds) {
          if (refunds.isEmpty) {
            return const EmptyState(icon: Icons.currency_rupee_rounded, title: 'No refunds', subtitle: 'When a customer who paid you by UPI is owed their money back, it shows here.');
          }
          final sorted = [...refunds]..sort((a, b) => (a.status.isDone ? 1 : 0).compareTo(b.status.isDone ? 1 : 0));
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: sorted.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, i) => RefundListTile(refund: sorted[i], onTap: () => context.push('/vendor/order/${sorted[i].orderId}')),
          );
        },
      ),
    );
  }
}

/// One refund in a list: the order, why, how much is left, and its status.
class RefundListTile extends StatelessWidget {
  const RefundListTile({super.key, required this.refund, this.onTap, this.trailing});
  final RefundCase refund;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    final hours = refund.ageHours();
    return InkWell(
      key: Key('refundListTile_${refund.orderId}'),
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: palette.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: palette.border)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(refund.orderId, style: const TextStyle(fontWeight: FontWeight.w700))),
            RefundStatusChip(status: refund.status),
          ]),
          const SizedBox(height: 4),
          Text(
            [
              refundCauseLabel(refund.cause),
              if (refund.vendorName != null) refund.vendorName!,
              if (hours != null && !refund.status.isDone) 'owed for ${ageLabel(hours)}',
            ].join(' · '),
            style: TextStyle(color: palette.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 4),
          Text(
            refund.owedPaise == null
                ? 'Amount being checked by Quicky'
                : refund.status.isDone
                    ? 'Refunded ${rupeesOf(refund.refundedPaise)}'
                    : 'Still owed ${rupeesOf(refund.outstandingPaise ?? 0)} of ${rupeesOf(refund.owedPaise!)}${refund.pendingPaise > 0 ? ' · ${rupeesOf(refund.pendingPaise)} awaiting confirmation' : ''}',
          ),
          if (refund.escalationLabel.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(refund.escalationLabel, key: Key('refundEscalation_${refund.orderId}'), style: TextStyle(color: refund.status.isDone ? palette.textSecondary : palette.error, fontWeight: FontWeight.w600, fontSize: 12)),
            ),
          if (refund.lastNotifiedAt != null || refund.lastFollowUpAt != null || refund.lastReviewAt != null)
            Text(
              [
                if (refund.lastNotifiedAt != null) 'Last notified ${istLabel(refund.lastNotifiedAt!)}',
                if (refund.lastFollowUpAt != null) 'Last follow-up ${istLabel(refund.lastFollowUpAt!)}',
                if (refund.lastReviewAt != null) 'Last Quicky review ${istLabel(refund.lastReviewAt!)}',
              ].join(' · '),
              style: TextStyle(color: palette.textSecondary, fontSize: 11.5),
            ),
          if (trailing != null) ...[const SizedBox(height: 6), trailing!],
        ]),
      ),
    );
  }
}
