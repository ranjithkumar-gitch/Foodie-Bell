import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodiebell/data/providers/road_route_provider.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

void main() {
  late OrderRouteCall original;
  setUp(() => original = orderRouteCall);
  tearDown(() => orderRouteCall = original);

  test("decodes Google's documented example polyline", () {
    final pts = decodePolyline('_p~iF~ps|U_ulLnnqC_mqNvxq`@');
    expect(pts.map((p) => [p.latitude, p.longitude]), [
      [38.5, -120.2],
      [40.7, -120.95],
      [43.252, -126.453],
    ]);
  });

  test('routes come from the orderRoute callable — no key in the app', () async {
    final calls = <Map<String, Object?>>[];
    orderRouteCall = (data) async {
      calls.add(data);
      return {'route': {'encodedPolyline': '_p~iF~ps|U_ulLnnqC_mqNvxq`@', 'distanceMeters': 1234, 'durationSeconds': 300}};
    };
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final r = await container.read(roadRouteProvider(orderRouteRequest('ORD-1', 'pickup')).future);
    expect((r!.distanceMeters, r.durationSeconds, r.points.length), (1234, 300, 3));
    expect(calls.single, {'orderId': 'ORD-1', 'leg': 'pickup'});

    await container.read(roadRouteProvider(orderRouteRequest('ORD-1', 'approach', origin: const LatLng(17.123456, 78.98765))).future);
    expect(calls.last, {'orderId': 'ORD-1', 'leg': 'approach', 'origin': {'latitude': 17.123, 'longitude': 78.988}}, reason: 'origin snapped to ~110 m');
  });

  test('no route, an error or quota trouble is "no route to show", never a crash', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    orderRouteCall = (data) async => {'route': null};
    expect(await container.read(roadRouteProvider(orderRouteRequest('A', 'dropoff')).future), isNull);
    orderRouteCall = (data) async => throw Exception('resource-exhausted');
    expect(await container.read(roadRouteProvider(orderRouteRequest('B', 'dropoff')).future), isNull);
  });
}
