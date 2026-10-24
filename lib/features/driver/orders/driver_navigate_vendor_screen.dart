import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/providers/firestore_drivers_provider.dart';
import '../../../data/providers/firestore_orders_provider.dart';
import '../../../data/providers/firestore_vendors_provider.dart';
import '../../../data/providers/geocode_provider.dart';
import '../../../data/providers/road_route_provider.dart';
import '../../../shared/error_reporting.dart';
import '../../../shared/widgets/mock_map_view.dart';
import '../driver_location_tracker.dart';
import '../driver_session.dart';
import 'driver_route_map.dart';

/// Active Delivery — Navigate to Vendor (spec §6 item 8): a real map of the
/// pickup point (the shop location the Vendor saved on
/// `vendor_profile_edit_screen.dart`) and the Driver's own live position
/// (`driver_location_tracker.dart`), a "Navigate" button that hands the
/// actual turn-by-turn route off to Google Maps, a rough time-to-reach
/// beside it, and an "Arrived at Vendor" affordance that hands off to
/// Pickup Confirmation. Purely a navigation step — it doesn't touch order
/// status itself.
class DriverNavigateVendorScreen extends ConsumerStatefulWidget {
  const DriverNavigateVendorScreen({super.key, required this.orderId});

  final String orderId;

  @override
  ConsumerState<DriverNavigateVendorScreen> createState() => _DriverNavigateVendorScreenState();
}

class _DriverNavigateVendorScreenState extends ConsumerState<DriverNavigateVendorScreen> {
  /// The last road route Google returned — kept on screen while the next
  /// one loads as the Driver moves, so the line doesn't blink away and
  /// back every ~100 m.
  RoadRoute? _lastRoute;

