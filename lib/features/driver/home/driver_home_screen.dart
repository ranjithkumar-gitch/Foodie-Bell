import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/account.dart';
import '../../../data/models/order.dart';
import '../../../data/providers/firestore_drivers_provider.dart';
import '../../../data/providers/firestore_orders_provider.dart';
import '../../../data/providers/firestore_reviews_provider.dart';
import '../../../data/providers/firestore_vendors_provider.dart';
import '../../../data/providers/order_drop_off.dart';
import '../../../shared/error_reporting.dart';
import '../../../shared/time_ago.dart';
import '../../../shared/widgets/app_network_image.dart';
import '../../../shared/widgets/currency_text.dart';
import '../../../shared/widgets/driver_live_map.dart';
import '../../../shared/widgets/notification_count_badge.dart';
import '../driver_location_tracker.dart';
import '../driver_session.dart';

const kDriverFlatPayout = 20.0;

/// Home / Go Online-Offline Toggle (spec §6 item 6), laid out like the
/// Swiggy/Zomato delivery-partner apps: a big online/offline duty card, a
/// today's-earnings summary, active deliveries (each with its live map, a
/// pickup → drop timeline, call buttons and one big "go" action), and open
/// orders to accept (payout first, distance to pickup, pickup → drop).
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
        icon: Icon(Icons.wifi_tethering_rounded, color: palette.primary, size: 32),
        title: const Text('Go online?'),
        content: const Text('Turn on your availability to start receiving delivery requests.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Not now')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Go Online')),
        ],
      ),
    );
    if (goOnline == true) _toggleOnline(true);
  }

  Future<void> _toggleOnline(bool value) async {
    setState(() => _online = value);
    try {
      await setDriverOnlineStatus(ref.read(currentDriverAccountProvider).id, value);
    } catch (e, st) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyError(e, action: 'Updating availability', stackTrace: st))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    final driver = ref.watch(currentDriverAccountProvider);
    final orders = ref.watch(firestoreOrdersProvider).valueOrNull ?? const [];
    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);
    final startOfWeek = startOfToday.subtract(Duration(days: now.weekday - 1));

    final myDelivered = orders.where((o) => o.driverId == driver.id && o.status == OrderStatus.delivered).toList();
    DateTime deliveredAt(Order o) => o.statusReachedAt(OrderStatus.delivered) ?? o.placedAt;
    final todaysDeliveries = myDelivered.where((o) => !deliveredAt(o).isBefore(startOfToday)).length;
    final weeksDeliveries = myDelivered.where((o) => !deliveredAt(o).isBefore(startOfWeek)).length;

    final myRatings = (ref.watch(firestoreReviewsProvider).valueOrNull ?? const [])
        .where((r) => r.driverId == driver.id && r.driverRating != null)
        .map((r) => r.driverRating!)
        .toList();
    final averageRating = myRatings.isEmpty ? null : myRatings.reduce((a, b) => a + b) / myRatings.length;

    // A driver isn't limited to one delivery at a time — they can accept a
    // new open order while already out on another, so this is every order
    // currently assigned to them, not just the first.
    final activeOrders =
        orders
            .where(
              (o) => o.driverId == driver.id && (o.status == OrderStatus.driverAssigned || o.status == OrderStatus.pickedUp),
            )
            .toList()
          ..sort((a, b) => a.placedAt.compareTo(b.placedAt));

    // Vendors in this driver's own territory, so "open orders" only ever
    // shows pickups a driver based here would actually be dispatched for —
    // same territory-matching convention Manager's real vendor screens use.
    final vendorsById = {for (final v in ref.watch(firestoreVendorsProvider).valueOrNull ?? const <Account>[]) v.id: v};
    final openOrders =
        orders
            .where(
              (o) =>
                  o.status == OrderStatus.vendorAccepted &&
                  o.driverId == null &&
                  vendorsById[o.vendorId]?.territory == driver.territory,
            )
            .toList()
          ..sort((a, b) => a.placedAt.compareTo(b.placedAt));

    final position = ref.watch(driverDevicePositionProvider).valueOrNull;
    double? kmToVendor(String vendorId) {
      final v = vendorsById[vendorId];
      if (position == null || v?.latitude == null || v?.longitude == null) return null;
      return Geolocator.distanceBetween(position.latitude, position.longitude, v!.latitude!, v.longitude!) / 1000;
    }

    final firstName = driver.name.split(' ').first;

    return Scaffold(
      backgroundColor: palette.background,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          children: [
            // Header — avatar, greeting + territory, notifications.
            Row(
              children: [
                driver.avatarUrl != null
                    ? AppNetworkImage(url: driver.avatarUrl!, width: 46, height: 46, borderRadius: BorderRadius.circular(23))
                    : CircleAvatar(
                        radius: 23,
                        backgroundColor: palette.primary.withValues(alpha: 0.12),
                        child: Text(
                          firstName.isEmpty ? '?' : firstName[0].toUpperCase(),
                          style: TextStyle(color: palette.primary, fontWeight: FontWeight.w800, fontSize: 18),
                        ),
                      ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Hi, $firstName 👋', style: Theme.of(context).textTheme.titleLarge),
                      if (driver.territory != null)
                        Row(
                          children: [
                            Icon(Icons.place_rounded, size: 14, color: palette.textMuted),
                            const SizedBox(width: 2),
                            Flexible(
                              child: Text(
                                driver.territory!,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 12.5, color: palette.textSecondary, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    IconButton.filledTonal(
                      onPressed: () => context.push('/driver/notifications'),
                      icon: const Icon(Icons.notifications_none_rounded),
                    ),
                    const NotificationBellDot(),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 18),
            _DutyCard(online: _online, onChanged: _toggleOnline),
            const SizedBox(height: 14),
            _EarningsCard(
              todayEarnings: todaysDeliveries * kDriverFlatPayout,
              todayDeliveries: todaysDeliveries,
              weekEarnings: weeksDeliveries * kDriverFlatPayout,
              rating: averageRating,
              onTap: () => context.go('/driver/earnings'),
            ),
            if (activeOrders.isNotEmpty) ...[
              const SizedBox(height: 24),
              _SectionTitle(title: 'Active deliveries', count: activeOrders.length),
              const SizedBox(height: 12),
              for (final order in activeOrders) ...[
                _ActiveDeliveryCard(order: order, vendor: vendorsById[order.vendorId]),
                const SizedBox(height: 14),
              ],
            ],
            const SizedBox(height: 10),
            if (_online) ...[
              _SectionTitle(
                title: 'New orders${driver.territory != null ? ' in ${driver.territory}' : ''}',
                count: openOrders.isEmpty ? null : openOrders.length,
                fontWeight: FontWeight.w500,
                fontSize: 15,
              ),
              const SizedBox(height: 12),
              if (openOrders.isEmpty)
                const _LookingForOrders()
              else
                for (final order in openOrders) ...[
                  _OpenOrderCard(order: order, vendor: vendorsById[order.vendorId], kmToPickup: kmToVendor(order.vendorId)),
                  const SizedBox(height: 12),
                ],
            ] else if (activeOrders.isEmpty)
              _OfflinePrompt(onGoOnline: () => _toggleOnline(true)),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, this.count, this.fontWeight, this.fontSize});
  final String title;
  final int? count;

  /// Override the headline's own (bold) weight / size — "New orders" uses
  /// w500 at 15.
  final FontWeight? fontWeight;
  final double? fontSize;

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    return Row(
      children: [
        Flexible(
          child: Text(
            title,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: fontWeight, fontSize: fontSize),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (count != null) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(color: palette.primary, borderRadius: BorderRadius.circular(10)),
            child: Text('$count', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12)),
          ),
        ],
      ],
    );
  }
}

/// The big duty toggle — green with a live pulse while online, dark while
/// offline, the whole card tappable (not just a tiny switch) like the
/// partner apps' "GO ONLINE" slider.
class _DutyCard extends StatelessWidget {
  const _DutyCard({required this.online, required this.onChanged});
  final bool online;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      decoration: BoxDecoration(
        gradient: online
            ? LinearGradient(colors: palette.promoGradient, begin: Alignment.topLeft, end: Alignment.bottomRight)
            : const LinearGradient(colors: [Color(0xFF3A3F47), Color(0xFF22262C)]),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: (online ? palette.primary : Colors.black).withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => onChanged(!online),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 14, 16),
            child: Row(
              children: [
                _StatusDot(active: online),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        online ? "You're ON DUTY" : "You're OFF DUTY",
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 17, letterSpacing: 0.3),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        online ? 'Receiving orders near you' : 'Go online to start earning',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 12.5, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: online,
                  onChanged: onChanged,
                  activeThumbColor: Colors.white,
                  activeTrackColor: Colors.white.withValues(alpha: 0.4),
                  inactiveThumbColor: Colors.white70,
                  inactiveTrackColor: Colors.white24,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A white dot that pulses (a fading ring growing out of it) while
/// [active], solid grey otherwise.
class _StatusDot extends StatefulWidget {
  const _StatusDot({required this.active});
  final bool active;

  @override
  State<_StatusDot> createState() => _StatusDotState();
}

class _StatusDotState extends State<_StatusDot> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500));

  @override
  void initState() {
    super.initState();
    if (widget.active) _controller.repeat();
  }

  @override
  void didUpdateWidget(_StatusDot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.active) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 40,
      height: 40,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final t = widget.active ? _controller.value : 0.0;
          return Stack(
            alignment: Alignment.center,
            children: [
              if (widget.active)
                Container(
                  width: 16 + 24 * t,
                  height: 16 + 24 * t,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.45 * (1 - t))),
                ),
              Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.active ? Colors.white : Colors.white38,
                  border: Border.all(color: Colors.white70, width: 2),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _EarningsCard extends StatelessWidget {
  const _EarningsCard({
    required this.todayEarnings,
    required this.todayDeliveries,
    required this.weekEarnings,
    required this.rating,
    required this.onTap,
  });

  final double todayEarnings;
  final int todayDeliveries;
  final double weekEarnings;
  final double? rating;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: palette.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text("Today's earnings", style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w700, fontSize: 13)),
                const Spacer(),
                Text('Details', style: TextStyle(color: palette.primary, fontWeight: FontWeight.w800, fontSize: 12.5)),
                Icon(Icons.chevron_right_rounded, size: 18, color: palette.primary),
              ],
            ),
            const SizedBox(height: 6),
            CurrencyText(
              todayEarnings,
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 32, color: palette.textPrimary, height: 1.1),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                _MiniStat(icon: Icons.inventory_2_rounded, value: '$todayDeliveries', label: 'Orders today'),
                _MiniStat(icon: Icons.date_range_rounded, value: AppFormat.currency(weekEarnings), label: 'This week'),
                _MiniStat(
                  icon: Icons.star_rounded,
                  value: rating == null ? '—' : rating!.toStringAsFixed(1),
                  label: 'Rating',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.icon, required this.value, required this.label});
  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    return Expanded(
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(color: palette.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, size: 17, color: palette.primary),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: palette.textPrimary),
                ),
                Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, color: palette.textMuted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// An in-progress delivery: stage banner (PICKUP / DROP), its live map,
