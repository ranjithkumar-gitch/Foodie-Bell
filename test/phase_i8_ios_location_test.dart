// Phase I.8 Batch 3: iOS Google Maps configuration, location permissions and
// the Driver's background tracking during an active delivery. The location
// platform is faked (no GPS, no Firestore); iOS behaviour is exercised with
// `debugDefaultTargetPlatformOverride`. This is not a device test: real
// background GPS on an iPhone is NOT VERIFIED here.
import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodiebell/core/maps/maps_availability.dart';
import 'package:foodiebell/data/models/order.dart';
import 'package:foodiebell/data/providers/firestore_orders_provider.dart';
import 'package:foodiebell/features/driver/driver_location_tracker.dart';
import 'package:geolocator/geolocator.dart';

class FakeGeo extends GeolocatorPlatform {
  bool serviceEnabled = true;
  LocationPermission permission = LocationPermission.whileInUse;
  LocationPermission afterRequest = LocationPermission.whileInUse;
  LocationAccuracyStatus accuracy = LocationAccuracyStatus.precise;
  int permissionRequests = 0;
  int fullAccuracyRequests = 0;
  final streams = <StreamController<Position>>[];
  final settings = <LocationSettings?>[];

  int get openStreams => streams.where((c) => c.hasListener).length;
  StreamController<Position> get latest => streams.last;

  @override
  Future<bool> isLocationServiceEnabled() async => serviceEnabled;
  @override
  Future<LocationPermission> checkPermission() async => permission;
  @override
  Future<LocationPermission> requestPermission() async {
    permissionRequests++;
    permission = afterRequest;
    return permission;
  }

  @override
  Future<Position?> getLastKnownPosition({bool forceLocationManager = false}) async => null;
  @override
  Stream<Position> getPositionStream({LocationSettings? locationSettings}) {
    final c = StreamController<Position>();
    streams.add(c);
    settings.add(locationSettings);
    return c.stream;
  }

  @override
  Future<LocationAccuracyStatus> getLocationAccuracy() async => accuracy;
  @override
  Future<LocationAccuracyStatus> requestTemporaryFullAccuracy({required String purposeKey}) async {
    fullAccuracyRequests++;
    return LocationAccuracyStatus.precise;
  }
}

Position _pos(double lat) => Position(
  latitude: lat, longitude: 78.0, timestamp: DateTime(2026, 11, 2), accuracy: 5, altitude: 0, altitudeAccuracy: 0,
  heading: 0, headingAccuracy: 0, speed: 0, speedAccuracy: 0,
);

Order _order(String id, OrderStatus status, {String driverId = 'd1'}) => Order(
  id: id, vendorId: 'v1', vendorName: 'Shop', userId: 'c1', userName: 'C', userPhone: '', items: const [],
  deliveryAddressLabel: 'Home', paymentMethod: PaymentMethod.cod, subtotal: 100, deliveryFee: 20, platformFee: 5,
  gstAmount: 0, total: 125, placedAt: DateTime(2026, 11, 2), rebatePercent: 10, status: status, driverId: driverId,
);

class _Writes {
  final driver = <String>[];
  final orders = <String>[];
  Object? fail;
  Future<void> writeDriver(String id, {required double latitude, required double longitude}) async {
    if (fail != null) throw fail!;
    driver.add('$id@$latitude');
  }

  Future<void> writeOrder(String id, {required double latitude, required double longitude}) async {
    if (fail != null) throw fail!;
    orders.add('$id@$latitude');
  }
}

/// Pumps the app-level wiring (`listenForDriverLocationTracking`) with the
/// given signed-in Driver and active-orders stream.
Future<({ProviderContainer container, StateController<String?> driver})> _wire(
  WidgetTester tester, {
  required DriverLocationTracker tracker,
  required Stream<List<Order>> orders,
  String? driverId = 'd1',
}) async {
  final driver = StateProvider<String?>((ref) => driverId);
  final scope = ProviderScope(
    overrides: [
      driverLocationTrackerProvider.overrideWithValue(tracker),
      trackedDriverIdProvider.overrideWith((ref) => ref.watch(driver)),
      activeOrdersProvider.overrideWith((ref) => orders),
    ],
    child: Consumer(builder: (context, ref, _) {
      listenForDriverLocationTracking(ref);
      // Keep the providers alive, as QuickyApp's tree does.
      ref.watch(trackedActiveOrderIdsProvider);
      return const SizedBox();
    }),
  );
  await tester.pumpWidget(scope);
  await tester.pump();
  final container = ProviderScope.containerOf(tester.element(find.byType(SizedBox)));
  return (container: container, driver: container.read(driver.notifier));
}

