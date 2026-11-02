import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Road routes for the map, served by the backend's `orderRoute` callable
/// (Phase F). The server holds the Routes API key and routes only from
/// points it knows (the shop, the customer, the Driver's tracked position)
/// for an order the caller is party to — the app no longer ships a Google
/// key that anyone could lift and spend.

/// A driving route along real roads between two points, as Google worked
/// it out — the line to draw on the map plus how far and how long it is.
class RoadRoute {
  const RoadRoute({required this.points, required this.distanceMeters, required this.durationSeconds});

  final List<LatLng> points;
  final int distanceMeters;
  final int durationSeconds;

  /// From the callable's `{encodedPolyline, distanceMeters, durationSeconds}`.
  static RoadRoute? fromResult(Object? data) {
    if (data is! Map) return null;
    final encoded = data['encodedPolyline'];
    if (encoded is! String || encoded.isEmpty) return null;
    return RoadRoute(
      points: decodePolyline(encoded),
      distanceMeters: (data['distanceMeters'] as num?)?.toInt() ?? 0,
      durationSeconds: (data['durationSeconds'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Which route of an order: `pickup` (Driver → shop), `dropoff` (Driver →
/// customer), `offer` (shop → customer, an open offer) or `approach` (this
/// device → shop, for an open offer; [origin] is snapped to ~110 m so a
/// moving Driver doesn't trigger a lookup on every GPS update).
typedef OrderRouteRequest = ({String orderId, String leg, double? originLatitude, double? originLongitude});

OrderRouteRequest orderRouteRequest(String orderId, String leg, {LatLng? origin}) => (
      orderId: orderId,
      leg: leg,
      originLatitude: origin == null ? null : double.parse(origin.latitude.toStringAsFixed(3)),
      originLongitude: origin == null ? null : double.parse(origin.longitude.toStringAsFixed(3)),
    );

/// The callable, swappable in tests.
typedef OrderRouteCall = Future<Object?> Function(Map<String, Object?> data);

OrderRouteCall orderRouteCall = (data) async =>
    (await FirebaseFunctions.instanceFor(region: 'asia-south1').httpsCallable('orderRoute').call<Object?>(data)).data;

/// The road route for a request — null when there is none to show (no
/// fix yet, no road route, quota or network trouble), which callers treat
/// as "draw the straight line" rather than an error screen.
final roadRouteProvider = FutureProvider.autoDispose.family<RoadRoute?, OrderRouteRequest>((ref, request) async {
  try {
    final result = await orderRouteCall({
      'orderId': request.orderId,
      'leg': request.leg,
      if (request.originLatitude != null) 'origin': {'latitude': request.originLatitude, 'longitude': request.originLongitude},
    });
    return RoadRoute.fromResult(result is Map ? result['route'] : null);
  } catch (e) {
    debugPrint('road_route_provider: route lookup failed: $e');
    return null;
  }
});

/// Google's "encoded polyline" format: each coordinate is stored as the
/// difference from the previous one, in 5-bit chunks offset by 63.
List<LatLng> decodePolyline(String encoded) {
  final points = <LatLng>[];
  var index = 0;
  var latitude = 0;
  var longitude = 0;

  int nextDelta() {
    var shift = 0;
    var result = 0;
    int chunk;
    do {
      chunk = encoded.codeUnitAt(index++) - 63;
      result |= (chunk & 0x1f) << shift;
      shift += 5;
    } while (chunk >= 0x20 && index < encoded.length);
    return (result & 1) != 0 ? ~(result >> 1) : result >> 1;
  }

  while (index < encoded.length) {
    latitude += nextDelta();
    if (index >= encoded.length) break;
    longitude += nextDelta();
    points.add(LatLng(latitude / 1e5, longitude / 1e5));
  }
  return points;
}
