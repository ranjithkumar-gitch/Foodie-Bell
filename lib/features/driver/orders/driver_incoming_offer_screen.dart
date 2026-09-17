import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/order.dart';
import '../../../data/providers/firestore_orders_provider.dart';
import '../../../shared/error_reporting.dart';
import '../../../shared/widgets/currency_text.dart';
import '../driver_session.dart';
import '../home/driver_home_screen.dart';

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
    final driver = ref.read(currentDriverAccountProvider);
    try {
      await updateOrderStatus(order.id, OrderStatus.driverAssigned, driverId: driver.id, driverName: driver.name, driverPhone: driver.phone);
    } catch (e, st) {
      if (!mounted) return;
      setState(() {
        _accepting = false;
        _error = friendlyError(e, action: 'Accepting offer', stackTrace: st);
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

    // The Order model doesn't carry real pickup/drop-off distances — derive
    // stable placeholders from the order id so they're at least consistent
    // per order rather than a fixed made-up number.
    final pickupDistanceKm = 1.0 + (order.id.hashCode.abs() % 15) / 10;
    final dropDistanceKm = 1.0 + (order.id.hashCode.abs() % 25) / 10;

    return Scaffold(
      appBar: AppBar(title: const Text('Delivery request')),
      backgroundColor: palette.background,
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(color: palette.surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: palette.border)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(radius: 22, backgroundColor: palette.primaryLight.withValues(alpha: 0.25), child: Icon(Icons.storefront_rounded, color: palette.primary)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(order.vendorName, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: palette.textPrimary)),
                                Text('Pickup · ${pickupDistanceKm.toStringAsFixed(1)} km away', style: TextStyle(color: palette.textSecondary, fontSize: 12.5)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Divider()),
                      Row(
                        children: [
                          Icon(Icons.place_rounded, color: palette.error),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Drop at ${order.deliveryAddressLabel}', style: TextStyle(fontWeight: FontWeight.w700, color: palette.textPrimary)),
                                Text('Drop · ${dropDistanceKm.toStringAsFixed(1)} km from vendor', style: TextStyle(color: palette.textSecondary, fontSize: 12.5)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Divider()),
                      Row(
                        children: [
                          Text('${order.items.length} item(s)', style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w600)),
                          const Spacer(),
                          if (order.isCod)
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: Text('COD · ${AppFormat.currency(order.total)}', style: TextStyle(color: palette.warning, fontWeight: FontWeight.w700, fontSize: 12.5)),
                            ),
                        ],
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(color: palette.primaryLight.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(14)),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('You earn', style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w700)),
                            CurrencyText(kDriverFlatPayout, style: TextStyle(color: palette.primary, fontWeight: FontWeight.w800, fontSize: 20)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 14),
                Text(_error!, textAlign: TextAlign.center, style: TextStyle(color: palette.error, fontWeight: FontWeight.w600, fontSize: 12.5)),
              ],
              const SizedBox(height: 20),
              Row(
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
                    child: ElevatedButton(
                      onPressed: _accepting ? null : () => _accept(order),
                      child: _accepting
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.2))
                          : const Text('Accept'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
