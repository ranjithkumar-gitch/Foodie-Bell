import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/order.dart';
import '../../data/providers/device_position_provider.dart';
import '../../data/providers/firestore_drivers_provider.dart';
import '../../data/providers/firestore_orders_provider.dart';
import '../../data/providers/firestore_vendors_provider.dart';
import '../../data/providers/geocode_provider.dart';
import '../../data/providers/order_drop_off.dart';
import '../../data/providers/road_route_provider.dart';
import '../../l10n/app_localizations_context.dart';
import 'mock_map_view.dart';

/// The User's live order tracking map: a real Google map of the shop, the
/// drop-off (the delivery address's pinned position, snapshotted on the
/// order) and the assigned Driver's reported position
/// (`driverLocationProvider`) — the Driver's marker gliding from one GPS
/// update to the next instead of jumping, with the road route from them to
/// the drop-off (through the shop until the order is picked up).
///
/// Before a Driver accepts, it shows just the shop and the drop-off. With
/// none of the three positions known it falls back to the same
/// [MockMapView] placeholder this slot always showed, at the same size, so
/// the surrounding card doesn't change shape either way.
class DriverLiveMap extends ConsumerStatefulWidget {
  const DriverLiveMap({
    super.key,
    required this.order,
    this.height = 200,
    this.borderRadius,
    this.interactive = true,
    this.viewerIsCustomer = true,
    this.driverPosition,
  });

  /// The Driver's live position off their own phone's GPS — passed in on
  /// the Driver's phone (Driver Home) so the line starts where they really
  /// are, exactly like the navigate screens' map, instead of from the
  /// Firestore copy, which can be minutes behind. Null on the customer's
  /// phone, which only has the Firestore copy.
  final LatLng? driverPosition;

  /// True on the User's own phone, where "this phone's position" is a fair
  /// last-resort drop-off pin for an order without one. False on the
  /// Driver's phone (Driver Home's delivery cards) — there it's the Driver's
  /// own position, which would wrongly pin the customer's home on them.
  final bool viewerIsCustomer;

  final Order order;
  final double height;
  final BorderRadius? borderRadius;

  /// False where the map sits inside a tappable card (Home's active-order
  /// card) — touches pass through to the card instead of panning the map.
  final bool interactive;

  @override
  ConsumerState<DriverLiveMap> createState() => _DriverLiveMapState();
}

class _DriverLiveMapState extends ConsumerState<DriverLiveMap> with SingleTickerProviderStateMixin {
  static const _driverMarkerId = MarkerId('driver');
  static const _vendorColor = Colors.deepOrange;
  static const _homeColor = Color(0xFF2E7D32);

