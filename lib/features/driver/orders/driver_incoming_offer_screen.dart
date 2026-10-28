import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/address.dart';
import '../../../data/models/order.dart';
import '../../../data/providers/firestore_drivers_provider.dart';
import '../../../data/providers/firestore_orders_provider.dart';
import '../../../data/providers/firestore_vendors_provider.dart';
import '../../../data/providers/geocode_provider.dart';
import '../../../data/providers/order_actions.dart';
import '../../../data/providers/order_drop_off.dart';
import '../../../data/providers/road_route_provider.dart';
import '../../../shared/error_reporting.dart';
import '../../../shared/widgets/currency_text.dart';
import '../../../shared/widgets/mock_map_view.dart';
import '../driver_location_tracker.dart';
import '../driver_session.dart';
import 'driver_route_map.dart';

/// Order Offer Detail (spec §6 item 7): full pickup/drop/payout detail for
/// one open order, reached by tapping a card on Home's "Open orders" list.
/// Accepting is the one place this role performs the `vendorAccepted ->
/// driverAssigned` transition, stamping the signed-in driver onto the
/// order. No countdown/auto-decline here — Home already lists every open
/// order side by side for the driver to browse, so nothing about opening
/// one to read its details is time-pressured; "Decline" just goes back to
/// that list without mutating anything.
class DriverIncomingOfferScreen extends ConsumerStatefulWidget {
  const DriverIncomingOfferScreen({super.key, required this.orderId});

  final String orderId;

  @override
  ConsumerState<DriverIncomingOfferScreen> createState() => _DriverIncomingOfferScreenState();
}

class _DriverIncomingOfferScreenState extends ConsumerState<DriverIncomingOfferScreen> {
  bool _accepting = false;
  String? _error;

  Future<void> _accept(Order order) async {
    setState(() {
      _accepting = true;
      _error = null;
    });
    try {
      // The server checks the offer is still open in the same transaction
      // that assigns it, so two Drivers tapping at once can't both get it.
      await claimDelivery(order.id);
    } catch (e, st) {
      if (!mounted) return;
      setState(() {
        _accepting = false;
        _error = e is OrderActionException ? e.message : friendlyError(e, action: 'Accepting offer', stackTrace: st);
      });
      return;
    }
    if (!mounted) return;
    context.go('/driver/delivery/${order.id}/navigate-vendor');
  }

  void _decline() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/driver/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    final order = ref.watch(orderByIdProvider(widget.orderId)).valueOrNull;

