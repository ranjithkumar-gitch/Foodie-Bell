import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/account.dart';
import '../../../data/models/vendor_document.dart';
import '../../../data/providers/device_position_provider.dart';
import '../../../data/providers/firestore_coupons_provider.dart';
import '../../../data/providers/firestore_reviews_provider.dart';
import '../../../l10n/app_localizations_context.dart';
import '../../../shared/widgets/app_network_image.dart';
import '../../../shared/widgets/currency_text.dart';
import '../../../shared/widgets/rating_badge.dart';
import '../translation/translated_text.dart';
import '../user_constants.dart';
import 'vendor_distance.dart';

/// Full-width card for a real, Firestore-backed Vendor `Account` — the
/// User-browsing equivalent of `vendor_card.dart`'s `VendorCard`, which is
/// typed to the mock storefront `Vendor` model and stays untouched/unused
/// here. Distance and the delivery-time window are only shown when both the
/// vendor's pinned shop location and the User's own position are known
/// (`vendor_distance.dart`), and the offer strip is the vendor's best live
/// coupon — nothing is fabricated when that data is missing. Rating *is* real
/// — averaged from [firestoreReviewsProvider] the same way
/// `vendor_detail_screen.dart` computes it — and only shown once the vendor
/// has at least one review, rather than showing a fabricated "new" score. A
/// closed vendor ([Account.isOpen]) gets the same "CLOSED" overlay
/// `VendorCard` shows — still browsable, but `vendor_detail_screen.dart`
/// blocks actually ordering from them. Cover image is the vendor's own
/// submitted shop-front photo (`VendorDocumentType.shopFrontPhoto`) when
/// they've uploaded one, else a plain category-icon placeholder.
class VendorAccountCard extends ConsumerWidget {
  const VendorAccountCard({
    super.key,
    required this.account,
    required this.categoryName,
    required this.onTap,
  });

  final Account account;
  final String? categoryName;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.colors;
    final coverUrl = account.documentUrl(VendorDocumentType.shopFrontPhoto);
    final vendorReviews =
        (ref.watch(firestoreReviewsProvider).valueOrNull ?? const [])
            .where((r) => r.vendorId == account.id)
            .toList();
    final averageRating = vendorReviews.isEmpty
        ? null
        : vendorReviews.map((r) => r.vendorRating).reduce((a, b) => a + b) /
              vendorReviews.length;
    final distanceKm = vendorDistanceKm(
      account,
      ref.watch(devicePositionProvider).valueOrNull,
    );
    final eta = distanceKm == null ? null : estimatedDeliveryWindow(distanceKm);
    final offer = bestLiveCoupon(
      ref.watch(firestoreCouponsProvider).valueOrNull ?? const [],
      account.id,
    );

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                coverUrl != null
                    ? AppNetworkImage(
                        url: coverUrl,
                        height: 140,
                        width: double.infinity,
                      )
                    : Container(
                        height: 140,
                        width: double.infinity,
                        color: palette.surfaceMuted,
                        child: Icon(
                          Icons.storefront_rounded,
                          size: 40,
                          color: palette.textMuted,
                        ),
                      ),
                if (!account.isOpen)
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.5),
                      ),
                      child: Center(
                        child: Text(
                          context.l10n.storefrontClosedBadge,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    ),
                  ),
                // Swiggy-style offer strip along the bottom of the photo —
                // the vendor's best live coupon, so the deal is visible
                // before the User even opens the storefront.
                if (offer != null && account.isOpen)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(12, 18, 12, 8),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0),
                            Colors.black.withValues(alpha: 0.75),
                          ],
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.local_offer_rounded,
                            size: 14,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              '${offer.discountLabel} · ${context.l10n.vendorOfferUseCode(offer.code)}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 13,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (averageRating != null)
                  Positioned(
                    top: 10,
                    right: 10,
                    child: RatingBadge(rating: averageRating, dark: true),
                  ),
                if (account.isOpen)
                  Positioned(
                    top: 10,
                    left: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: palette.success,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            context.l10n.storefrontOpenNow,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    account.name,
                    style: Theme.of(context).textTheme.titleMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (categoryName != null) ...[
                    const SizedBox(height: 4),
                    TranslatedText(
                      categoryName!,
                      style: Theme.of(context).textTheme.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      if (eta != null) ...[
                        _MetaTag(
                          icon: Icons.schedule_rounded,
                          label: context.l10n.vendorEtaRange(eta.min, eta.max),
                          emphasize: true,
                        ),
                        const SizedBox(width: 14),
                      ],
                      _MetaTag(
                        icon: Icons.moped_outlined,
                        label: AppFormat.currency(
                          UserConstants.defaultDeliveryFee,
                        ),
                      ),
                      if (distanceKm != null) ...[
                        const SizedBox(width: 14),
                        Expanded(
                          child: _MetaTag(
                            icon: Icons.near_me_outlined,
                            label: context.l10n.vendorDistanceKm(
                              formatDistanceKm(distanceKm),
                            ),
                          ),
                        ),
                      ] else if (account.territory != null) ...[
                        const SizedBox(width: 14),
                        Expanded(
                          child: _MetaTag(
                            icon: Icons.place_outlined,
                            label: account.territory!,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetaTag extends StatelessWidget {
  const _MetaTag({
    required this.icon,
    required this.label,
    this.emphasize = false,
  });

  final IconData icon;
  final String label;

  /// The delivery-time tag — bolder and in the text colour, since it's the
  /// first thing a User scans a vendor list for.
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 14,
          color: emphasize ? palette.primary : palette.textMuted,
        ),
        const SizedBox(width: 3),
        Flexible(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: emphasize ? FontWeight.w800 : FontWeight.w600,
              color: emphasize ? palette.textPrimary : palette.textSecondary,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