/// Lets the tracker's async work finish. A stream subscription's `cancel()`
/// completes on the real event loop, which the widget tester's fake clock
/// doesn't run — so give it real time too.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 3; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pump(const Duration(milliseconds: 10));
  }
}

void main() {
  late FakeGeo geo;
  late GeolocatorPlatform original;
  setUp(() {
    original = GeolocatorPlatform.instance;
    geo = FakeGeo();
    GeolocatorPlatform.instance = geo;
  });
  tearDown(() => GeolocatorPlatform.instance = original);

  group('iOS project configuration (Info.plist, AppDelegate, xcconfig)', () {
    final plist = File('ios/Runner/Info.plist').readAsStringSync();
    test('location strings are present; When In Use is what geolocator asks for', () {
      expect(plist, contains('<key>NSLocationWhenInUseUsageDescription</key>'));
      expect(plist, contains('<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>'));
      expect(plist, contains('<key>DeliveryTracking</key>'));
      // geolocator_apple requests When In Use whenever that key exists, so no
      // role is ever prompted for Always by `requestPermission()`.
      expect(plist.indexOf('NSLocationWhenInUseUsageDescription'), greaterThan(0));
    });

    test('background modes: remote notifications kept, location added for deliveries', () {
      final modes = RegExp(r'<key>UIBackgroundModes</key>\s*<array>(.*?)</array>', dotAll: true).firstMatch(plist)!.group(1)!;
      expect(modes, contains('<string>remote-notification</string>'));
      expect(modes, contains('<string>location</string>'));
    });

    test('the Maps key comes from the git-ignored Secrets.xcconfig, never hard-coded', () {
      expect(plist, contains('<key>GMSApiKey</key>'));
      expect(plist, contains(r'<string>$(GMS_API_KEY)</string>'));
      expect(plist, isNot(contains('AIza')), reason: 'no real key in the plist');
      for (final f in ['ios/Flutter/Debug.xcconfig', 'ios/Flutter/Release.xcconfig']) {
        expect(File(f).readAsStringSync(), contains('#include? "Secrets.xcconfig"'), reason: f);
      }
      final example = File('ios/Flutter/Secrets.xcconfig.example').readAsStringSync();
      expect(RegExp(r'^GMS_API_KEY\s*=\s*$', multiLine: true).hasMatch(example), isTrue, reason: 'the template is empty');
      final delegate = File('ios/Runner/AppDelegate.swift').readAsStringSync();
      expect(delegate, contains('GMSServices.provideAPIKey(key)'));
      expect(delegate, isNot(contains('AIza')));
      expect(delegate, isNot(contains('print(')), reason: 'the key is never logged');
      expect(delegate.indexOf('provideAPIKey'), lessThan(delegate.indexOf('super.application')), reason: 'before any map can be created');
    });
  });

  group('1, 2: Maps availability', () {
    const channel = mapsConfigChannel;
    tearDown(() => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null));

    test('iOS asks AppDelegate; Android and web need no key check', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async => call.method == 'isConfigured');
      expect(await mapsConfigured(platform: TargetPlatform.iOS, isWeb: false), isTrue);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async => false);
      expect(await mapsConfigured(platform: TargetPlatform.iOS, isWeb: false), isFalse);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async => throw PlatformException(code: 'x'));
      expect(await mapsConfigured(platform: TargetPlatform.iOS, isWeb: false), isFalse, reason: 'a failure is "unavailable", never a crash');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
      expect(await mapsConfigured(platform: TargetPlatform.iOS, isWeb: false), isFalse, reason: 'no handler (older build)');
      expect(await mapsConfigured(platform: TargetPlatform.android, isWeb: false), isTrue);
    });

    testWidgets('a missing key shows a placeholder instead of the map; a configured one shows the map', (tester) async {
      for (final (ok, expectMap) in [(false, false), (true, true)]) {
        await tester.pumpWidget(ProviderScope(
          key: UniqueKey(),
          overrides: [mapsAvailableProvider.overrideWith((ref) async => ok)],
          child: const MaterialApp(home: Scaffold(body: SizedBox(height: 200, child: MapsGate(child: Text('the map'))))),
        ));
        await tester.pumpAndSettle();
        expect(find.text('the map'), expectMap ? findsOneWidget : findsNothing);
        expect(find.text('Map unavailable'), expectMap ? findsNothing : findsOneWidget);
      }
    });
  });

  group('3–6, 18: permissions and Location Services', () {
    test('3: the first start asks once (When In Use) and tracks; a resume never re-prompts', () async {
      geo.permission = LocationPermission.denied;
      final w = _Writes();
      final t = DriverLocationTracker(writeDriver: w.writeDriver, writeOrder: w.writeOrder);
      await t.start('d1');
      expect([geo.permissionRequests, t.isTracking], [1, true]);
      await t.stop();
      geo.permission = LocationPermission.denied;
      geo.afterRequest = LocationPermission.denied;
      await t.start('d1');
      await t.retryIfIdle();
      expect(geo.permissionRequests, 2, reason: 'retryIfIdle never shows the prompt');
      await t.stop();
    });

    test('4: background reporting only during a delivery (iOS settings), with the location indicator', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      try {
        final t = DriverLocationTracker(writeDriver: _Writes().writeDriver, writeOrder: _Writes().writeOrder);
        await t.start('d1');
        var s = geo.settings.last as AppleSettings;
        expect([s.allowBackgroundLocationUpdates, s.showBackgroundLocationIndicator, s.pauseLocationUpdatesAutomatically], [false, false, false]);
        await t.setOnDelivery(true);
        s = geo.settings.last as AppleSettings;
        expect([s.allowBackgroundLocationUpdates, s.showBackgroundLocationIndicator, s.accuracy, s.distanceFilter], [true, true, LocationAccuracy.high, 10], reason: 'the existing accuracy and 10 m filter are unchanged');
        expect(geo.openStreams, 1);
        await t.stop();
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    test('reduced accuracy during a delivery asks for temporary full accuracy once per start; refusal keeps tracking', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      try {
        geo.accuracy = LocationAccuracyStatus.reduced;
        final t = DriverLocationTracker(writeDriver: _Writes().writeDriver, writeOrder: _Writes().writeOrder);
        await t.start('d1');
        expect(geo.fullAccuracyRequests, 0, reason: 'not while idle');
        await t.setOnDelivery(true);
        expect([geo.fullAccuracyRequests, t.isTracking], [1, true]);
        await t.stop();
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    test('5, 6: denied or permanently denied — no tracking, no crash, no repeated prompt', () async {
      for (final p in [LocationPermission.denied, LocationPermission.deniedForever]) {
        geo
          ..permission = p
          ..afterRequest = p
          ..permissionRequests = 0;
        final t = DriverLocationTracker(writeDriver: _Writes().writeDriver, writeOrder: _Writes().writeOrder);
        await t.start('d1');
        await t.setOnDelivery(true);
        expect([t.isTracking, geo.openStreams], [false, 0], reason: '$p');
        expect(geo.permissionRequests, p == LocationPermission.denied ? 1 : 0, reason: 'deniedForever is never re-prompted');
        await t.stop();
      }
    });

    test('18: Location Services off — nothing starts; once switched on, a resume starts it', () async {
      geo.serviceEnabled = false;
      final t = DriverLocationTracker(writeDriver: _Writes().writeDriver, writeOrder: _Writes().writeOrder);
      await t.start('d1');
      expect(t.isTracking, isFalse);
      geo.serviceEnabled = true;
      await t.retryIfIdle();
      expect(t.isTracking, isTrue);
      // The stream fails (GPS switched off mid-session): dropped, restarted on resume.
      geo.latest.addError(const LocationServiceDisabledException());
      await Future<void>.delayed(Duration.zero);
      expect(t.isTracking, isFalse);
      await t.retryIfIdle();
      expect([t.isTracking, geo.openStreams], [true, 1]);
      await t.stop();
    });
  });

  group('7–16, 19: delivery lifecycle, through the app wiring', () {
    testWidgets('7–12: a delivery starts background tracking; completion, cancellation and reassignment end it', (tester) async {
      final w = _Writes();
      var clock = DateTime(2026, 11, 2, 12);
      final tracker = DriverLocationTracker(writeDriver: w.writeDriver, writeOrder: w.writeOrder, now: () => clock);
      final orders = StreamController<List<Order>>.broadcast();
      addTearDown(orders.close);
      // As in the app: the session goes from nobody to the Driver.
      final wired = await _wire(tester, tracker: tracker, orders: orders.stream, driverId: null);
      wired.driver.state = 'd1';
      await _settle(tester);
      expect([tracker.isTracking, tracker.onDelivery], [true, false], reason: 'signed-in Driver, no delivery: foreground only');
      for (final (label, end) in [
        ('completed', _order('o1', OrderStatus.delivered)),
        ('cancelled', _order('o1', OrderStatus.cancelled)),
        ('reassigned away', _order('o1', OrderStatus.pickedUp, driverId: 'd2')),
      ]) {
        orders.add([_order('o1', OrderStatus.driverAssigned)]);
        await _settle(tester);
        expect([tracker.onDelivery, tracker.activeOrderIds], [true, {'o1'}], reason: '7: active delivery ($label case)');
        // 8: backgrounded — tracking isn't stopped by the lifecycle (iOS keeps it running with the location mode).
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        await _settle(tester);
        expect(tracker.isTracking, isTrue);
        clock = clock.add(const Duration(seconds: 11)); // past the 10 s write throttle
        geo.latest.add(_pos(17.0));
        await _settle(tester);
        expect(w.orders.last, 'o1@17.0');
        // 9: resumed — no second stream.
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
        await _settle(tester);
        expect(geo.openStreams, 1);
        // 10–12: the delivery ends for this Driver.
        orders.add([end].where((o) => o.status == OrderStatus.driverAssigned || o.status == OrderStatus.pickedUp).toList());
        await _settle(tester);
        expect([tracker.onDelivery, tracker.activeOrderIds], [false, <String>{}], reason: label);
        w.orders.clear();
        clock = clock.add(const Duration(seconds: 11));
        geo.latest.add(_pos(17.1));
        await _settle(tester);
        expect(w.orders, isEmpty, reason: 'no more writes to the order after $label');
        expect(geo.openStreams, 1, reason: '15: never more than one stream');
      }
      await tester.runAsync(tracker.stop);
    });

    testWidgets('13, 16: signing out stops tracking and closes the stream', (tester) async {
      final tracker = DriverLocationTracker(writeDriver: _Writes().writeDriver, writeOrder: _Writes().writeOrder);
      final orders = StreamController<List<Order>>.broadcast();
      addTearDown(orders.close);
      final wired = await _wire(tester, tracker: tracker, orders: orders.stream, driverId: null);
      wired.driver.state = 'd1';
      await _settle(tester);
      orders.add([_order('o1', OrderStatus.pickedUp)]);
      await _settle(tester);
      expect([tracker.isTracking, tracker.onDelivery], [true, true]);
      wired.driver.state = null; // signed out
      await _settle(tester);
      expect([tracker.isTracking, tracker.onDelivery, geo.openStreams], [false, false, 0]);
    });

    testWidgets('14: Customers, shops and Managers never start tracking', (tester) async {
      final tracker = DriverLocationTracker(writeDriver: _Writes().writeDriver, writeOrder: _Writes().writeOrder);
      await _wire(tester, tracker: tracker, orders: Stream.value([_order('o1', OrderStatus.pickedUp)]), driverId: null);
      await _settle(tester);
      expect([tracker.isTracking, geo.streams.length, geo.permissionRequests], [false, 0, 0]);
    });

    test('15: repeated starts, resumes and delivery flips keep one stream', () async {
      final t = DriverLocationTracker(writeDriver: _Writes().writeDriver, writeOrder: _Writes().writeOrder);
      await t.start('d1');
      await Future.wait([t.retryIfIdle(), t.retryIfIdle(), t.setOnDelivery(true)]);
      await t.setOnDelivery(false);
      await t.setOnDelivery(true);
      await t.retryIfIdle();
      expect(geo.openStreams, 1);
      await t.stop();
      expect(geo.openStreams, 0);
    });

    test('17: a write failure (network) never stops tracking', () async {
      final w = _Writes()..fail = Exception('unavailable');
      var clock = DateTime(2026, 11, 2, 12);
      final t = DriverLocationTracker(writeDriver: w.writeDriver, writeOrder: w.writeOrder, now: () => clock)..activeOrderIds = {'o1'};
      await t.start('d1');
      geo.latest.add(_pos(17.0));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(t.isTracking, isTrue);
      w.fail = null;
      // The tracker writes at most once per 10 s.
      clock = clock.add(const Duration(seconds: 11));
      geo.latest.add(_pos(17.2));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect([w.driver.last, w.orders.last], ['d1@17.2', 'o1@17.2'], reason: 'reporting resumes when the network is back');
      await t.stop();
    });

    testWidgets('19: if the server listener fails, no stale delivery keeps background tracking', (tester) async {
      final tracker = DriverLocationTracker(writeDriver: _Writes().writeDriver, writeOrder: _Writes().writeOrder);
      final orders = StreamController<List<Order>>.broadcast();
      addTearDown(orders.close);
      final wired = await _wire(tester, tracker: tracker, orders: orders.stream, driverId: null);
      wired.driver.state = 'd1';
      await _settle(tester);
      orders.add([_order('o1', OrderStatus.pickedUp)]);
      await _settle(tester);
      expect(tracker.onDelivery, isTrue);
      orders.addError(Exception('permission-denied'));
      await _settle(tester);
      expect([tracker.onDelivery, tracker.activeOrderIds], [false, <String>{}]);
      await tester.runAsync(tracker.stop);
    });
  });
}