  /// Opens Google Maps with the route from wherever the Driver is right now
  /// to the shop — by coordinates when the Vendor has pinned a location,
  /// otherwise by searching their typed address.
  Future<void> _openGoogleMaps(BuildContext context, {LatLng? vendor, String? address}) async {
    final uri = Uri.https('www.google.com', '/maps/dir/', {
      'api': '1',
      'destination': vendor != null ? '${vendor.latitude},${vendor.longitude}' : address!,
      'travelmode': 'driving',
    });
    try {
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open Google Maps.')));
      }
    } catch (e, st) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e, action: 'Opening Google Maps', stackTrace: st))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    final order = ref.watch(orderByIdProvider(widget.orderId)).valueOrNull;
    if (order == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final vendorAccount = ref.watch(liveVendorAccountProvider(order.vendorId));
    final vendorAddress = (vendorAccount?.address ?? '').trim();
    final pinnedVendor = vendorAccount?.latitude != null && vendorAccount?.longitude != null
        ? LatLng(vendorAccount!.latitude!, vendorAccount.longitude!)
        : null;
    // No pinned shop location — look the typed address up instead, so the
    // map still has a real pickup point to draw. Less exact than a pin, so
    // "Arrived" isn't locked against it (see [atVendor]).
    final geocodedVendor = pinnedVendor != null || vendorAddress.isEmpty
        ? null
        : ref.watch(geocodedAddressProvider(vendorAddress)).valueOrNull;
    final vendor = pinnedVendor ?? geocodedVendor;

    // This phone's own GPS first; the position on the Driver's Firestore
    // doc only as a stand-in until the first fix comes through.
    final devicePosition = ref.watch(driverDevicePositionProvider).valueOrNull;
    final driverId = ref.watch(currentDriverAccountProvider).id;
    final reportedLocation = driverId.isEmpty ? null : ref.watch(driverLocationProvider(driverId)).valueOrNull;
    final driver = devicePosition != null
        ? LatLng(devicePosition.latitude, devicePosition.longitude)
        : reportedLocation != null
        ? LatLng(reportedLocation.latitude, reportedLocation.longitude)
        : null;

    // Google's road route when it's available; otherwise the map falls
    // back to a straight link and the time to a rough on-device figure.
    RoadRoute? route;
    if (vendor != null && driver != null) {
      final fetched = ref.watch(roadRouteProvider(roadRouteRequest(from: driver, to: vendor)));
      if (fetched.hasValue) _lastRoute = fetched.value;
      route = _lastRoute;
    }
    final estimate = route != null
        ? TravelEstimate.fromRoute(route)
        : vendor != null && driver != null
        ? TravelEstimate.between(driver, vendor)
        : null;
    final canNavigate = vendor != null || vendorAddress.isNotEmpty;

    // "Arrived at Vendor" stays disabled until the Driver is actually at
    // the shop. GPS never lands on the exact same coordinates twice, so
    // "at the shop" means within [kDriverArrivalRadiusMeters] of its pinned
    // location. A Vendor with no pinned location gives nothing exact to
    // measure against (a geocoded address can be a street or more off), so
    // the button stays enabled there rather than leaving the Driver stuck.
    final metersToVendor = metersBetween(driver, vendor);
    final atVendor =
        pinnedVendor == null || (metersToVendor != null && metersToVendor <= kDriverArrivalRadiusMeters);
    const mapRadius = BorderRadius.all(Radius.circular(18));

    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => context.go('/driver/home')),
        title: const Text('Navigate to vendor'),
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: palette.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: palette.border)),
              child: Row(
                children: [
                  CircleAvatar(radius: 22, backgroundColor: palette.primaryLight.withValues(alpha: 0.25), child: Icon(Icons.storefront_rounded, color: palette.primary)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(order.vendorName, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: palette.textPrimary)),
                        const SizedBox(height: 2),
                        Text('Order ${order.id} · ${order.items.length} item(s)', style: TextStyle(color: palette.textSecondary, fontSize: 12.5)),
                        if (vendorAddress.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            vendorAddress,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: palette.textSecondary, fontSize: 12.5),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Expanded(
              child: vendor != null
                  ? ClipRRect(
                      borderRadius: mapRadius,
                      child: DriverRouteMap(destination: vendor, destinationName: order.vendorName, driver: driver, route: route?.points),
                    )
                  : driver != null
                  // No shop position at all — still a real map, on the
                  // Driver, rather than the fake placeholder.
                  ? ClipRRect(borderRadius: mapRadius, child: DriverPositionMap(driver: driver))
                  : const MockMapView(height: double.infinity, showRoute: true, borderRadius: mapRadius),
            ),
            if (pinnedVendor == null) ...[
              const SizedBox(height: 8),
              Text(
                vendor != null
                    ? "Vendor location found from its address — it may be slightly off."
                    : "This vendor hasn't pinned their location yet — use Navigate to search the address.",
                textAlign: TextAlign.center,
                style: TextStyle(color: palette.textMuted, fontSize: 12),
              ),
            ] else if (driver == null) ...[
              const SizedBox(height: 8),
              Text(
                'Turn on location (GPS) and allow location access to see yourself on the map.',
                textAlign: TextAlign.center,
                style: TextStyle(color: palette.textMuted, fontSize: 12),
              ),
            ],
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: canNavigate ? () => _openGoogleMaps(context, vendor: vendor, address: vendorAddress) : null,
                    icon: const Icon(Icons.navigation_rounded, size: 18),
                    label: const Text('Navigate'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(color: palette.surfaceMuted, borderRadius: BorderRadius.circular(12)),
                    child: Row(
                      children: [
                        Icon(Icons.schedule_rounded, color: palette.primary, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                estimate == null ? '—' : '${estimate.approximate ? '~' : ''}${estimate.minutes} min',
                                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: palette.textPrimary),
                              ),
                              Text(
                                estimate == null ? 'Est. time to vendor' : '${estimate.distanceLabel} away',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(color: palette.textSecondary, fontSize: 11.5),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            ArrivalHint(
              arrived: atVendor,
              metersAway: metersToVendor,
              hasDriverPosition: driver != null,
              arrivedText: 'You\'re at the vendor. Mark yourself arrived to collect this order.',
              awayText: 'Head to the vendor to collect this order.',
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: atVendor ? () => context.go('/driver/delivery/${order.id}/pickup-confirm') : null,
              icon: Icon(atVendor ? Icons.check_circle_rounded : Icons.lock_outline_rounded, size: 20),
              label: const Text('Arrived at Vendor'),
            ),
          ],
        ),
      ),
    );
  }
}