/// the pickup → drop timeline with the current leg highlighted, call
/// buttons for whoever the Driver is heading to, and one big action.
class _ActiveDeliveryCard extends ConsumerWidget {
  const _ActiveDeliveryCard({required this.order, required this.vendor});
  final Order order;
  final Account? vendor;

  Future<void> _call(BuildContext context, String? phone) async {
    if (phone == null || phone.isEmpty) return;
    try {
      await launchUrl(Uri(scheme: 'tel', path: phone));
    } catch (e, st) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e, action: 'Calling', stackTrace: st))));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final drop = watchOrderDropOff(ref, order);
    final palette = context.colors;
    final pickedUp = order.status == OrderStatus.pickedUp;
    final stageColor = pickedUp ? palette.success : palette.warning;
    final itemCount = order.items.fold<int>(0, (sum, i) => sum + i.quantity);
    final route = pickedUp ? '/driver/delivery/${order.id}/navigate-customer' : '/driver/delivery/${order.id}/navigate-vendor';

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: stageColor.withValues(alpha: 0.6), width: 1.4),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 16, offset: const Offset(0, 6))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: stageColor.withValues(alpha: 0.12),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                Icon(pickedUp ? Icons.delivery_dining_rounded : Icons.storefront_rounded, color: stageColor, size: 20),
                const SizedBox(width: 8),
                // Takes whatever width is left beside the icon and order id
                // (ellipsis on a narrow phone) — unbounded beside a Spacer
                // it overflowed the row.
                Expanded(
                  child: Text(
                    pickedUp ? 'DROP · Deliver to customer' : 'PICKUP · Collect from vendor',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: stageColor, fontWeight: FontWeight.w500, fontSize: 12.5, letterSpacing: 0.3),
                  ),
                ),
                const SizedBox(width: 8),
                Text('#${order.id}', style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w500, fontSize: 12)),
              ],
            ),
          ),
          InkWell(
            onTap: () => context.push(route),
            child: DriverLiveMap(order: order, height: 150, interactive: false, viewerIsCustomer: false),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
            child: Column(
              children: [
                _TimelineStop(
                  icon: Icons.storefront_rounded,
                  color: Colors.deepOrange,
                  label: 'PICKUP',
                  title: order.vendorName,
                  subtitle: vendor?.address,
                  done: pickedUp,
                  current: !pickedUp,
                  showLine: true,
                  onCall: pickedUp ? null : () => _call(context, vendor?.phone),
                ),
                _TimelineStop(
                  icon: Icons.home_rounded,
                  color: const Color(0xFF2E7D32),
                  label: 'DROP',
                  title: order.userName,
                  subtitle: drop.fullAddress,
                  done: false,
                  current: pickedUp,
                  showLine: false,
                  onCall: pickedUp ? () => _call(context, order.userPhone) : null,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: Row(
              children: [
                Icon(Icons.shopping_bag_outlined, size: 16, color: palette.textMuted),
                const SizedBox(width: 4),
                Text('$itemCount item${itemCount == 1 ? '' : 's'}', style: TextStyle(color: palette.textSecondary, fontSize: 12.5)),
                const Spacer(),
                if (order.isCod && !order.codPaymentReceived)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: palette.error.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                    child: Text(
                      'Collect ${AppFormat.currency(order.total)} cash',
                      style: TextStyle(color: palette.error, fontWeight: FontWeight.w800, fontSize: 12),
                    ),
                  )
                else
                  Text('Paid online', style: TextStyle(color: palette.success, fontWeight: FontWeight.w700, fontSize: 12.5)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: ElevatedButton.icon(
              onPressed: () => context.push(route),
              icon: const Icon(Icons.navigation_rounded, size: 20),
              label: Text(pickedUp ? 'Go to drop location' : 'Go to pickup'),
            ),
          ),
        ],
      ),
    );
  }
}

