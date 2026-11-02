import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/order.dart';
import '../../../l10n/app_localizations_context.dart';
import '../../../shared/cancellation_reasons.dart';

/// "The shop cancelled your order" with the reason label (Phase I.4). Shown
/// to the customer only for a vendor-attributed cancellation; it never shows
/// the shop's internal remark, and never claims a refund is complete (the
/// UPI payment card shows the refund's own server status).
class ShopCancelledBanner extends StatelessWidget {
  const ShopCancelledBanner({super.key, required this.cancellation});
  final OrderCancellation cancellation;

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    final l10n = context.l10n;
    final reason = cancellation.reasonCode;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: palette.error.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(14), border: Border.all(color: palette.error.withValues(alpha: 0.35))),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.storefront_outlined, color: palette.error),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.orderCancelledByShop, style: TextStyle(fontWeight: FontWeight.w700, color: palette.textPrimary)),
                if (reason != null && reason.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(l10n.orderCancelledReason(reasonLabel(l10n, reason)), style: TextStyle(color: palette.textSecondary)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
