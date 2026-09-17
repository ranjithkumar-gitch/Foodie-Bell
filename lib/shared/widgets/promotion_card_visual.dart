import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../l10n/app_localizations_context.dart';
import 'app_network_image.dart';

/// The exact visual a Manager-approved promotion renders as on User Home
/// (`home_screen.dart`'s promo carousel) — pulled out into its own widget so
/// `vendor_promotions_screen.dart`'s "Request Promotion" form can render the
/// *same* card live, off in-progress form state (an unsaved [imageFile],
/// live-typed [tagline]/[discountLabel]), before a Vendor ever submits.
/// Home's card feeds it the persisted [Promotion] fields instead; both call
/// sites share this one implementation so "what you typed" and "what Users
/// see" can never visually drift apart.
class PromotionCardVisual extends StatelessWidget {
  const PromotionCardVisual({
    super.key,
    this.imageFile,
    this.imageUrl,
    this.vendorName,
    this.tagline,
    this.discountLabel,
    this.showOrderCta = true,
  });

  /// An unsaved, locally-picked photo (vendor form, before upload) — takes
  /// priority over [imageUrl] when both are set.
  final File? imageFile;

  /// A persisted photo URL (Home's real card, or the vendor form once it
  /// falls back to the vendor's own storefront photo).
  final String? imageUrl;

  /// Null (or blank) hides the name row entirely — an Admin-created
  /// "General App Promotion" isn't on behalf of any vendor, so there's
  /// nothing real to put here; Home (`home_screen.dart`) passes null rather
  /// than a placeholder like "Quicky" for those. The vendor form always
  /// passes the vendor's own name, since a vendor's own promotion is
  /// always on behalf of them.
  final String? vendorName;
  final String? tagline;

  /// Optional top-right badge (e.g. "50% OFF", "₹100 OFF") — a vendor's own
  /// free-text discount callout, shown as-is rather than parsed/validated.
  final String? discountLabel;

  /// False only for an Admin-created "General App Promotion" with no vendor
  /// to open — Home passes this through from `onTap == null`; the vendor
  /// form always shows it, since a vendor's own promotion always links to
  /// their storefront once live.
  final bool showOrderCta;

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (imageFile != null)
            Image.file(imageFile!, fit: BoxFit.cover)
          else if (imageUrl != null)
            AppNetworkImage(
              url: imageUrl!,
              width: double.infinity,
              height: double.infinity,
            )
          else
            Container(
              color: palette.surfaceMuted,
              child: Icon(
                Icons.storefront_rounded,
                color: palette.textMuted,
                size: 40,
              ),
            ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.15),
                  Colors.black.withValues(alpha: 0.78),
                ],
                stops: const [0.0, 0.55, 1.0],
              ),
            ),
          ),
          Positioned(
            top: 14,
            left: 14,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: palette.primary,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                context.l10n.homePromotedBadge,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ),
          if (discountLabel != null && discountLabel!.trim().isNotEmpty)
            Positioned(
              top: 14,
              right: 14,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: palette.secondary,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  discountLabel!.trim(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (vendorName != null && vendorName!.trim().isNotEmpty)
                        Text(
                          vendorName!,
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: palette.primaryLight,
                            fontSize: 17,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      if (tagline != null && tagline!.trim().isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          tagline!.trim(),
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.88),
                            fontSize: 12.5,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (showOrderCta) ...[
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          context.l10n.homeOrderNowCta,
                          style: TextStyle(
                            color: palette.primaryDark,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(width: 3),
                        Icon(
                          Icons.arrow_forward_rounded,
                          size: 14,
                          color: palette.primaryDark,
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
