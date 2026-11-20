import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/providers/vendor_incidents_provider.dart';
import '../../../shared/error_reporting.dart';

/// Manager: a shop's cancellation record (Phase I.4,
/// `vendor_accountability/{vendorId}`) — the server's rolling 7/30-day
/// figures and flags, with the thresholds approved for beta. The flags are
/// informational: they never suspend, hide, rank or charge a shop.
class VendorReliabilityCard extends StatelessWidget {
  const VendorReliabilityCard({super.key, required this.reliability});
  final AsyncValue<VendorReliability?> reliability;

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: palette.surfaceMuted, borderRadius: BorderRadius.circular(12)),
      child: reliability.when(
        loading: () => const Center(child: Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator())),
        error: (e, st) => Text(friendlyError(e, action: 'Loading the shop’s reliability', stackTrace: st), style: TextStyle(color: palette.error)),
        data: (r) {
          if (r == null) return Text('No cancellations or rejections recorded.', style: TextStyle(color: palette.textMuted));
          final flags = [
            if (r.escalation) ('Escalated to QuickMandi', palette.error),
            if (r.reviewRequired) ('Review needed', palette.warning),
            if (r.warning && !r.reviewRequired) ('Warning', palette.warning),
          ];
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (flags.isNotEmpty) ...[
                Wrap(spacing: 6, children: [
                  for (final (label, color) in flags)
                    Chip(visualDensity: VisualDensity.compact, label: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w700)), backgroundColor: color.withValues(alpha: 0.12)),
                ]),
                const SizedBox(height: 6),
              ],
              _line(context, 'Last 7 days', '${r.cancellations7} cancelled · ${r.rejections7} rejected · ${r.accepted7} accepted'),
              _line(context, 'Last 30 days', '${r.cancellations30} cancelled · ${r.rejections30} rejected · ${r.accepted30} accepted'),
              _line(context, 'Cancellation rate (30 days)', '${(r.rate30 * 100).toStringAsFixed(1)}%'),
              if (r.excused30 > 0) _line(context, 'Excused (30 days)', '${r.excused30}'),
              if (r.reviewRequiredWeeks.length > 1 && r.reviewRequiredWeeks.every((w) => w))
                _line(context, 'Review needed', '${r.reviewRequiredWeeks.length} weeks running'),
              const SizedBox(height: 6),
              Text(
                r.provisionalThresholds
                    ? 'Flags were worked out with provisional thresholds and are for information only.'
                    : 'Flags are for information only — they never suspend, rank or charge a shop.',
                style: TextStyle(color: palette.textMuted, fontSize: 12),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _line(BuildContext context, String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(children: [
      Expanded(child: Text(label, style: TextStyle(color: context.colors.textSecondary))),
      Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
    ]),
  );
}
