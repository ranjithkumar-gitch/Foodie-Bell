import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';

final _orderStatusTimeFormat = DateFormat('d MMM, h:mm a');

/// Small muted timestamp meant to sit next to (or under) an order-status
/// [StatusChip] wherever one appears — when the order reached that status
/// (`Order.statusReachedAt(order.status)`). Renders nothing for a null
/// timestamp (orders placed before per-status timestamps were tracked),
/// rather than showing a placeholder.
class OrderStatusTimestamp extends StatelessWidget {
  const OrderStatusTimestamp(this.at, {super.key});

  final DateTime? at;

  @override
  Widget build(BuildContext context) {
    final at = this.at;
    if (at == null) return const SizedBox.shrink();
    final palette = context.colors;
    return Text(_orderStatusTimeFormat.format(at), style: TextStyle(color: palette.textMuted, fontSize: 10.5));
  }
}
