import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../time_ago.dart';

/// Small muted "5 min ago" / "2 hr ago" / "3 days ago" timestamp meant to
/// sit next to (or under) an order-status [StatusChip] wherever one
/// appears — how long since the order reached that status
/// (`Order.statusReachedAt(order.status)`), kept current while on screen.
/// Renders nothing for a null timestamp (orders placed before per-status
/// timestamps were tracked), rather than showing a placeholder.
class OrderStatusTimestamp extends StatelessWidget {
  const OrderStatusTimestamp(this.at, {super.key});

  final DateTime? at;

  @override
  Widget build(BuildContext context) {
    final at = this.at;
    if (at == null) return const SizedBox.shrink();
    final palette = context.colors;
    return TimeAgoText(at, style: TextStyle(color: palette.textMuted, fontSize: 10.5));
  }
}
