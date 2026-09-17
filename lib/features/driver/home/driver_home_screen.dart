import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/order.dart';
import '../../../data/providers/firestore_drivers_provider.dart';
import '../../../data/providers/firestore_orders_provider.dart';
import '../../../data/providers/firestore_vendors_provider.dart';
import '../../../shared/error_reporting.dart';
import '../../../shared/widgets/currency_text.dart';
import '../../../shared/widgets/notification_count_badge.dart';
import '../driver_session.dart';

const kDriverFlatPayout = 20.0;

/// Home / Go Online-Offline Toggle (spec §6 item 6): a big availability
/// switch, today's earnings, and whatever needs this driver's attention
/// right now — an in-progress delivery to resume, or open orders to accept.
///
/// The online/offline flag is persisted (`Account.isOnline`,
/// `setDriverOnlineStatus`) so it's remembered across app restarts/re-logins
/// instead of always resetting to offline — seeded once from the signed-in
/// driver's own record on first load.
class DriverHomeScreen extends ConsumerStatefulWidget {
  const DriverHomeScreen({super.key});

  @override
  ConsumerState<DriverHomeScreen> createState() => _DriverHomeScreenState();
}

class _DriverHomeScreenState extends ConsumerState<DriverHomeScreen> {
  late bool _online = ref.read(currentDriverAccountProvider).isOnline;

