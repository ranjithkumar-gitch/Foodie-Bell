import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/providers/road_route_provider.dart';
import '../../../shared/widgets/driver_live_map.dart';

/// How close to a stop (the shop for pickup, the drop-off for delivery)
/// the Driver has to be before its "Arrived" button enables — what Swiggy/
/// Zomato do so a partner can't mark themselves arrived from across town.
/// 100 m rather than door-tight because phone GPS is itself often 10–30 m
/// off (more indoors or between tall buildings).
const kDriverArrivalRadiusMeters = 100.0;

/// The line above an "Arrived" button saying why it's locked or that it's
/// ready: how far the Driver still is from the stop, and that it unlocks
/// within [kDriverArrivalRadiusMeters].
class ArrivalHint extends StatelessWidget {
  const ArrivalHint({
    super.key,
    required this.arrived,
    required this.metersAway,
    required this.hasDriverPosition,
    required this.arrivedText,
    required this.awayText,
  });

  final bool arrived;
  final double? metersAway;
  final bool hasDriverPosition;
  final String arrivedText;
  final String awayText;

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    final radius = kDriverArrivalRadiusMeters.round();
    final String detail;
    if (arrived) {
      detail = arrivedText;
    } else if (!hasDriverPosition) {
      detail = '$awayText Turn on location (GPS) — "Arrived" unlocks within $radius m.';
    } else {
      final away = metersAway!;
      final label = away < 1000 ? '${away.round()} m' : '${(away / 1000).toStringAsFixed(1)} km';
      detail = '$awayText You\'re $label away — "Arrived" unlocks within $radius m.';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: (arrived ? palette.success : palette.warning).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            arrived ? Icons.where_to_vote_rounded : Icons.near_me_rounded,
            color: arrived ? palette.success : palette.warning,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              detail,
              style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w600, fontSize: 12.5),
            ),
          ),
        ],
      ),
    );
  }
}

/// The whole trip on one map for a delivery offer — where the Driver is
/// now, the pickup (vendor) and the drop-off — with the road route through
/// them when Google returned one (a dashed straight line otherwise), framed
/// so every known point is in view.
class TripPreviewMap extends StatefulWidget {
  const TripPreviewMap({
    super.key,
    required this.pickup,
    required this.pickupName,
    this.driver,
    this.drop,
    this.dropName = 'Drop-off',
    this.route,
  });

  final LatLng pickup;
  final String pickupName;
  final LatLng? driver;
  final LatLng? drop;
  final String dropName;

  /// Road route points, driver → pickup → drop, when known.
  final List<LatLng>? route;

  @override
  State<TripPreviewMap> createState() => _TripPreviewMapState();
}

class _TripPreviewMapState extends State<TripPreviewMap> {
  static const _dropColor = Color(0xFF2E7D32);

  GoogleMapController? _controller;
  BitmapDescriptor? _pickupIcon;
  BitmapDescriptor? _dropIcon;
  BitmapDescriptor? _driverIcon;
  Color? _driverIconColor;
  int _framedPoints = 0;

  List<LatLng> get _points => [?widget.driver, widget.pickup, ?widget.drop];

