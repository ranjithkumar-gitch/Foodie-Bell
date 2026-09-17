/// A Vendor's request to have their business promoted/featured — the
/// lifecycle is Vendor requests → Territory Manager's queue → Manager
/// confirms payment received and approves (or rejects) → once approved, it
/// goes live on the User Home page for that territory.
///
/// [ended] is a naturally-finished (or Admin-taken-down) run — distinct from
/// [rejected] (never went live). Written by QuickyAdmin (the separate admin
/// app sharing this `promotions` collection), not by this app.
enum PromotionStatus { pending, active, rejected, ended }

/// Sentinel [Promotion.territory] value for Admin-created promotions
/// launched network-wide rather than scoped to one territory (see
/// `admin_promotion_create_screen.dart`'s "All Territories" toggle) — every
/// territory-equality check against a promotion (`home_screen.dart`'s Home
/// feed, `manager_promotion_approvals_screen.dart`'s queue) should go
/// through [Promotion.matchesTerritory] rather than `==` so this stays the
/// single place that means "every territory".
const kAllTerritoriesLabel = 'All Territories';

extension PromotionStatusX on PromotionStatus {
  String get label => switch (this) {
    PromotionStatus.pending => 'Pending',
    PromotionStatus.active => 'Active',
    PromotionStatus.rejected => 'Rejected',
    PromotionStatus.ended => 'Ended',
  };
}

class Promotion {
  const Promotion({
    required this.id,
    required this.vendorId,
    required this.vendorName,
    required this.territory,
    required this.requestedAt,
    required this.startDate,
    this.durationDays,
    required this.price,
    this.vendorPhotoUrl,
    this.promoImageUrl,
    this.category,
    this.tagline,
    this.discountLabel,
    this.status = PromotionStatus.pending,
    this.paymentReceived = false,
    this.reviewedAt,
    this.rejectionReason,
  });

  final String id;
  final String vendorId;
  final String vendorName;

  /// Shop-front photo, if the vendor has one on file — fallback for the
  /// User Home promo card when [promoImageUrl] isn't set.
  final String? vendorPhotoUrl;

  /// The vendor's own 3:2 banner image uploaded specifically for this
  /// promotion request (`vendor_promotions_screen.dart`) — shown to the
  /// Manager during approval and, once approved, on the User Home promo
  /// card in place of [vendorPhotoUrl]. Optional: a vendor who skips this
  /// still gets featured, just with their storefront photo instead.
  final String? promoImageUrl;

  /// Denormalized at request time so Manager/Admin can filter/group by
  /// territory without joining against the vendor's live account.
  final String territory;
  final String? category;

  /// Optional short message the vendor wrote describing the promotion
  /// (e.g. "20% off this weekend") — shown on the Home card if present.
  final String? tagline;

  /// Optional free-text callout badge shown top-right of the Home card
  /// (e.g. "50% OFF", "₹100 OFF") — the vendor's own wording, not parsed or
  /// validated against the actual catalogue discount.
  final String? discountLabel;

  final PromotionStatus status;

  /// Set by the Manager once they've confirmed payment for the promotion —
  /// independent of [status], since payment is confirmed before approval.
  final bool paymentReceived;

  final DateTime requestedAt;
  final DateTime? reviewedAt;
  final String? rejectionReason;

  /// Vendor-picked go-live date (`vendor_promotions_screen.dart`'s Start
  /// Date field) — the promotion isn't shown on User Home until this date,
  /// even once Manager-approved, so a vendor can schedule a future campaign
  /// rather than always going live immediately.
  final DateTime startDate;

  /// The selected plan's day count (3/5/7/10/15 — see `promotion_plans.dart`),
  /// or **null** for an open-ended run that stays live until QuickyAdmin
  /// (the separate admin app) takes it down — the default for an
  /// Admin-created promotion. A Vendor request always picks a plan.
  final int? durationDays;

  /// The selected plan's price, paid to the Manager (spec's promotion fee)
  /// — real per-request revenue, not a flat assumed figure.
  final double price;

  bool get isOpenEnded => durationDays == null;

  /// [startDate] + [durationDays], or **null** for an open-ended run — the
  /// promotion stops showing on User Home once this passes, without needing
  /// [status] to change.
  DateTime? get endDate =>
      durationDays == null ? null : startDate.add(Duration(days: durationDays!));

  bool get hasStarted => !DateTime.now().isBefore(startDate);

  bool get hasExpired {
    final end = endDate;
    return end != null && DateTime.now().isAfter(end);
  }

  /// True only while the promotion is Manager-approved *and* today falls
  /// within [startDate]..[endDate] — the single check every "should this
  /// show to a User right now" call site (`home_screen.dart`) uses, so
  /// approval status and scheduling can never be checked separately and
  /// fall out of sync.
  bool get isLiveNow =>
      status == PromotionStatus.active && hasStarted && !hasExpired;

  /// True when this promotion targets [territoryName] specifically, or
  /// every territory ([kAllTerritoriesLabel]) — the check every
  /// territory-scoped promotion list should use instead of `==` against
  /// [territory] directly.
  bool matchesTerritory(String? territoryName) =>
      territory == territoryName || territory == kAllTerritoriesLabel;

  /// True for an Admin-created promotion not tied to any vendor (the
  /// "General App Promotion" toggle on `admin_promotion_create_screen.dart`)
  /// — a platform-wide offer/announcement rather than a featured business.
  /// Home's promoted card (`home_screen.dart`) uses this to skip pushing to
  /// a vendor detail page, since [vendorId] is empty and there's nothing to
  /// open.
  bool get isAppPromotion => vendorId.isEmpty;
}
