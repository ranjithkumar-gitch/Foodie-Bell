import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/address.dart';
import '../../../data/models/order.dart';
import '../../../data/providers/firestore_drivers_provider.dart';
import '../../../data/providers/firestore_orders_provider.dart';
import '../../../data/providers/order_drop_off.dart';
import '../../../data/providers/road_route_provider.dart';
import '../../../shared/error_reporting.dart';
import '../../../shared/widgets/mock_map_view.dart';
import '../driver_location_tracker.dart';
import '../driver_session.dart';
import 'driver_route_map.dart';

/// Active Delivery — Navigate to Customer (spec §6 item 10): a real map of
/// the drop-off (the position snapshotted on the order, else the User's
/// saved address it was placed to) and the Driver's own live position, a
/// "Navigate" hand-off to Google Maps with a time-to-reach beside it, a real
/// call (device dialer, `order.userPhone`) and one-to-one chat
/// (`order_chat_screen.dart`), plus an "Arrived at Customer" action that
/// routes into Cash Collection (COD orders only) then Delivery
/// Confirmation. "Arrived" stays locked until the Driver is within
/// [kDriverArrivalRadiusMeters] of the drop-off, same as pickup
/// (`driver_navigate_vendor_screen.dart`). Call/chat only show while the
/// order is still active.
class DriverNavigateCustomerScreen extends ConsumerStatefulWidget {
  const DriverNavigateCustomerScreen({super.key, required this.orderId});

  final String orderId;

  @override
  ConsumerState<DriverNavigateCustomerScreen> createState() => _DriverNavigateCustomerScreenState();
}

class _DriverNavigateCustomerScreenState extends ConsumerState<DriverNavigateCustomerScreen> {
  /// The last road route Google returned — kept on screen while the next
  /// one loads as the Driver moves, so the line doesn't blink away.
  RoadRoute? _lastRoute;

  static const _dropOffColor = Color(0xFF2E7D32);