  @override
  void initState() {
    super.initState();
    // Only ever prompted once per app session, and only when the driver
    // isn't already online — no point asking someone who already is.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_online) _showGoOnlineDialog();
    });
  }

  Future<void> _showGoOnlineDialog() async {
    final palette = context.colors;
    final goOnline = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(
          Icons.wifi_tethering_rounded,
          color: palette.primary,
          size: 32,
        ),
        title: const Text('Go online?'),
        content: const Text(
          'Turn on your availability to start receiving delivery requests.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Not now'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Go Online'),
          ),
        ],
      ),
    );
    if (goOnline == true) _toggleOnline(true);
  }

  Future<void> _toggleOnline(bool value) async {
    setState(() => _online = value);
    try {
      await setDriverOnlineStatus(
        ref.read(currentDriverAccountProvider).id,
        value,
      );
    } catch (e, st) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            friendlyError(e, action: 'Updating availability', stackTrace: st),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    final driver = ref.watch(currentDriverAccountProvider);
    final orders = ref.watch(firestoreOrdersProvider).valueOrNull ?? const [];
    final now = DateTime.now();

    final todaysDeliveries = orders
        .where(
          (o) =>
              o.driverId == driver.id &&
              o.status == OrderStatus.delivered &&
              o.placedAt.year == now.year &&
              o.placedAt.month == now.month &&
              o.placedAt.day == now.day,
        )
        .toList();
    final todaysEarnings = todaysDeliveries.length * kDriverFlatPayout;

    // A driver isn't limited to one delivery at a time — they can accept a
    // new open order while already out on another, so this is every order
    // currently assigned to them, not just the first.
    final activeOrders =
        orders
            .where(
              (o) =>
                  o.driverId == driver.id &&
                  (o.status == OrderStatus.driverAssigned ||
                      o.status == OrderStatus.pickedUp),
            )
            .toList()
          ..sort((a, b) => a.placedAt.compareTo(b.placedAt));

    // Vendors in this driver's own territory, so "open orders" only ever
    // shows pickups a driver based here would actually be dispatched for —
    // same territory-matching convention Manager's real vendor screens use.
    final vendorTerritoryById = {
      for (final v
          in ref.watch(firestoreVendorsProvider).valueOrNull ?? const [])
        v.id: v.territory,
    };
    final openOrders =
        orders
            .where(
              (o) =>
                  o.status == OrderStatus.vendorAccepted &&
                  o.driverId == null &&
                  vendorTerritoryById[o.vendorId] == driver.territory,
            )
            .toList()
          ..sort((a, b) => a.placedAt.compareTo(b.placedAt));

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Hi, ${driver.name.split(' ').first}'),
            if (driver.territory != null)
              Text(
                driver.territory!,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: palette.textSecondary,
                ),
              ),
          ],
        ),
        actions: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton(
                onPressed: () => context.push('/driver/notifications'),
                icon: const Icon(Icons.notifications_none_rounded),
              ),
              const NotificationBellDot(),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: palette.promoGradient,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _online ? "You're Online" : "You're Offline",
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _online
                            ? "You're available for orders"
                            : 'Go online to start receiving orders',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: _online,
                  onChanged: _toggleOnline,
                  activeThumbColor: Colors.white,
                  activeTrackColor: Colors.white.withValues(alpha: 0.4),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  icon: Icons.payments_rounded,
                  label: "Today's earnings",
                  value: AppFormat.currency(todaysEarnings),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  icon: Icons.local_shipping_rounded,
                  label: 'Deliveries today',
                  value: '${todaysDeliveries.length}',
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (activeOrders.isNotEmpty) ...[
            Text(
              'Active deliveries (${activeOrders.length})',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 12),
            for (final order in activeOrders) ...[
              _ActiveOrderCard(order: order),
              const SizedBox(height: 12),
            ],
          ],
          if (_online) ...[
            if (activeOrders.isNotEmpty) const SizedBox(height: 8),
            Text(
              'Open orders${driver.territory != null ? ' in ${driver.territory}' : ''}',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 12),
            if (openOrders.isEmpty)
              Container(
                padding: const EdgeInsets.all(24),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: palette.surfaceMuted,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.hourglass_top_rounded,
                      color: palette.textMuted,
                      size: 32,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Waiting for new orders nearby...',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: palette.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              )
            else
              for (final order in openOrders) ...[
                _OpenOrderCard(order: order),
                const SizedBox(height: 12),
              ],
          ] else if (activeOrders.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: palette.surfaceMuted,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.power_settings_new_rounded,
                    color: palette.textMuted,
                    size: 32,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    "You're offline — flip the switch above to start earning.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: palette.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: palette.primary),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 20,
              color: palette.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(color: palette.textSecondary, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _ActiveOrderCard extends StatelessWidget {
  const _ActiveOrderCard({required this.order});
  final Order order;

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    final isPickedUp = order.status == OrderStatus.pickedUp;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.primary, width: 1.4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isPickedUp ? Icons.house_rounded : Icons.storefront_rounded,
                color: palette.primary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order.id,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: palette.textPrimary,
                      ),
                    ),
                    Text(
                      isPickedUp
                          ? 'Heading to ${order.userName}'
                          : 'Pickup from ${order.vendorName}',
                      style: TextStyle(
                        color: palette.textSecondary,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ElevatedButton(
            onPressed: () => context.push(
              isPickedUp
                  ? '/driver/delivery/${order.id}/navigate-customer'
                  : '/driver/delivery/${order.id}/navigate-vendor',
            ),
            child: Text(
              isPickedUp ? 'Navigate to customer' : 'Navigate to vendor',
            ),
          ),
        ],
      ),
    );
  }
}

/// One open, unaccepted order on the Home list — tapping it opens the full
/// pickup/drop/payout detail (`driver_incoming_offer_screen.dart`) to
/// Accept or go back, so a driver browsing several open orders side by side
/// can review one calmly before committing rather than accepting blind off
/// a compact card.
class _OpenOrderCard extends StatelessWidget {
  const _OpenOrderCard({required this.order});
  final Order order;

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => context.push('/driver/offer/${order.id}'),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: palette.secondary.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: palette.secondary),
        ),
        child: Row(
          children: [
            Icon(Icons.notifications_active_rounded, color: palette.secondary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Pickup from ${order.vendorName}',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: palette.textPrimary,
                    ),
                  ),
                  Text(
                    'Drop at ${order.deliveryAddressLabel}',
                    style: TextStyle(
                      color: palette.textSecondary,
                      fontSize: 12.5,
                    ),
                  ),
                  Text(
                    'Payout ${AppFormat.currency(kDriverFlatPayout)} · ${order.items.length} item(s)',
                    style: TextStyle(
                      color: palette.textSecondary,
                      fontSize: 12.5,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: palette.textMuted),
          ],
        ),
      ),
    );
  }
}
