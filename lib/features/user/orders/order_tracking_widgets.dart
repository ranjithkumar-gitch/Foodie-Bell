import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/order.dart';
import '../../../l10n/app_localizations_context.dart';

/// Before a delivery partner is on the job (placed / vendor accepted)
/// there's nothing moving to follow, so tracking UIs show [OrderStageHero]
/// instead of the live map — same as Swiggy/Zomato.
bool orderShowsLiveMap(OrderStatus status) =>
    status == OrderStatus.driverAssigned || status == OrderStatus.pickedUp;

/// What's happening with [order] right now, in words — the icon, headline
/// and one-line explanation every tracking surface (Home's active-order
/// card, Order Detail) shows for the current stage.
({IconData icon, String title, String subtitle}) orderStageInfo(BuildContext context, Order order) {
  final l10n = context.l10n;
  final driverName = order.driverName ?? l10n.homeTrackDefaultDriver;
  return switch (order.status) {
    OrderStatus.placed => (
      icon: Icons.receipt_long_rounded,
      title: l10n.homeTrackPlacedTitle,
      subtitle: l10n.homeTrackPlacedSubtitle(order.vendorName),
    ),
    OrderStatus.vendorAccepted => (
      icon: Icons.soup_kitchen_rounded,
      title: l10n.homeTrackAcceptedTitle,
      subtitle: l10n.homeTrackAcceptedSubtitle(order.vendorName),
    ),
    OrderStatus.driverAssigned => (
      icon: Icons.two_wheeler_rounded,
      title: l10n.homeTrackDriverAssignedTitle,
      subtitle: l10n.homeTrackDriverAssignedSubtitle(driverName),
    ),
    _ => (
      icon: Icons.delivery_dining_rounded,
      title: l10n.homeTrackPickedUpTitle,
      subtitle: l10n.homeTrackPickedUpSubtitle(driverName),
    ),
  };
}

/// Order Detail's big status panel — sits where the map goes, at the same
/// height, while the order is still with the vendor: a large pulsing stage
/// icon, the headline, the explanation, and the 4-step progress bar.
class OrderStageHero extends StatelessWidget {
  const OrderStageHero({super.key, required this.order, this.height = 280, this.borderRadius});

  final Order order;
  final double height;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    final stage = orderStageInfo(context, order);
    return Container(
      height: height,
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 22),
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [palette.primary.withValues(alpha: 0.16), palette.primaryLight.withValues(alpha: 0.05)],
        ),
      ),
      child: Column(
        children: [
          const Spacer(),
          PulsingStatusIcon(icon: stage.icon, size: 84),
          const SizedBox(height: 18),
          Text(
            stage.title,
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20, color: palette.textPrimary),
          ),
          const SizedBox(height: 6),
          Text(
            stage.subtitle,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: palette.textSecondary, fontSize: 13.5, height: 1.35),
          ),
          const Spacer(),
          OrderProgressBar(status: order.status),
        ],
      ),
    );
  }
}

/// The current stage's icon on a brand disc, with a soft ring that keeps
/// expanding and fading out behind it — the "something is happening"
/// heartbeat food apps show while the order waits on the vendor. [size] is
/// the disc's diameter; the ring grows to ~1.3× that.
class PulsingStatusIcon extends StatefulWidget {
  const PulsingStatusIcon({super.key, required this.icon, this.size = 44});
  final IconData icon;
  final double size;

  @override
  State<PulsingStatusIcon> createState() => _PulsingStatusIconState();
}

class _PulsingStatusIconState extends State<PulsingStatusIcon> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    final size = widget.size;
    final outer = size * 1.3;
    return SizedBox(
      width: outer,
      height: outer,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final t = Curves.easeOut.transform(_controller.value);
          final ring = size * 0.9 + (outer - size * 0.9) * t;
          return Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: ring,
                height: ring,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: palette.primary.withValues(alpha: 0.28 * (1 - t)),
                ),
              ),
              child!,
            ],
          );
        },
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: palette.promoGradient)),
          child: Icon(widget.icon, color: Colors.white, size: size * 0.5),
        ),
      ),
    );
  }
}

/// Four-segment progress bar — Placed → Accepted → Partner assigned →
/// Picked up. Finished stages are solid; the current one shimmers so the
/// bar reads as "in progress" rather than stuck.
class OrderProgressBar extends StatefulWidget {
  const OrderProgressBar({super.key, required this.status});
  final OrderStatus status;

  @override
  State<OrderProgressBar> createState() => _OrderProgressBarState();
}

class _OrderProgressBarState extends State<OrderProgressBar> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  static const _stages = [OrderStatus.placed, OrderStatus.vendorAccepted, OrderStatus.driverAssigned, OrderStatus.pickedUp];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    final current = _stages.indexOf(widget.status);
    return Row(
      children: [
        for (var i = 0; i < _stages.length; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: SizedBox(
                height: 5,
                child: i < current
                    ? ColoredBox(color: palette.primary)
                    : i == current
                    ? AnimatedBuilder(
                        animation: _controller,
                        // A bright band sweeping left → right across the
                        // segment; the gradient clamps to the dim end
                        // colour outside the band.
                        builder: (context, _) => DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment(3 * _controller.value - 2, 0),
                              end: Alignment(3 * _controller.value - 1, 0),
                              colors: [
                                palette.primary.withValues(alpha: 0.35),
                                palette.primary,
                                palette.primary.withValues(alpha: 0.35),
                              ],
                            ),
                          ),
                        ),
                      )
                    : ColoredBox(color: palette.border),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
