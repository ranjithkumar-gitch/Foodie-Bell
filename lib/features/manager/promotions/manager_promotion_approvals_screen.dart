import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/promotion.dart';
import '../../../data/providers/firestore_promotions_provider.dart';
import '../../../shared/error_reporting.dart';
import '../../../shared/widgets/app_network_image.dart';
import '../../../shared/widgets/currency_text.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/status_chip.dart';
import '../manager_session.dart';

final _dateFormat = DateFormat('d MMM yyyy');

/// Vendor Promotion Approvals (spec §7.13): every promotion request from a
/// vendor in this Manager's own territory. The Manager owns two actions —
/// confirming payment was received, and approving (or rejecting) the
/// request — approving requires payment already confirmed, since the spec's
/// flow is "payment received, then approved" in that order.
class ManagerPromotionApprovalsScreen extends ConsumerWidget {
  const ManagerPromotionApprovalsScreen({super.key});

  StatusTone _tone(PromotionStatus status) => switch (status) {
    PromotionStatus.active => StatusTone.success,
    PromotionStatus.rejected => StatusTone.error,
    PromotionStatus.pending => StatusTone.warning,
    PromotionStatus.ended => StatusTone.neutral,
  };

  Future<void> _markPaymentReceived(BuildContext context, String promotionId) async {
    try {
      await markPromotionPaymentReceived(promotionId);
    } catch (e, st) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e, action: 'Confirming payment', stackTrace: st))));
    }
  }

  Future<void> _approve(BuildContext context, String promotionId) async {
    try {
      await approvePromotion(promotionId);
    } catch (e, st) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e, action: 'Approving promotion', stackTrace: st))));
    }
  }

  Future<void> _reject(BuildContext context, String promotionId) async {
    try {
      await rejectPromotion(promotionId, 'Declined by Territory Manager');
    } catch (e, st) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e, action: 'Rejecting promotion', stackTrace: st))));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.colors;
    final managerAccount = ref.watch(currentManagerAccountProvider);
    final promotionsAsync = ref.watch(firestorePromotionsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Vendor Promotion Approvals')),
      body: promotionsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text(friendlyError(e, action: 'Loading promotions', stackTrace: st))),
        data: (allPromotions) {
          final requests = allPromotions.where((p) => p.matchesTerritory(managerAccount.territory)).toList()
            ..sort((a, b) => b.requestedAt.compareTo(a.requestedAt));

          if (requests.isEmpty) {
            return const EmptyState(icon: Icons.local_offer_outlined, title: 'No promotion requests', subtitle: 'Vendor promotion requests in your territory will show up here.');
          }
          return ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: requests.length,
            separatorBuilder: (context, _) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final promo = requests[i];
              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: palette.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: palette.border)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (promo.promoImageUrl != null || promo.vendorPhotoUrl != null) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: AppNetworkImage(url: (promo.promoImageUrl ?? promo.vendorPhotoUrl)!, width: double.infinity, height: 130),
                      ),
                      const SizedBox(height: 10),
                    ],
                    Row(
                      children: [
                        Expanded(child: Text(promo.vendorName, style: TextStyle(fontWeight: FontWeight.w800, color: palette.textPrimary))),
                        StatusChip(label: promo.status.label, tone: _tone(promo.status)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(promo.tagline ?? 'Promote my business', style: TextStyle(color: palette.textSecondary, fontSize: 13)),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.calendar_today_rounded, size: 13, color: palette.textMuted),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            promo.isOpenEnded
                                ? 'Started ${_dateFormat.format(promo.startDate)} · No end date'
                                : '${_dateFormat.format(promo.startDate)} — ${_dateFormat.format(promo.endDate!)} · ${promo.durationDays} days',
                            style: TextStyle(color: palette.textSecondary, fontSize: 11.5),
                          ),
                        ),
                        CurrencyText(promo.price, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: palette.textPrimary)),
                      ],
                    ),
                    if (promo.status == PromotionStatus.active) ...[
                      const SizedBox(height: 8),
                      StatusChip(
                        label: promo.isLiveNow ? 'Live now' : (promo.hasExpired ? 'Expired' : 'Scheduled'),
                        tone: promo.isLiveNow ? StatusTone.success : StatusTone.neutral,
                      ),
                    ],
                    if (promo.status == PromotionStatus.pending) ...[
                      const SizedBox(height: 12),
                      InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: promo.paymentReceived ? null : () => _markPaymentReceived(context, promo.id),
                        child: Row(
                          children: [
                            Icon(
                              promo.paymentReceived ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
                              color: promo.paymentReceived ? palette.success : palette.textMuted,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Payment received',
                              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5, color: promo.paymentReceived ? palette.success : palette.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(foregroundColor: palette.error, side: BorderSide(color: palette.error)),
                              onPressed: () => _reject(context, promo.id),
                              child: const Text('Reject'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: promo.paymentReceived ? () => _approve(context, promo.id) : null,
                              child: const Text('Approve'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
