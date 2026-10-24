import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geocoding/geocoding.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// The map position of a typed street address — the fallback for a shop
/// or drop-off that was saved without a pinned location, so the Driver's
/// navigation map still has a real destination to draw instead of the
/// placeholder. Uses the device's own geocoder (the `geocoding` package),
/// no API key. Null when the address is blank or can't be resolved.
/// Cached per address for the rest of the session.
final geocodedAddressProvider = FutureProvider.family<LatLng?, String>((ref, address) async {
  final query = address.trim();
  if (query.isEmpty) return null;
  try {
    final results = await Geocoding().locationFromAddress(query);
    if (results.isEmpty) return null;
    return LatLng(results.first.latitude, results.first.longitude);
  } catch (e) {
    debugPrint('geocode_provider: could not resolve "$query": $e');
    return null;
  }
});