  Future<void> _call(BuildContext context, String phone) async {
    if (phone.isEmpty) return;
    final uri = Uri(scheme: 'tel', path: phone);
    try {
      final launched = await launchUrl(uri);
      if (!launched && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open the phone dialer.')));
      }
    } catch (e, st) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e, action: 'Calling customer', stackTrace: st))));
    }
  }

  /// Opens Google Maps with the route to the drop-off — by coordinates
  /// when known, otherwise by searching the typed address.
  Future<void> _openGoogleMaps(BuildContext context, {LatLng? dropOff, required String address}) async {
    final uri = Uri.https('www.google.com', '/maps/dir/', {
      'api': '1',
      'destination': dropOff != null ? '${dropOff.latitude},${dropOff.longitude}' : address,
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
    final canContact = !order.status.isTerminal;

    // The drop-off straight from the saved address the order was placed to
    // (its lat/long and full street address — see `order_drop_off.dart`).
    final drop = watchOrderDropOff(ref, order);
    final dropOff = drop.position;
    final pinnedDropOff = drop.pinned ? drop.position : null;
    final fullAddress = drop.fullAddress;
    final savedAddress = drop.address;

    // This phone's own GPS first; the Driver's Firestore position only as
    // a stand-in until the first fix comes through.
    final devicePosition = ref.watch(driverDevicePositionProvider).valueOrNull;
    final driverId = ref.watch(currentDriverAccountProvider).id;
    final reportedLocation = driverId.isEmpty ? null : ref.watch(driverLocationProvider(driverId)).valueOrNull;
    final driver = devicePosition != null
        ? LatLng(devicePosition.latitude, devicePosition.longitude)
        : reportedLocation != null
        ? LatLng(reportedLocation.latitude, reportedLocation.longitude)
        : null;

    RoadRoute? route;
    if (dropOff != null && driver != null) {
      final fetched = ref.watch(roadRouteProvider(roadRouteRequest(from: driver, to: dropOff)));
      if (fetched.hasValue) _lastRoute = fetched.value;
      route = _lastRoute;
    }
    final estimate = route != null
        ? TravelEstimate.fromRoute(route)
        : dropOff != null && driver != null
        ? TravelEstimate.between(driver, dropOff)
        : null;

    // Locked until within [kDriverArrivalRadiusMeters] of the drop-off. An
    // order with no pinned drop-off has nothing exact to measure against (a
    // geocoded address can be a street or more off), so it stays enabled
    // rather than stranding the Driver.
    final metersToCustomer = metersBetween(driver, dropOff);
    final atCustomer =
        pinnedDropOff == null || (metersToCustomer != null && metersToCustomer <= kDriverArrivalRadiusMeters);
    const mapRadius = BorderRadius.all(Radius.circular(18));

    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => context.go('/driver/home')),
        title: const Text('Navigate to customer'),
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
                  CircleAvatar(radius: 22, backgroundColor: palette.primaryLight.withValues(alpha: 0.25), child: Icon(Icons.person_rounded, color: palette.primary)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                savedAddress?.recipientName.isNotEmpty == true ? savedAddress!.recipientName : order.userName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: palette.textPrimary),
                              ),
                            ),
                            if (savedAddress != null) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(color: palette.surfaceMuted, borderRadius: BorderRadius.circular(6)),
                                child: Text(
                                  savedAddress.label.label,
                                  style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w500, color: palette.textSecondary),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          fullAddress,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: palette.textSecondary, fontSize: 12.5, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                  if (canContact) ...[
                    _CircleAction(icon: Icons.call_rounded, onTap: () => _call(context, order.userPhone)),
                    const SizedBox(width: 8),
                    _CircleAction(icon: Icons.chat_bubble_rounded, onTap: () => context.push('/driver/delivery/${order.id}/chat')),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 14),
            Expanded(
              child: dropOff != null
                  ? ClipRRect(
                      borderRadius: mapRadius,
                      child: DriverRouteMap(
                        destination: dropOff,
                        destinationName: order.userName,
                        destinationIcon: Icons.home_rounded,
                        destinationColor: _dropOffColor,
                        destinationSnippet: 'Drop-off',
                        driver: driver,
                        route: route?.points,
                      ),
                    )
                  : driver != null
                  ? ClipRRect(borderRadius: mapRadius, child: DriverPositionMap(driver: driver))
                  : const MockMapView(height: double.infinity, showRoute: true, borderRadius: mapRadius),
            ),
            if (pinnedDropOff == null) ...[
              const SizedBox(height: 8),
              Text(
                dropOff != null
                    ? "Drop-off found from the address — it may be slightly off."
                    : "This address has no pinned location — use Navigate to search it in Google Maps.",
                textAlign: TextAlign.center,
                style: TextStyle(color: palette.textMuted, fontSize: 12),
              ),
            ],
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _openGoogleMaps(context, dropOff: dropOff, address: fullAddress),
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
                                estimate == null ? 'Est. time to customer' : '${estimate.distanceLabel} away',
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
              arrived: atCustomer,
              metersAway: metersToCustomer,
              hasDriverPosition: driver != null,
              arrivedText: 'You\'re at the customer\'s location. Mark yourself arrived to hand over this order.',
              awayText: 'Head to the customer to hand over this order.',
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: atCustomer
                  ? () => context.go(
                      order.isCod ? '/driver/delivery/${order.id}/cash-collection' : '/driver/delivery/${order.id}/delivery-confirm',
                    )
                  : null,
              icon: Icon(atCustomer ? Icons.check_circle_rounded : Icons.lock_outline_rounded, size: 20),
              label: const Text('Arrived at Customer'),
            ),
          ],
        ),
      ),
    );
  }
}

class _CircleAction extends StatelessWidget {
  const _CircleAction({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: CircleAvatar(radius: 18, backgroundColor: palette.primary, child: Icon(icon, color: Colors.white, size: 18)),
    );
  }
}