/// One stop on a delivery's pickup → drop timeline: a coloured badge
/// joined to the next stop by a vertical line, a small label, the name
/// and address, and an optional call button for the current stop.
class _TimelineStop extends StatelessWidget {
  const _TimelineStop({
    required this.icon,
    required this.color,
    required this.label,
    required this.title,
    required this.subtitle,
    required this.done,
    required this.current,
    required this.showLine,
    this.onCall,
    this.regularWeight = false,
  });

  /// Medium (w500) text instead of the bold labels/titles — the new-order
  /// cards' lighter look.
  final bool regularWeight;

  final IconData icon;
  final Color color;
  final String label;
  final String title;
  final String? subtitle;
  final bool done;
  final bool current;
  final bool showLine;
  final VoidCallback? onCall;

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    final faded = done && !current;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: faded ? palette.surfaceMuted : color.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                  border: current ? Border.all(color: color, width: 1.6) : null,
                ),
                child: Icon(done ? Icons.check_rounded : icon, size: 16, color: faded ? palette.textMuted : color),
              ),
              if (showLine)
                Expanded(
                  child: Container(width: 2, margin: const EdgeInsets.symmetric(vertical: 2), color: palette.border),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: showLine ? 14 : 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: regularWeight ? FontWeight.w500 : FontWeight.w800,
                      letterSpacing: 0.6,
                      color: palette.textMuted,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: regularWeight ? FontWeight.w500 : FontWeight.w800,
                      fontSize: 14.5,
                      color: faded ? palette.textMuted : palette.textPrimary,
                      decoration: faded ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  if (subtitle != null && subtitle!.trim().isNotEmpty)
                    Text(
                      subtitle!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: palette.textSecondary,
                        fontWeight: regularWeight ? FontWeight.w500 : null,
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (onCall != null)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: IconButton.filledTonal(
                visualDensity: VisualDensity.compact,
                onPressed: onCall,
                icon: const Icon(Icons.call_rounded, size: 18),
              ),
            ),
        ],
      ),
    );
  }
}