    if (order == null || order.status != OrderStatus.vendorAccepted || order.driverId != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Order offer')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.timer_off_rounded, size: 44, color: palette.textMuted),
                const SizedBox(height: 14),
                Text('This offer is no longer available.', style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w600)),
                const SizedBox(height: 20),
                ElevatedButton(onPressed: () => context.go('/driver/home'), child: const Text('Back to home')),
              ],
            ),
          ),
        ),
      );
    }

    // ── Real positions ────────────────────────────────────────────────
    // Pickup: the vendor's pinned shop location, else its typed address
    // looked up on the map.
    final vendorAccount = ref.watch(liveVendorAccountProvider(order.vendorId));
    final vendorAddress = (vendorAccount?.address ?? '').trim();
    final pinnedVendor = vendorAccount?.latitude != null && vendorAccount?.longitude != null
        ? LatLng(vendorAccount!.latitude!, vendorAccount.longitude!)
        : null;
    final vendor =
        pinnedVendor ??
        (vendorAddress.isEmpty ? null : ref.watch(geocodedAddressProvider(vendorAddress)).valueOrNull);

    // Drop-off straight from the saved address the order was placed to —
    // its lat/long, and its full street address (`order_drop_off.dart`).
    final dropOff = watchOrderDropOff(ref, order);
    final drop = dropOff.position;

    // The Driver: this phone's GPS, else their last reported position.
    final devicePosition = ref.watch(driverDevicePositionProvider).valueOrNull;
    final driverId = ref.watch(currentDriverAccountProvider).id;
    final reported = driverId.isEmpty ? null : ref.watch(driverLocationProvider(driverId)).valueOrNull;
    final driver = devicePosition != null
        ? LatLng(devicePosition.latitude, devicePosition.longitude)
        : reported != null
        ? LatLng(reported.latitude, reported.longitude)
        : null;

    // ── Real distances, one per leg ───────────────────────────────────
    // Google's road figures when it answers, else a rough on-device guess.
    RoadRoute? toPickupRoute;
    if (driver != null && vendor != null) {
      toPickupRoute = ref.watch(roadRouteProvider(roadRouteRequest(from: driver, to: vendor))).valueOrNull;
    }
    RoadRoute? toDropRoute;
    if (vendor != null && drop != null) {
      toDropRoute = ref.watch(roadRouteProvider(roadRouteRequest(from: vendor, to: drop))).valueOrNull;
    }
    final toPickup = toPickupRoute != null
        ? TravelEstimate.fromRoute(toPickupRoute)
        : driver != null && vendor != null
        ? TravelEstimate.between(driver, vendor)
        : null;
    final toDrop = toDropRoute != null
        ? TravelEstimate.fromRoute(toDropRoute)
        : vendor != null && drop != null
        ? TravelEstimate.between(vendor, drop)
        : null;
    final routePoints = [...?toPickupRoute?.points, ...?toDropRoute?.points];
    final itemCount = order.items.fold<int>(0, (sum, i) => sum + i.quantity);

    String legLabel(TravelEstimate? e, String fallback, String suffix) =>
        e == null ? fallback : '${e.distanceLabel} · ${e.approximate ? '~' : ''}${e.minutes} min $suffix';

    return Scaffold(
      appBar: AppBar(title: const Text('Delivery request')),
      backgroundColor: palette.background,
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: SizedBox(
                      height: 240,
                      child: vendor != null
                          ? TripPreviewMap(
                              pickup: vendor,
                              pickupName: order.vendorName,
                              driver: driver,
                              drop: drop,
                              dropName: dropOff.fullAddress,
                              route: routePoints.length > 1 ? routePoints : null,
                            )
                          : driver != null
                          ? DriverPositionMap(driver: driver)
                          : const MockMapView(height: 240, showRoute: true),
                    ),
                  ),
                  if (vendor == null) ...[
                    const SizedBox(height: 6),
                    Text(
                      "This vendor's location isn't on the map yet.",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: palette.textMuted, fontSize: 12),
                    ),
                  ],
                  const SizedBox(height: 14),
                  // Payout + whole-trip summary.
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: palette.promoGradient, begin: Alignment.topLeft, end: Alignment.bottomRight),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'You earn',
                                style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontWeight: FontWeight.w500, fontSize: 13),
                              ),
                              CurrencyText(
                                // The whole delivery fee is the Driver's.
                                order.money != null ? order.money!.driverEntitlement / 100 : Order.legacyDriverPayout,
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 28, height: 1.15),
                              ),
                            ],
                          ),
                        ),
                        if (toPickup != null || toDrop != null)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                'Total trip',
                                style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontWeight: FontWeight.w500, fontSize: 12),
                              ),
                              Text(
                                _totalLabel(toPickup, toDrop),
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  // Pickup → drop with each leg's real distance and time.
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: palette.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: palette.border),
                    ),
                    child: Column(
                      children: [
                        _OfferStop(
                          icon: Icons.storefront_rounded,
                          color: Colors.deepOrange,
                          label: 'PICKUP',
                          title: order.vendorName,
                          subtitle: vendorAddress.isEmpty ? null : vendorAddress,
                          detail: legLabel(toPickup, driver == null ? 'Turn on location to see distance' : 'Distance unavailable', 'from you'),
                          showLine: true,
                        ),
                        _OfferStop(
                          icon: Icons.home_rounded,
                          color: const Color(0xFF2E7D32),
                          label: dropOff.address == null ? 'DROP' : 'DROP · ${dropOff.address!.label.label.toUpperCase()}',
                          title: dropOff.address?.recipientName.isNotEmpty == true ? dropOff.address!.recipientName : order.userName,
                          subtitle: dropOff.fullAddress,
                          detail: legLabel(toDrop, 'Distance unavailable', 'from vendor'),
                          showLine: false,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: palette.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: palette.border),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.shopping_bag_outlined, size: 18, color: palette.textMuted),
                        const SizedBox(width: 6),
                        Text(
                          '$itemCount item${itemCount == 1 ? '' : 's'}',
                          style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w500),
                        ),
                        const Spacer(),
                        if (order.isCod)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(color: palette.warning.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(8)),
                            child: Text(
                              'Collect ${AppFormat.currency(order.total)} cash',
                              style: TextStyle(color: palette.warning, fontWeight: FontWeight.w500, fontSize: 12.5),
                            ),
                          )
                        else
                          Text('Paid online', style: TextStyle(color: palette.success, fontWeight: FontWeight.w500, fontSize: 12.5)),
                      ],
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 14),
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: palette.error, fontWeight: FontWeight.w500, fontSize: 12.5),
                    ),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _accepting ? null : _decline,
                      style: OutlinedButton.styleFrom(foregroundColor: palette.error, side: BorderSide(color: palette.error)),
                      child: const Text('Back'),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: _accepting ? null : () => _accept(order),
                      child: _accepting
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.2))
                          : const Text('Accept order'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// "4.2 km · ~18 min" across both legs — whatever's known of them.
  String _totalLabel(TravelEstimate? a, TravelEstimate? b) {
    final meters = (a?.meters ?? 0) + (b?.meters ?? 0);
    final minutes = (a?.minutes ?? 0) + (b?.minutes ?? 0);
    final approximate = (a?.approximate ?? false) || (b?.approximate ?? false) || a == null || b == null;
    final distance = meters < 1000 ? '${meters.round()} m' : '${(meters / 1000).toStringAsFixed(1)} km';
    return '$distance · ${approximate ? '~' : ''}$minutes min';
  }
}

/// One stop in the offer's pickup → drop list: coloured badge (joined to
/// the next stop by a line), label, name, address, and that leg's distance
/// and time.
class _OfferStop extends StatelessWidget {
  const _OfferStop({
    required this.icon,
    required this.color,
    required this.label,
    required this.title,
    required this.subtitle,
    required this.detail,
    required this.showLine,
  });

  final IconData icon;
  final Color color;
  final String label;
  final String title;
  final String? subtitle;
  final String detail;
  final bool showLine;

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(color: color.withValues(alpha: 0.14), shape: BoxShape.circle),
                child: Icon(icon, size: 17, color: color),
              ),
              if (showLine)
                Expanded(child: Container(width: 2, margin: const EdgeInsets.symmetric(vertical: 3), color: palette.border)),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: showLine ? 16 : 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w500, letterSpacing: 0.6, color: palette.textMuted)),
                  const SizedBox(height: 1),
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontWeight: FontWeight.w500, fontSize: 15, color: palette.textPrimary),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: palette.textSecondary),
                    ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.near_me_rounded, size: 13, color: palette.primary),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          detail,
                          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500, color: palette.primary),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
