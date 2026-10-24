import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Where this phone is right now — the User's own position, shared by the
/// order tracking map (`driver_live_map.dart`, its last-resort drop-off pin)
/// and Home/Search's distance + delivery-time estimates on vendor cards
/// (`vendor_distance.dart`). Null when location is off or not allowed.
/// Kept alive after the first successful fix so every screen reuses it
/// instead of each one waiting on its own GPS read.
final devicePositionProvider = FutureProvider.autoDispose<LatLng?>((ref) async {
  try {
    if (!await Geolocator.isLocationServiceEnabled()) return null;
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) return null;
    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 20)),
    );
    ref.keepAlive();
    return LatLng(position.latitude, position.longitude);
  } catch (e) {
    debugPrint('device_position_provider: reading this phone\'s position failed: $e');
    return null;
  }
});
