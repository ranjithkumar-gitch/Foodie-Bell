import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/order.dart';

const _kTrackedStatuses = [
  OrderStatus.placed,
  OrderStatus.vendorAccepted,
  OrderStatus.driverAssigned,
  OrderStatus.pickedUp,
  OrderStatus.delivered,
];

final _stepTimeFormat = DateFormat('d MMM, h:mm a');

/// Vertical status stepper mirroring the platform lifecycle (spec §4.12:
/// Placed → Vendor Accepted → Driver Assigned → Picked Up → Delivered).
/// Reused by User's Order Tracking, Vendor's order detail, Driver's active
/// delivery, and Manager/Admin oversight read-only views. Each reached step
/// shows when it was reached ([Order.statusReachedAt]) — null for a status
/// the order hasn't reached yet, or one recorded before timestamp tracking
/// existed.
class OrderStatusStepper extends StatelessWidget {
  const OrderStatusStepper({super.key, required this.status, this.statusTimestamps = const {}});

  final OrderStatus status;
  final Map<OrderStatus, DateTime> statusTimestamps;

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;

    if (status == OrderStatus.cancelled || status == OrderStatus.rejected) {
      final at = statusTimestamps[status];
      return Row(
        children: [
          Icon(Icons.cancel_rounded, color: palette.error),
          const SizedBox(width: 10),
          Text(status.label, style: TextStyle(color: palette.error, fontWeight: FontWeight.w700)),
          if (at != null) ...[
            const SizedBox(width: 8),
            Text(_stepTimeFormat.format(at), style: TextStyle(color: palette.textMuted, fontSize: 11.5)),
          ],
        ],
      );
    }

    final currentIndex = _kTrackedStatuses.indexOf(status);

    return Column(
      children: [
        for (var i = 0; i < _kTrackedStatuses.length; i++)
          _StepRow(
            label: _kTrackedStatuses[i].label,
            isDone: i <= currentIndex,
            isLast: i == _kTrackedStatuses.length - 1,
            timestamp: statusTimestamps[_kTrackedStatuses[i]],
          ),
      ],
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({required this.label, required this.isDone, required this.isLast, this.timestamp});

  final String label;
  final bool isDone;
  final bool isLast;
  final DateTime? timestamp;

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    final color = isDone ? palette.primary : palette.border;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                child: isDone ? const Icon(Icons.check_rounded, size: 14, color: Colors.white) : null,
              ),
              if (!isLast) Expanded(child: Container(width: 2, color: color)),
            ],
          ),
          const SizedBox(width: 12),
          Padding(
            padding: const EdgeInsets.only(bottom: 24, top: 2),
            child: Row(
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: isDone ? palette.textPrimary : palette.textMuted,
                    fontWeight: isDone ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
                if (isDone && timestamp != null) ...[
                  const SizedBox(width: 8),
                  Text(_stepTimeFormat.format(timestamp!), style: TextStyle(color: palette.textMuted, fontSize: 11.5)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