  // Roughly matches how often a moving Driver reports (every 10 m), so one
  // glide finishes about when the next position arrives.
  late final AnimationController _glide =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))..addListener(_onGlideTick);

  GoogleMapController? _mapController;
  BitmapDescriptor? _driverIcon;
  BitmapDescriptor? _driverArrowIcon;
  BitmapDescriptor? _vendorIcon;
  BitmapDescriptor? _homeIcon;
  Color? _driverIconColor;

  /// Compass bearing (0 = north) of the Driver's last move, worked out from
  /// consecutive reported positions — the marker turns into a direction
  /// arrow pointing this way, like the partner icon on Swiggy/Zomato's map.
  /// Null until they've moved far enough to tell.
  double? _heading;

  /// Where the marker is drawn right now — mid-glide this sits between
  /// [_glideFrom] and [_glideTo].
  LatLng? _shown;
  LatLng? _glideFrom;
  LatLng? _glideTo;

  /// The last road route Google returned for [_routeDestination] — kept on
  /// screen while the next one loads as the Driver moves, so the line
  /// doesn't blink away and back every ~100 m.
  RoadRoute? _lastRoute;
  LatLng? _routeDestination;

  /// The points the camera keeps in view: the Driver and wherever they're
  /// heading, or the shop and the drop-off before a Driver is on the way.
  List<LatLng> _focus = const [];

  @override
  void initState() {
    super.initState();
    buildMapBadgeIcon(Icons.storefront_rounded, _vendorColor).then((icon) {
      if (mounted) setState(() => _vendorIcon = icon);
    });
    buildMapBadgeIcon(Icons.home_rounded, _homeColor).then((icon) {
      if (mounted) setState(() => _homeIcon = icon);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final color = context.colors.primary;
    if (color != _driverIconColor) {
      _driverIconColor = color;
      _buildDriverIcon(color).then((icon) {
        if (mounted && _driverIconColor == color) setState(() => _driverIcon = icon);
      });
      buildMapBadgeIcon(Icons.navigation_rounded, color).then((icon) {
        if (mounted && _driverIconColor == color) setState(() => _driverArrowIcon = icon);
      });
    }
  }

  @override
  void didUpdateWidget(DriverLiveMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    final position = widget.driverPosition;
    if (position != null && position != oldWidget.driverPosition) _moveTo(position);
  }

  @override
  void dispose() {
    _glide.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  void _onGlideTick() {
    final from = _glideFrom;
    final to = _glideTo;
    if (from == null || to == null) return;
    final t = Curves.easeInOut.transform(_glide.value);
    setState(() {
      _shown = LatLng(
        from.latitude + (to.latitude - from.latitude) * t,
        from.longitude + (to.longitude - from.longitude) * t,
      );
    });
  }

  void _moveTo(LatLng target) {
    final current = _shown;
    if (current == null) {
      setState(() => _shown = target);
      return;
    }
    if (current == target) return;
    // Only a real move says which way they're facing — a few metres is
    // just GPS jitter, and would spin the arrow around on the spot.
    if (Geolocator.distanceBetween(current.latitude, current.longitude, target.latitude, target.longitude) > 5) {
      final bearing = Geolocator.bearingBetween(current.latitude, current.longitude, target.latitude, target.longitude);
      _heading = (bearing + 360) % 360;
    }
    _glideFrom = current;
    _glideTo = target;
    _glide.forward(from: 0);
  }

  /// Moves the camera so every point in [_focus] is in view.
  Future<void> _frame() async {
    final controller = _mapController;
    final points = _focus;
    if (controller == null || points.isEmpty) return;
    var south = points.first.latitude;
    var north = south;
    var west = points.first.longitude;
    var east = west;
    for (final point in points.skip(1)) {
      if (point.latitude < south) south = point.latitude;
      if (point.latitude > north) north = point.latitude;
      if (point.longitude < west) west = point.longitude;
      if (point.longitude > east) east = point.longitude;
    }
    try {
      if (Geolocator.distanceBetween(south, west, north, east) < 30) {
        // One point, or two almost on top of each other — bounds this
        // tight would zoom in absurdly.
        await controller.animateCamera(CameraUpdate.newLatLngZoom(LatLng((south + north) / 2, (west + east) / 2), 16));
        return;
      }
      // Scaled to the map's size — a fixed 44 px on the 150 px Home card
      // left barely 60 px for the route itself.
      final padding = (widget.height * 0.14).clamp(20.0, 44.0);
      await controller.animateCamera(
        CameraUpdate.newLatLngBounds(LatLngBounds(southwest: LatLng(south, west), northeast: LatLng(north, east)), padding),
      );
    } catch (e) {
      debugPrint('driver_live_map: framing the map failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final pickedUp = order.status == OrderStatus.pickedUp;
    final hasDriverOnTheWay = order.status == OrderStatus.driverAssigned || pickedUp;
    final driverId = hasDriverOnTheWay ? order.driverId : null;

    final vendorAccount = ref.watch(liveVendorAccountProvider(order.vendorId));
    final vendorAddress = (vendorAccount?.address ?? '').trim();
    final vendor = vendorAccount?.latitude != null && vendorAccount?.longitude != null
        ? LatLng(vendorAccount!.latitude!, vendorAccount.longitude!)
        : vendorAddress.isEmpty
        ? null
        : ref.watch(geocodedAddressProvider(vendorAddress)).valueOrNull;
    // The drop-off: read straight off the saved address the order was
    // placed to (its lat/long, else its street address looked up on the
    // map — `order_drop_off.dart`), else — on the customer's own phone only
    // — where that phone is right now, so there's always a pin for the
    // route to end at.
    var home = watchOrderDropOff(ref, order).position;
    if (widget.viewerIsCustomer) home ??= ref.watch(devicePositionProvider).valueOrNull;

    LatLng? reported;
    if (driverId != null && widget.driverPosition != null) {
      reported = widget.driverPosition;
    } else if (driverId != null && widget.viewerIsCustomer) {
      // Customers follow their Driver through the order's tracking document
      // (`order_tracking`) — they can't read any Driver's record.
      LatLng? positionOf(DriverPosition? p) => p == null ? null : LatLng(p.latitude, p.longitude);
      reported = positionOf(ref.watch(driverPositionProvider(order.id)).valueOrNull);
      ref.listen(driverPositionProvider(order.id), (previous, next) {
        final moved = positionOf(next.valueOrNull);
        if (moved != null) _moveTo(moved);
      });
    } else if (driverId != null) {
      final location = ref.watch(driverLocationProvider(driverId)).valueOrNull;
      if (location != null) reported = LatLng(location.latitude, location.longitude);
      ref.listen(driverLocationProvider(driverId), (previous, next) {
        final moved = next.valueOrNull;
        if (moved != null) _moveTo(LatLng(moved.latitude, moved.longitude));
      });
    }
    if (reported == null) _shown = null;
    final shown = reported == null ? null : (_shown ??= reported);

    // Only the leg the Driver is on right now: to the shop until the order
    // is picked up, then to the customer — for the customer and the Driver
    // alike, and the same line the Driver's navigate screens
    // (`driver_navigate_vendor_screen.dart` / `..._customer_screen.dart`)
    // draw. Drawing the whole trip through the shop at once made the line
    // run on past the shop before the Driver had even got there.
    final destination = reported == null ? null : (pickedUp ? home : vendor);
    const LatLng? via = null;
    RoadRoute? route;
    if (reported != null && destination != null) {
      if (_routeDestination != destination) {
        _routeDestination = destination;
        _lastRoute = null;
      }
      final fetched = ref
          .watch(roadRouteProvider(roadRouteRequest(from: reported, to: destination, via: via)))
          .valueOrNull;
      if (fetched != null) _lastRoute = fetched;
      route = _lastRoute;
    }

    // Live "Arriving in X min · Y km" — Google's own figures for the road
    // route (through the shop until pickup) when there is one, otherwise a
    // rough guess from the straight-line gap (~30% longer by road, ~25 km/h
    // on a two-wheeler through town).
    ({int minutes, double km})? eta;
    if (route != null) {
      final minutes = (route.durationSeconds / 60).ceil();
      eta = (minutes: minutes < 1 ? 1 : minutes, km: route.distanceMeters / 1000);
    } else if (shown != null && destination != null) {
      var meters = 0.0;
      var from = shown;
      for (final stop in [?via, destination]) {
        meters += Geolocator.distanceBetween(from.latitude, from.longitude, stop.latitude, stop.longitude) * 1.3;
        from = stop;
      }
      final minutes = (meters / 1000 / 25 * 60).ceil();
      eta = (minutes: minutes < 1 ? 1 : minutes, km: meters / 1000);
    }

    // The road line as drawn: starting exactly at the Driver's marker, with
    // the stretch they've already covered dropped. Google's route starts at
    // the lookup origin, which is snapped to a ~100 m grid
    // (`roadRouteRequest`), so drawn as-is it began up to ~100 m away from
    // the marker and kept the road behind them on screen.
    final routeLine = route != null && route.points.length > 1 && shown != null
        ? _lineFromDriver(shown, route.points)
        : null;

    // Everything the camera keeps in view — the whole road route too, not
    // just its ends, so a route that bends away isn't cut off at the edge.
    // Google's own points, not [routeLine]: that one changes on every
    // frame of the marker's glide, and would re-frame the camera nonstop.
    final focus = reported != null
        ? [reported, ?via, ?destination, ...?route?.points]
        : [?vendor, ?home];
    if (focus.isEmpty) {
      _focus = const [];
      return MockMapView(height: widget.height, showRoute: true, borderRadius: widget.borderRadius);
    }
    if (!listEquals(focus, _focus)) {
      _focus = focus;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _frame();
      });
    }

    final map = SizedBox(
      height: widget.height,
      width: double.infinity,
      child: IgnorePointer(
        ignoring: !widget.interactive,
        child: GoogleMap(
          initialCameraPosition: CameraPosition(target: focus.first, zoom: 15),
          onMapCreated: (controller) {
            _mapController = controller;
            // The map has no size yet on the frame it's created, and
            // fitting bounds to a zero-sized map throws on Android.
            Timer(const Duration(milliseconds: 300), () {
              if (mounted) _frame();
            });
          },
          markers: {
            // Once the order is picked up the shop is behind the Driver.
            if (vendor != null && !pickedUp)
              Marker(
                markerId: const MarkerId('vendor'),
                position: vendor,
                icon: _vendorIcon ?? BitmapDescriptor.defaultMarker,
                anchor: _vendorIcon == null ? const Offset(0.5, 1) : const Offset(0.5, 0.5),
                infoWindow: InfoWindow(title: order.vendorName),
              ),
            if (home != null)
              Marker(
                markerId: const MarkerId('home'),
                position: home,
                icon: _homeIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
                anchor: _homeIcon == null ? const Offset(0.5, 1) : const Offset(0.5, 0.5),
                infoWindow: InfoWindow(title: order.deliveryAddressLabel),
              ),
            if (shown != null)
              // Once we know which way they're heading, a direction arrow
              // laid flat on the map and turned to face it; the two-wheeler
              // badge until then.
              _heading != null && _driverArrowIcon != null
                  ? Marker(
                      markerId: _driverMarkerId,
                      position: shown,
                      icon: _driverArrowIcon!,
                      anchor: const Offset(0.5, 0.5),
                      rotation: _heading!,
                      flat: true,
                      zIndexInt: 1,
                    )
                  : Marker(
                      markerId: _driverMarkerId,
                      position: shown,
                      icon: _driverIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
                      anchor: _driverIcon == null ? const Offset(0.5, 1) : const Offset(0.5, 0.5),
                      zIndexInt: 1,
                    ),
          },
          polylines: {
            if (routeLine != null)
              Polyline(
                polylineId: const PolylineId('road-route'),
                points: routeLine,
                color: context.colors.primary,
                width: 5,
                startCap: Cap.roundCap,
                endCap: Cap.roundCap,
                jointType: JointType.round,
              )
            // No road route (still loading, or Google refused the lookup):
            // a straight link instead, dashed so it doesn't read as the
            // actual road the Driver is taking.
            else if (shown != null && destination != null)
              Polyline(
                polylineId: const PolylineId('driver-to-destination'),
                points: [shown, ?via, destination],
                color: context.colors.primary,
                width: 4,
                patterns: [PatternItem.dash(24), PatternItem.gap(12)],
              ),
          },
          // Inside a scrolling page, so the map has to claim drags itself
          // or the page would scroll instead of the map panning.
          gestureRecognizers: {
            if (widget.interactive) Factory<OneSequenceGestureRecognizer>(() => EagerGestureRecognizer()),
          },
          myLocationButtonEnabled: false,
          zoomControlsEnabled: false,
          mapToolbarEnabled: false,
          compassEnabled: false,
        ),
      ),
    );

    final overlaid = Stack(
      children: [
        map,
        // Customer-facing only — on the Driver's own phone (Driver Home's
        // delivery cards) an ETA to themselves means nothing.
        if (widget.viewerIsCustomer && eta != null)
          Positioned(
            left: 10,
            top: 10,
            right: 10,
            child: IgnorePointer(
              child: Align(
                alignment: Alignment.topLeft,
                child: _MapChip(
                  icon: Icons.schedule_rounded,
                  // Before pickup the line (and so the time) only runs to
                  // the shop, so it says that instead of "Arriving in".
                  label:
                      '${pickedUp ? context.l10n.trackArrivingIn(eta.minutes) : context.l10n.trackReachingShopIn(eta.minutes)} · ${context.l10n.trackDistanceKm(eta.km < 10 ? eta.km.toStringAsFixed(1) : eta.km.toStringAsFixed(0))}',
                  color: context.colors.primary,
                ),
              ),
            ),
          ),
      ],
    );

    if (widget.borderRadius == null) return overlaid;
    return ClipRRect(borderRadius: widget.borderRadius!, child: overlaid);
  }
}

/// [route] from the point on it nearest [driver] onwards, with [driver]
/// itself as the first point — so the line starts at the marker and only
/// shows the road still ahead. Only looks a short way along the route for
/// that nearest point: the Driver is near its start (the lookup is redone
/// every ~100 m), and a route that doubles back past the same spot later
/// mustn't be cut there.
List<LatLng> _lineFromDriver(LatLng driver, List<LatLng> route) {
  final searchEnd = route.length < 40 ? route.length : 40;
  var nearest = 0;
  var nearestMeters = double.infinity;
  for (var i = 0; i < searchEnd; i++) {
    final meters = Geolocator.distanceBetween(driver.latitude, driver.longitude, route[i].latitude, route[i].longitude);
    if (meters < nearestMeters) {
      nearestMeters = meters;
      nearest = i;
    }
  }
  return [driver, ...route.skip(nearest + 1)];
}

/// A small pill floating over the top of the tracking map — the live ETA,
/// or the "location updated X min ago" warning.
class _MapChip extends StatelessWidget {
  const _MapChip({required this.icon, required this.label, required this.color});
  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 2))],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w800, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