/// One open, unaccepted order — payout first (what a partner decides on),
/// distance to the pickup, the pickup → drop route, and a "View & Accept"
/// button into the full detail (`driver_incoming_offer_screen.dart`) so a
/// driver comparing several reviews one calmly rather than accepting blind.
class _OpenOrderCard extends ConsumerWidget {
  const _OpenOrderCard({required this.order, required this.vendor, required this.kmToPickup});
  final Order order;
  final Account? vendor;
  final double? kmToPickup;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final drop = watchOrderDropOff(ref, order);
    final palette = context.colors;
    final itemCount = order.items.fold<int>(0, (sum, i) => sum + i.quantity);
    final waitingSince = order.statusReachedAt(OrderStatus.vendorAccepted) ?? order.placedAt;
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => context.push('/driver/offer/${order.id}'),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: palette.secondary.withValues(alpha: 0.7), width: 1.3),
          boxShadow: [BoxShadow(color: palette.secondary.withValues(alpha: 0.12), blurRadius: 14, offset: const Offset(0, 6))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: palette.secondary, borderRadius: BorderRadius.circular(8)),
                  child: const Text('NEW ORDER', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500, fontSize: 11, letterSpacing: 0.5)),
                ),
                const SizedBox(width: 8),
                Text(
                  timeAgoOf(context, waitingSince),
                  style: TextStyle(color: palette.textMuted, fontSize: 12, fontWeight: FontWeight.w500),
                ),
                const Spacer(),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    CurrencyText(
                      kDriverFlatPayout,
                      style: TextStyle(fontWeight: FontWeight.w500, fontSize: 22, color: palette.success, height: 1),
                    ),
                    Text('Payout', style: TextStyle(color: palette.textMuted, fontSize: 11, fontWeight: FontWeight.w500)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 14),
            _TimelineStop(
              icon: Icons.storefront_rounded,
              color: Colors.deepOrange,
              label: kmToPickup == null ? 'PICKUP' : 'PICKUP · ${kmToPickup!.toStringAsFixed(1)} km away',
              title: order.vendorName,
              subtitle: vendor?.address,
              done: false,
              current: false,
              showLine: true,
              regularWeight: true,
            ),
            _TimelineStop(
              icon: Icons.home_rounded,
              color: const Color(0xFF2E7D32),
              label: 'DROP',
              title: drop.address?.recipientName.isNotEmpty == true ? drop.address!.recipientName : order.userName,
              subtitle: drop.fullAddress,
              done: false,
              current: false,
              showLine: false,
              regularWeight: true,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.shopping_bag_outlined, size: 16, color: palette.textMuted),
                const SizedBox(width: 4),
                Text(
                  '$itemCount item${itemCount == 1 ? '' : 's'}',
                  style: TextStyle(color: palette.textSecondary, fontSize: 12.5, fontWeight: FontWeight.w500),
                ),
                const SizedBox(width: 12),
                Icon(order.isCod ? Icons.payments_outlined : Icons.verified_rounded, size: 16, color: palette.textMuted),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    order.isCod ? 'Cash on delivery' : 'Paid online',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: palette.textSecondary, fontSize: 12.5, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            // Its own full-width row — squeezed into the row above it had
            // no width bound, and the theme's full-width button style
            // overflowed it.
            SizedBox(
              width: double.infinity,
              height: 46,
              child: FilledButton(
                onPressed: () => context.push('/driver/offer/${order.id}'),
                style: FilledButton.styleFrom(
                  backgroundColor: palette.secondary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('View & Accept', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14.5)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Online with nothing open nearby — a radar-style pulse so the screen
/// reads as "actively searching", not "empty".
class _LookingForOrders extends StatefulWidget {
  const _LookingForOrders();

  @override
  State<_LookingForOrders> createState() => _LookingForOrdersState();
}

class _LookingForOrdersState extends State<_LookingForOrders> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 2200))..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
      decoration: BoxDecoration(color: palette.surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: palette.border)),
      child: Column(
        children: [
          SizedBox(
            width: 120,
            height: 120,
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) => Stack(
                alignment: Alignment.center,
                children: [
                  for (final offset in const [0.0, 0.5])
                    Builder(
                      builder: (context) {
                        final t = (_controller.value + offset) % 1.0;
                        return Container(
                          width: 40 + 80 * t,
                          height: 40 + 80 * t,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: palette.primary.withValues(alpha: 0.5 * (1 - t)), width: 2),
                          ),
                        );
                      },
                    ),
                  child!,
                ],
              ),
              child: Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: palette.promoGradient)),
                child: const Icon(Icons.two_wheeler_rounded, color: Colors.white, size: 26),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text('Looking for orders near you…', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            "Stay online — new orders will show up here.",
            textAlign: TextAlign.center,
            style: TextStyle(color: palette.textSecondary, fontSize: 12.5),
          ),
        ],
      ),
    );
  }
}

class _OfflinePrompt extends StatelessWidget {
  const _OfflinePrompt({required this.onGoOnline});
  final VoidCallback onGoOnline;

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
      decoration: BoxDecoration(color: palette.surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: palette.border)),
      child: Column(
        children: [
          Material(
            color: palette.primary,
            shape: const CircleBorder(),
            elevation: 6,
            shadowColor: palette.primary.withValues(alpha: 0.5),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onGoOnline,
              child: const SizedBox(
                width: 96,
                height: 96,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.power_settings_new_rounded, color: Colors.white, size: 34),
                    SizedBox(height: 2),
                    Text('GO ONLINE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 0.5)),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text("You're offline", style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            'Go online to start receiving delivery requests and earning.',
            textAlign: TextAlign.center,
            style: TextStyle(color: palette.textSecondary, fontSize: 12.5),
          ),
        ],
      ),
    );
  }
}