  @override
  void initState() {
    super.initState();
    buildMapBadgeIcon(Icons.storefront_rounded, Colors.deepOrange).then((icon) {
      if (mounted) setState(() => _pickupIcon = icon);
    });
    buildMapBadgeIcon(Icons.home_rounded, _dropColor).then((icon) {
      if (mounted) setState(() => _dropIcon = icon);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final color = context.colors.primary;
    if (color != _driverIconColor) {
      _driverIconColor = color;
      buildMapBadgeIcon(Icons.two_wheeler_rounded, color).then((icon) {
        if (mounted && _driverIconColor == color) setState(() => _driverIcon = icon);
      });
    }
  }

  @override
  void didUpdateWidget(TripPreviewMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Re-frame only when a point first becomes known (the driver's GPS fix
    // or a geocoded drop-off arriving late), not on every small move.
    if (_points.length != _framedPoints) _frame();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _frame() async {
    final controller = _controller;
    final points = _points;
    if (controller == null) return;
    _framedPoints = points.length;
    var south = points.first.latitude, north = south;
    var west = points.first.longitude, east = west;
    for (final p in points.skip(1)) {
      if (p.latitude < south) south = p.latitude;
      if (p.latitude > north) north = p.latitude;
      if (p.longitude < west) west = p.longitude;
      if (p.longitude > east) east = p.longitude;
    }
    try {
      if (Geolocator.distanceBetween(south, west, north, east) < 40) {
        await controller.animateCamera(CameraUpdate.newLatLngZoom(widget.pickup, 16));
        return;
      }
      await controller.animateCamera(
        CameraUpdate.newLatLngBounds(LatLngBounds(southwest: LatLng(south, west), northeast: LatLng(north, east)), 50),
      );
    } catch (e) {
      debugPrint('driver_route_map: framing the trip preview failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final route = widget.route;
    final driver = widget.driver;
    final drop = widget.drop;
    return GoogleMap(
      initialCameraPosition: CameraPosition(target: widget.pickup, zoom: 14),
      onMapCreated: (controller) {
        _controller = controller;
        // No size yet on the frame it's created — fitting bounds to a
        // zero-sized map throws on Android.
        Timer(const Duration(milliseconds: 300), () {
          if (mounted) _frame();
        });
      },
      markers: {
        Marker(
          markerId: const MarkerId('pickup'),
          position: widget.pickup,
          icon: _pickupIcon ?? BitmapDescriptor.defaultMarker,
          anchor: _pickupIcon == null ? const Offset(0.5, 1) : const Offset(0.5, 0.5),
          infoWindow: InfoWindow(title: widget.pickupName, snippet: 'Pickup'),
        ),
        if (drop != null)
          Marker(
            markerId: const MarkerId('drop'),
            position: drop,
            icon: _dropIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
            anchor: _dropIcon == null ? const Offset(0.5, 1) : const Offset(0.5, 0.5),
            infoWindow: InfoWindow(title: widget.dropName, snippet: 'Drop-off'),
          ),
        if (driver != null)
          Marker(
            markerId: const MarkerId('driver'),
            position: driver,
            icon: _driverIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
            anchor: _driverIcon == null ? const Offset(0.5, 1) : const Offset(0.5, 0.5),
            infoWindow: const InfoWindow(title: 'You'),
            zIndexInt: 1,
          ),
      },
      polylines: {
        if (route != null && route.length > 1)
          Polyline(
            polylineId: const PolylineId('trip-route'),
            points: route,
            color: context.colors.primary,
            width: 5,
            startCap: Cap.roundCap,
            endCap: Cap.roundCap,
            jointType: JointType.round,
          )
        else if (_points.length > 1)
          Polyline(
            polylineId: const PolylineId('trip-straight'),
            points: _points,
            color: context.colors.primary,
            width: 4,
            patterns: [PatternItem.dash(24), PatternItem.gap(12)],
          ),
      },
      // Sits inside the offer's scrolling page — claim drags so the map
      // pans/zooms instead of the page scrolling.
      gestureRecognizers: {Factory<OneSequenceGestureRecognizer>(() => EagerGestureRecognizer())},
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      mapToolbarEnabled: false,
      compassEnabled: false,
    );
  }
}

/// A real map centred on the Driver alone — what the navigation screens
/// show when the stop has no position at all (no pin, and its typed
/// address couldn't be geocoded), instead of the fake placeholder. The
/// camera follows the Driver as they move.
class DriverPositionMap extends StatefulWidget {
  const DriverPositionMap({super.key, required this.driver});
  final LatLng driver;

  @override
  State<DriverPositionMap> createState() => _DriverPositionMapState();
}

class _DriverPositionMapState extends State<DriverPositionMap> {
  GoogleMapController? _controller;
  BitmapDescriptor? _driverIcon;
  Color? _driverIconColor;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final color = context.colors.primary;
    if (color != _driverIconColor) {
      _driverIconColor = color;
      buildMapBadgeIcon(Icons.two_wheeler_rounded, color).then((icon) {
        if (mounted && _driverIconColor == color) setState(() => _driverIcon = icon);
      });
    }
  }

  @override
  void didUpdateWidget(DriverPositionMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.driver != widget.driver) {
      _controller?.animateCamera(CameraUpdate.newLatLng(widget.driver)).catchError((_) {});
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GoogleMap(
      initialCameraPosition: CameraPosition(target: widget.driver, zoom: 16),
      onMapCreated: (controller) => _controller = controller,
      markers: {
        Marker(
          markerId: const MarkerId('driver'),
          position: widget.driver,
          icon: _driverIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
          anchor: _driverIcon == null ? const Offset(0.5, 1) : const Offset(0.5, 0.5),
          infoWindow: const InfoWindow(title: 'You'),
        ),
      },
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      mapToolbarEnabled: false,
      compassEnabled: false,
    );
  }
}

/// Metres between [a] and [b] — null when either isn't known.
double? metersBetween(LatLng? a, LatLng? b) {
  if (a == null || b == null) return null;
  return Geolocator.distanceBetween(a.latitude, a.longitude, b.latitude, b.longitude);
}

/// Time and distance to the shop: Google's own figures for the road route
/// ([fromRoute]) when there is one, otherwise a rough guess worked out on
/// the device from the straight-line gap ([between]) — which knows nothing
/// about the actual roads, and is shown with a "~" to say so.
class TravelEstimate {
  const TravelEstimate({required this.meters, required this.minutes, this.approximate = true});

  factory TravelEstimate.fromRoute(RoadRoute route) {
    final minutes = (route.durationSeconds / 60).ceil();
    return TravelEstimate(meters: route.distanceMeters.toDouble(), minutes: minutes < 1 ? 1 : minutes, approximate: false);
  }

  // Roads are never straight: a typical in-town trip runs about 30% longer
  // than the crow-flies distance.
  static const _roadFactor = 1.3;
  // Average two-wheeler speed through town traffic.
  static const _kmPerHour = 25.0;

  final double meters;
  final int minutes;
  final bool approximate;

  factory TravelEstimate.between(LatLng from, LatLng to) {
    final meters = Geolocator.distanceBetween(from.latitude, from.longitude, to.latitude, to.longitude) * _roadFactor;
    final minutes = (meters / 1000 / _kmPerHour * 60).ceil();
    return TravelEstimate(meters: meters, minutes: minutes < 1 ? 1 : minutes);
  }

  String get distanceLabel => meters < 1000 ? '${meters.round()} m' : '${(meters / 1000).toStringAsFixed(1)} km';
}

/// The Driver's current stop ([destination] — the shop on pickup, the
/// drop-off on delivery) and the Driver (two-wheeler badge) on one Google
/// map with a line linking them, framed so both are in view. The Driver's
/// pin follows their position as it updates; the camera only frames the
/// pair once, so it doesn't fight a Driver who has panned or zoomed the
/// map themselves.
class DriverRouteMap extends StatefulWidget {
  const DriverRouteMap({
    super.key,
    required this.destination,
    required this.destinationName,
    required this.driver,
    this.destinationIcon = Icons.storefront_rounded,
    this.destinationColor = Colors.deepOrange,
    this.destinationSnippet = 'Pickup',
    this.route,
  });

  final LatLng destination;
  final String destinationName;
  final IconData destinationIcon;
  final Color destinationColor;
  final String destinationSnippet;
  final LatLng? driver;

  /// The road route to draw, when Google has returned one.
  final List<LatLng>? route;

  @override
  State<DriverRouteMap> createState() => _DriverRouteMapState();
}

class _DriverRouteMapState extends State<DriverRouteMap> {
  GoogleMapController? _controller;
  bool _framed = false;
  BitmapDescriptor? _vendorIcon;
  BitmapDescriptor? _driverIcon;
  Color? _driverIconColor;

  @override
  void initState() {
    super.initState();
    buildMapBadgeIcon(widget.destinationIcon, widget.destinationColor).then((icon) {
      if (mounted) setState(() => _vendorIcon = icon);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final color = context.colors.primary;
    if (color != _driverIconColor) {
      _driverIconColor = color;
      buildMapBadgeIcon(Icons.two_wheeler_rounded, color).then((icon) {
        if (mounted && _driverIconColor == color) setState(() => _driverIcon = icon);
      });
    }
  }

  @override
  void didUpdateWidget(DriverRouteMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The Driver's first position can arrive after the map is already up.
    if (!_framed) _frame();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _frame() async {
    final controller = _controller;
    final driver = widget.driver;
    if (controller == null || driver == null) return;
    _framed = true;
    final vendor = widget.destination;
    try {
      final apart = Geolocator.distanceBetween(driver.latitude, driver.longitude, vendor.latitude, vendor.longitude);
      if (apart < 30) {
        // Already at the shop — bounds this tight would zoom in absurdly.
        await controller.animateCamera(CameraUpdate.newLatLngZoom(vendor, 17));
        return;
      }
      final bounds = LatLngBounds(
        southwest: LatLng(
          driver.latitude < vendor.latitude ? driver.latitude : vendor.latitude,
          driver.longitude < vendor.longitude ? driver.longitude : vendor.longitude,
        ),
        northeast: LatLng(
          driver.latitude > vendor.latitude ? driver.latitude : vendor.latitude,
          driver.longitude > vendor.longitude ? driver.longitude : vendor.longitude,
        ),
      );
      await controller.animateCamera(CameraUpdate.newLatLngBounds(bounds, 70));
    } catch (e) {
      debugPrint('driver_route_map: framing the map failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final driver = widget.driver;
    final route = widget.route;
    return GoogleMap(
      initialCameraPosition: CameraPosition(target: widget.destination, zoom: 15),
      onMapCreated: (controller) {
        _controller = controller;
        // The map has no size yet on the frame it's created, and fitting
        // bounds to a zero-sized map throws on Android.
        Timer(const Duration(milliseconds: 300), () {
          if (mounted) _frame();
        });
      },
      markers: {
        Marker(
          markerId: const MarkerId('destination'),
          position: widget.destination,
          icon: _vendorIcon ?? BitmapDescriptor.defaultMarker,
          anchor: _vendorIcon == null ? const Offset(0.5, 1) : const Offset(0.5, 0.5),
          infoWindow: InfoWindow(title: widget.destinationName, snippet: widget.destinationSnippet),
        ),
        if (driver != null)
          Marker(
            markerId: const MarkerId('driver'),
            position: driver,
            icon: _driverIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
            anchor: _driverIcon == null ? const Offset(0.5, 1) : const Offset(0.5, 0.5),
            infoWindow: const InfoWindow(title: 'You'),
          ),
      },
      polylines: {
        if (route != null && route.length > 1)
          Polyline(
            polylineId: const PolylineId('road-route'),
            points: route,
            color: context.colors.primary,
            width: 6,
            startCap: Cap.roundCap,
            endCap: Cap.roundCap,
            jointType: JointType.round,
          )
        // No road route (still loading, or Google refused the lookup): a
        // straight link between the two instead, dashed so it doesn't
        // read as turn-by-turn directions.
        else if (driver != null)
          Polyline(
            polylineId: const PolylineId('driver-to-destination'),
            points: [driver, widget.destination],
            color: context.colors.primary,
            width: 5,
            patterns: [PatternItem.dash(24), PatternItem.gap(12)],
          ),
      },
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      mapToolbarEnabled: false,
      compassEnabled: false,
    );
  }
}