/// The delivery-partner badge used as the map marker — the same
/// `two_wheeler_rounded` glyph on the brand colour that the order card's
/// own driver avatar uses.
Future<BitmapDescriptor> _buildDriverIcon(Color color) => buildMapBadgeIcon(Icons.two_wheeler_rounded, color);

/// A round map marker: [icon] in white on a [color] disc with a white rim —
/// rendered to a bitmap since map markers can't be widgets. Anchor it at
/// its centre (`Offset(0.5, 0.5)`).
Future<BitmapDescriptor> buildMapBadgeIcon(IconData icon, Color color) async {
  const size = 96.0;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  const center = Offset(size / 2, size / 2);
  canvas.drawCircle(center, size / 2, Paint()..color = Colors.white);
  canvas.drawCircle(center, size / 2 - 6, Paint()..color = color);
  final glyph = TextPainter(
    textDirection: TextDirection.ltr,
    text: TextSpan(
      text: String.fromCharCode(icon.codePoint),
      style: TextStyle(fontFamily: icon.fontFamily, package: icon.fontPackage, fontSize: 52, color: Colors.white),
    ),
  )..layout();
  glyph.paint(canvas, Offset((size - glyph.width) / 2, (size - glyph.height) / 2));
  final image = await recorder.endRecording().toImage(size.toInt(), size.toInt());
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  return BitmapDescriptor.bytes(bytes!.buffer.asUint8List(), width: 40, height: 40);
}
