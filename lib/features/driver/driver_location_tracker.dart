import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../core/session/session_controller.dart';
import '../../data/models/account.dart';
import '../../data/models/order.dart';
import '../../data/providers/firestore_drivers_provider.dart';
import '../../data/providers/firestore_orders_provider.dart';

/// Reports the signed-in Driver's GPS position to their own Firestore doc
/// (`updateDriverLocation`) — once as soon as a Driver session starts (a
/// login, a fresh registration, or a session restored on cold start), then
/// again every time they move, which is what the User's order tracking map
/// (`driver_live_map.dart`) follows.
///
/// While the Driver has a delivery in progress ([setOnDelivery]) it keeps
/// reporting with the app in the background too — an Android location
/// foreground service (ongoing "sharing your location" notification) / iOS
/// background location updates — since that's exactly when they switch to
/// Google Maps for turn-by-turn and the customer is watching the map. With
/// no delivery in progress it only reports while the app is open, so an
/// idle Driver isn't left with a permanent notification.
class DriverLocationTracker {
  StreamSubscription<Position>? _subscription;

  /// Whether the current stream was started in background mode — see
  /// [setOnDelivery].
  bool _onDelivery = false;

  /// The stream only fires after a 10 m move, so a Driver standing still
  /// (waiting at the vendor, at a signal) would otherwise stop writing and
  /// the customer's map would wrongly flag their location as stale. This
  /// re-sends the last known position every [_heartbeatInterval] while the
  /// stream is alive, refreshing `locationUpdatedAt` — so "updated X min
  /// ago" only ever shows when the phone has genuinely stopped reporting.
  Timer? _heartbeat;
  Position? _lastPosition;
  DateTime? _lastReportedAt;
  // Well under the customer map's 2-minute "stale" threshold, so a
  // standing-still Driver never trips it (worst case ~1 min between writes).
  static const _heartbeatInterval = Duration(seconds: 30);

  /// The Driver currently signed in — kept even while nothing is being
  /// reported (GPS off, permission denied) so [retryIfIdle] knows who to
  /// start reporting for once that's sorted out.
  String? _driverId;
  bool _starting = false;

  /// Bumped on every [start]/[stop] so a slow permission prompt or first
  /// GPS fix from a previous session can't start reporting under the next
  /// one.
  int _generation = 0;

  Future<void> start(String driverId) async {
    await stop();
    _driverId = driverId;
    await _begin(driverId, prompt: true);
  }

  /// Called whenever the app comes back to the foreground: a Driver whose
  /// GPS was off or who had denied the permission at login starts reporting
  /// as soon as they've fixed it in Settings, without having to sign in
  /// again. Never re-shows the permission prompt itself.
  Future<void> retryIfIdle() async {
    final driverId = _driverId;
    if (driverId == null || _subscription != null || _starting) return;
    await _begin(driverId, prompt: false);
  }

  /// Switches background reporting on while the Driver has a delivery in
  /// progress, off once they don't — restarting the running position
  /// stream with the matching settings, since a stream's background mode
  /// is fixed when it starts.
  Future<void> setOnDelivery(bool onDelivery) async {
    if (onDelivery == _onDelivery) return;
    _onDelivery = onDelivery;
    final driverId = _driverId;
    if (driverId == null || _starting) return;
    await _subscription?.cancel();
    _subscription = null;
    await _begin(driverId, prompt: false);
  }

