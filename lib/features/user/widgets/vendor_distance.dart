import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../data/models/account.dart';
import '../../../data/models/coupon.dart';

/// Straight-line distance in km from [from] (the User's own position,
/// `devicePositionProvider`) to [vendor]'s pinned shop location — null when
/// either side isn't known, so cards simply leave the distance off instead
/// of showing a made-up one.
double? vendorDistanceKm(Account vendor, LatLng? from) {
  if (from == null || vendor.latitude == null || vendor.longitude == null) return null;
  return Geolocator.distanceBetween(from.latitude, from.longitude, vendor.latitude!, vendor.longitude!) / 1000;
}

/// A Swiggy-style "25–30 mins" delivery window estimated from [km]: a flat
/// ~15 min for the vendor to prepare/pack, plus ~4 min per km of road (a
/// bike averaging ~15 km/h through town traffic, straight-line distance
/// being shorter than the real road), rounded to 5-minute steps.
({int min, int max}) estimatedDeliveryWindow(double km) {
  final minutes = 15 + km * 4;
  final low = (minutes / 5).round() * 5;
  return (min: low < 15 ? 15 : low, max: (low < 15 ? 15 : low) + 5);
}

String formatDistanceKm(double km) => km < 10 ? km.toStringAsFixed(1) : km.toStringAsFixed(0);

/// The live coupon worth headlining on [vendorId]'s card/storefront — the
/// biggest percentage-off one, else the biggest flat-off one. Null when the
/// vendor has nothing live right now.
Coupon? bestLiveCoupon(Iterable<Coupon> coupons, String vendorId) {
  Coupon? best;
  for (final c in coupons) {
    if (c.vendorId != vendorId || !c.isLiveNow) continue;
    if (best == null) {
      best = c;
      continue;
    }
    final cPct = c.discountType == CouponDiscountType.percentage;
    final bestPct = best.discountType == CouponDiscountType.percentage;
    if (cPct != bestPct) {
      if (cPct) best = c;
    } else if (c.discountValue > best.discountValue) {
      best = c;
    }
  }
  return best;
}
