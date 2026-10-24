import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// The same Google Cloud key the map itself is drawn with
/// (`AndroidManifest.xml` / `AppDelegate.swift`). Looking up a road route
/// with it needs the **Routes API** enabled on that key's project, and the
/// key must not be locked to "Android apps"/"iOS apps" only — these are
/// plain web requests, which that kind of restriction rejects.
const _googleMapsApiKey = 'AIzaSyBVE7vsYfkVURXi8UTjXDyNoE_EBPOvdcQ';

/// A driving route along real roads between two points, as Google worked
/// it out — the line to draw on the map plus how far and how long it is.
class RoadRoute {
  const RoadRoute({required this.points, required this.distanceMeters, required this.durationSeconds});

  final List<LatLng> points;
  final int distanceMeters;
  final int durationSeconds;
}

/// Origin and destination of a route lookup, plus an optional stop the
/// route has to pass through on the way.
typedef RoadRouteRequest = ({
  double fromLatitude,
  double fromLongitude,
  double toLatitude,
  double toLongitude,
  double? viaLatitude,
  double? viaLongitude,
});

/// Builds the lookup key for [roadRouteProvider]. The origin is snapped to
/// a ~100 m grid: a moving Driver then only triggers (and pays for) a new
/// Google lookup about every 100 m, not on every GPS update. [via] is a
/// stop in between — the shop, on a Driver's way to the customer.
RoadRouteRequest roadRouteRequest({required LatLng from, required LatLng to, LatLng? via}) => (
  fromLatitude: double.parse(from.latitude.toStringAsFixed(3)),
  fromLongitude: double.parse(from.longitude.toStringAsFixed(3)),
  toLatitude: to.latitude,
  toLongitude: to.longitude,
  viaLatitude: via?.latitude,
  viaLongitude: via?.longitude,
);

/// The road route for a [RoadRouteRequest] — null when Google couldn't be
/// reached or refused the request (API not enabled, key restricted, no
/// network), which callers treat as "no route to show" rather than an
/// error screen.
final roadRouteProvider = FutureProvider.autoDispose.family<RoadRoute?, RoadRouteRequest>((ref, request) async {
  try {
    return await _fetchFromRoutesApi(request);
  } catch (e, st) {
    debugPrint('road_route_provider: route lookup failed: $e\n$st');
    return null;
  }
});

Future<Map<String, dynamic>> _readJson(HttpClientResponse response) async {
  final body = await response.transform(utf8.decoder).join();
  final decoded = jsonDecode(body);
  return decoded is Map<String, dynamic> ? decoded : const {};
}

Future<RoadRoute?> _fetchFromRoutesApi(RoadRouteRequest request) async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 10);
  try {
    final httpRequest = await client.postUrl(Uri.parse('https://routes.googleapis.com/directions/v2:computeRoutes'));
    httpRequest.headers
      ..contentType = ContentType.json
      ..set('X-Goog-Api-Key', _googleMapsApiKey)
      ..set('X-Goog-FieldMask', 'routes.distanceMeters,routes.duration,routes.polyline.encodedPolyline');
    httpRequest.write(
      jsonEncode({
        'origin': {
          'location': {
            'latLng': {'latitude': request.fromLatitude, 'longitude': request.fromLongitude},
          },
        },
        'destination': {
          'location': {
            'latLng': {'latitude': request.toLatitude, 'longitude': request.toLongitude},
          },
        },
        if (request.viaLatitude != null && request.viaLongitude != null)
          'intermediates': [
            {
              'location': {
                'latLng': {'latitude': request.viaLatitude, 'longitude': request.viaLongitude},
              },
            },
          ],
        'travelMode': 'DRIVE',
      }),
    );
    final response = await httpRequest.close().timeout(const Duration(seconds: 15));
    final json = await _readJson(response);
    final routes = json['routes'] as List<dynamic>?;
    if (response.statusCode != 200 || routes == null || routes.isEmpty) {
      debugPrint('road_route_provider: Routes API gave no route (${response.statusCode}): ${json['error'] ?? json}');
      return null;
    }
    final route = routes.first as Map<String, dynamic>;
    final encoded = (route['polyline'] as Map<String, dynamic>?)?['encodedPolyline'] as String?;
    if (encoded == null) return null;
    // Duration comes back as e.g. "345s".
    final duration = (route['duration'] as String? ?? '').replaceAll('s', '');
    return RoadRoute(
      points: _decodePolyline(encoded),
      distanceMeters: (route['distanceMeters'] as num?)?.toInt() ?? 0,
      durationSeconds: double.tryParse(duration)?.round() ?? 0,
    );
  } finally {
    client.close(force: true);
  }
}

/// Google's "encoded polyline" format: each coordinate is stored as the
/// difference from the previous one, in 5-bit chunks offset by 63.
List<LatLng> _decodePolyline(String encoded) {
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