  /// [_onDelivery] decides whether reporting survives the app going to
  /// the background.
  LocationSettings _settings() {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return AndroidSettings(
        accuracy: LocationAccuracy.high,
        // 10 m keeps the marker moving smoothly on the User's map without
        // a Firestore write for every GPS jitter while standing still.
        distanceFilter: 10,
        intervalDuration: const Duration(seconds: 4),
        foregroundNotificationConfig: _onDelivery
            ? const ForegroundNotificationConfig(
                notificationTitle: "You're on a delivery",
                notificationText: 'Quicky is sharing your location so the customer can track their order.',
                notificationChannelName: 'Delivery location',
                enableWakeLock: true,
                setOngoing: true,
              )
            : null,
      );
    }
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return AppleSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
        activityType: ActivityType.automotiveNavigation,
        pauseLocationUpdatesAutomatically: false,
        allowBackgroundLocationUpdates: _onDelivery,
        showBackgroundLocationIndicator: _onDelivery,
      );
    }
    return const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 10);
  }

  Future<void> _begin(String driverId, {required bool prompt}) async {
    final generation = _generation;
    _starting = true;
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        debugPrint('driver_location_tracker: location services are off, not reporting');
        return;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied && prompt) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        debugPrint('driver_location_tracker: location permission is $permission, not reporting');
        return;
      }
      if (generation != _generation) return;

      // The device's cached fix goes up straight away, so the Driver's doc
      // has a position from the moment they sign in rather than only once
      // a fresh GPS fix arrives (which can take a while indoors, or never
      // come at all).
      try {
        final lastKnown = await Geolocator.getLastKnownPosition();
        if (generation != _generation) return;
        if (lastKnown != null) _report(driverId, lastKnown);
      } catch (e) {
        debugPrint('driver_location_tracker: no last known position: $e');
      }

      // The stream delivers the current position first, then every move.
      _subscription = Geolocator.getPositionStream(locationSettings: _settings()).listen(
        (position) => _report(driverId, position),
        onError: (Object e, StackTrace st) {
          debugPrint('driver_location_tracker: position stream failed: $e\n$st');
          // E.g. GPS switched off mid-session — drop the dead subscription
          // so [retryIfIdle] can start a new one.
          if (generation != _generation) return;
          _subscription?.cancel();
          _subscription = null;
        },
      );
    } catch (e, st) {
      debugPrint('driver_location_tracker: start($driverId) failed: $e\n$st');
    } finally {
      if (generation == _generation) _starting = false;
    }
  }

  Future<void> stop() async {
    _generation++;
    _driverId = null;
    _starting = false;
    _onDelivery = false;
    _heartbeat?.cancel();
    _heartbeat = null;
    _lastPosition = null;
    await _subscription?.cancel();
    _subscription = null;
  }

  Future<void> _report(String driverId, Position position) async {
    _lastPosition = position;
    _lastReportedAt = DateTime.now();
    _heartbeat ??= Timer.periodic(_heartbeatInterval, (_) {
      final id = _driverId;
      final last = _lastPosition;
      final reportedAt = _lastReportedAt;
      // Only while the position stream is still alive — if GPS died, the
      // location really is going stale and the customer should see that.
      if (id == null || last == null || _subscription == null) return;
      if (reportedAt != null && DateTime.now().difference(reportedAt) < _heartbeatInterval - const Duration(seconds: 5)) {
        return;
      }
      _report(id, last);
    });
    try {
      await updateDriverLocation(driverId, latitude: position.latitude, longitude: position.longitude);
    } catch (e, st) {
      debugPrint('driver_location_tracker: update($driverId) failed: $e\n$st');
    }
  }
}

final driverLocationTrackerProvider = Provider<DriverLocationTracker>((ref) {
  final tracker = DriverLocationTracker();
  final lifecycle = AppLifecycleListener(onResume: tracker.retryIfIdle);
  ref.onDispose(lifecycle.dispose);
  ref.onDispose(tracker.stop);
  return tracker;
});

/// The Driver's own position read straight off this phone's GPS, live — for
/// a Driver-side map (`driver_navigate_vendor_screen.dart`) that should
/// show where they are even when the Firestore copy [DriverLocationTracker]
/// writes is missing or behind. Null when location is off or not allowed.
/// Only listens while a screen is watching it.
final driverDevicePositionProvider = StreamProvider.autoDispose<Position?>((ref) async* {
  if (!await Geolocator.isLocationServiceEnabled()) {
    yield null;
    return;
  }
  var permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
  }
  if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
    yield null;
    return;
  }
  try {
    final lastKnown = await Geolocator.getLastKnownPosition();
    if (lastKnown != null) yield lastKnown;
  } catch (e) {
    debugPrint('driver_location_tracker: no last known position: $e');
  }
  yield* Geolocator.getPositionStream(
    locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 10),
  );
});

/// The id of the Driver whose position should be reported right now — set
/// from login/registration onward (including while still under review, so
/// a just-registered Driver's location is on record too), null for every
/// other role and once signed out.
final _trackedDriverIdProvider = Provider<String?>((ref) {
  final session = ref.watch(sessionControllerProvider);
  final account = session.account;
  if (account == null || account.role != AppRole.driver || account.id.isEmpty) return null;
  final tracked = session.stage == AuthStage.active || session.stage == AuthStage.pendingApproval;
  return tracked ? account.id : null;
});

/// True while the signed-in Driver has a delivery in progress (assigned or
/// picked up) — what switches [DriverLocationTracker] into background mode.
final _trackedDriverOnDeliveryProvider = Provider<bool>((ref) {
  final driverId = ref.watch(_trackedDriverIdProvider);
  if (driverId == null) return false;
  final orders = ref.watch(firestoreOrdersProvider).valueOrNull ?? const [];
  return orders.any(
    (o) => o.driverId == driverId && (o.status == OrderStatus.driverAssigned || o.status == OrderStatus.pickedUp),
  );
});

/// Starts/stops [DriverLocationTracker] as a Driver session begins and ends,
/// and flips its background mode as deliveries start and finish — called
/// from `QuickyApp.build`, same pattern as `fcm_topics.dart`'s `listenFor...`
/// helpers.
void listenForDriverLocationTracking(WidgetRef ref) {
  ref.listen<String?>(_trackedDriverIdProvider, (previous, next) {
    if (previous == next) return;
    final tracker = ref.read(driverLocationTrackerProvider);
    if (next == null) {
      tracker.stop();
    } else {
      tracker.start(next).then((_) => tracker.setOnDelivery(ref.read(_trackedDriverOnDeliveryProvider)));
    }
  });
  ref.listen<bool>(_trackedDriverOnDeliveryProvider, (previous, next) {
    if (previous == next) return;
    ref.read(driverLocationTrackerProvider).setOnDelivery(next);
  });
}
