import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

enum StatusTone { neutral, success, warning, error, info }

/// A small status pill reused across order status, ticket status, account
/// status (active/pending/rejected/suspended), category active toggle, etc.
class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.label, this.tone = StatusTone.neutral});

  final String label;
  final StatusTone tone;

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    final color = switch (tone) {
      StatusTone.neutral => palette.textSecondary,
      StatusTone.success => palette.success,
      StatusTone.warning => palette.warning,
      StatusTone.error => palette.error,
      StatusTone.info => palette.primary,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
      child: Text(label, style: TextStyle(color: color, fontSize: 11.5, fontWeight: FontWeight.w800)),
    );
  }
}
