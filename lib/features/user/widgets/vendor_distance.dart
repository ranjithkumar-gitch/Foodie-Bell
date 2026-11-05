import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';

import '../../../core/notifications/fcm_topics.dart';
import '../../../data/models/account.dart';
import '../../../data/models/address.dart';
import '../../../data/models/coupon.dart';
import '../../../data/providers/device_position_provider.dart';
import '../../../data/providers/firestore_addresses_provider.dart';
import '../../../l10n/app_localizations_context.dart';

/// Where the User's order would be delivered — what vendor distances and
/// delivery times are measured from: the address picked for delivery
/// (`selectedAddressProvider`) when it's pinned, else their default pinned
/// address, else any pinned one, else the phone's own position. Null when
/// none of these is known.
final deliveryPointProvider = Provider<LatLng?>((ref) {
  LatLng? pinOf(Address? a) => a != null && a.hasValidPin ? LatLng(a.latitude!, a.longitude!) : null;
  final selected = pinOf(ref.watch(selectedAddressProvider));
  if (selected != null) return selected;
  final userId = ref.watch(currentAccountIdProvider);
  if (userId != null) {
    final pinned = (ref.watch(firestoreAddressesProvider(userId)).valueOrNull ?? const <Address>[])
        .where((a) => a.hasValidPin)
        .toList();
    final saved = pinOf(pinned.where((a) => a.isDefault).firstOrNull ?? pinned.firstOrNull);
    if (saved != null) return saved;
  }
  return ref.watch(devicePositionProvider).valueOrNull;
});

/// Straight-line distance in km from [from] (the delivery point,
/// [deliveryPointProvider]) to [vendor]'s pinned shop location — null when
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

/// Always in km, never metres — a shop next door reads "0.1 km".
String formatDistanceKm(double km) {
  if (km < 0.1) return '0.1';
  return km < 10 ? km.toStringAsFixed(1) : km.toStringAsFixed(0);
}

/// [eta] as the User reads it: "25–30 mins" under an hour, then whole hours
/// ("2 hr"), then days ("1 day"), and past a week the date it would arrive.
String formatDeliveryWindow(BuildContext context, ({int min, int max}) eta) {
  final l10n = context.l10n;
  final max = eta.max;
  if (max < 60) return l10n.vendorEtaRange(eta.min, max);
  if (max < 24 * 60) return l10n.vendorEtaHours((max / 60).ceil());
  final days = (max / (24 * 60)).ceil();
  if (days <= 7) return l10n.vendorEtaDays(days);
  return l10n.vendorEtaDate(DateFormat('d MMM yyyy').format(DateTime.now().add(Duration(minutes: max))));
}

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
