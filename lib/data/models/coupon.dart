import '../../shared/widgets/currency_text.dart';

enum CouponDiscountType { percentage, flatAmount }

/// A Vendor-created discount code (spec-adjacent to `Promotion`, but a real
/// price reduction rather than a paid "get featured" placement) — either a
/// percentage or a flat ₹ amount off, applied either to the Vendor's whole
/// catalogue or a hand-picked subset of it. Published to Users on Home
/// (`home_screen.dart`, below the Promotions carousel) once
/// [isLiveNow]; redeemed in the cart (`cart_screen.dart`) and enforced
/// single-use-per-User at order placement time
/// (`firestore_orders_provider.dart`'s `createOrderWithCoupon`).
class Coupon {
  const Coupon({
    required this.id,
    required this.vendorId,
    required this.vendorName,
    required this.code,
    required this.discountType,
    required this.discountValue,
    required this.appliesToAllItems,
    required this.productIds,
    required this.startAt,
    required this.endAt,
    required this.createdAt,
  });

  final String id;
  final String vendorId;
  final String vendorName;

  /// Unique, vendor-facing redemption code (`generateCouponCode`) — shown to
  /// the vendor on creation and typed/tapped by Users in the cart.
  final String code;

  final CouponDiscountType discountType;

  /// A percentage (0-100) when [discountType] is `percentage`, otherwise a
  /// flat ₹ amount.
  final double discountValue;

  /// True when this coupon discounts every product in the vendor's
  /// catalogue; false means only [productIds] qualify.
  final bool appliesToAllItems;

  /// Product ids this coupon discounts — empty and unused when
  /// [appliesToAllItems] is true.
  final List<String> productIds;

  /// Vendor-picked validity window start (date + time combined).
  final DateTime startAt;

  /// Vendor-picked validity window end (date + time combined).
  final DateTime endAt;

  final DateTime createdAt;

  bool get hasStarted => !DateTime.now().isBefore(startAt);

  bool get hasExpired => DateTime.now().isAfter(endAt);

  /// True only while today falls within [startAt]..[endAt] — the single
  /// check every "can this coupon be shown/applied right now" call site
  /// should use, mirroring `Promotion.isLiveNow`.
  bool get isLiveNow => hasStarted && !hasExpired;

  bool appliesToProduct(String productId) =>
      appliesToAllItems || productIds.contains(productId);

  String get discountLabel => discountType == CouponDiscountType.percentage
      ? '${_trimTrailingZero(discountValue)}% OFF'
      : '${AppFormat.currency(discountValue)} OFF';
}

String _trimTrailingZero(double value) =>
    value == value.roundToDouble() ? value.toStringAsFixed(0) : value.toString();
