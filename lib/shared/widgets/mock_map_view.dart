import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// What a map slot shows when there's no real map to draw — no road
/// route from the server (`orderRoute`), no location yet, or no map on
/// this screen. It used to paint a fake road grid with an animated route,
/// which looked like real navigation; now it's a plain "map not available"
/// panel, so nothing invented is ever shown as a map (Phase I.2). The name
/// and parameters are kept so the callers didn't change; [showPin] and
/// [showRoute] no longer draw anything.
class MockMapView extends StatelessWidget {
  const MockMapView({
    super.key,
    this.height = 200,
    this.showPin = true,
    this.showRoute = false,
    this.borderRadius,
  });

  final double height;
  final bool showPin;
  final bool showRoute;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    return ClipRRect(
      borderRadius: borderRadius ?? BorderRadius.circular(16),
      child: Container(
        height: height,
        width: double.infinity,
        color: palette.surfaceMuted,
        alignment: Alignment.center,
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.map_outlined, color: palette.textMuted, size: 32),
            const SizedBox(height: 8),
            Text('Map not available', style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text('Use the address shown for directions.', textAlign: TextAlign.center, style: TextStyle(color: palette.textMuted, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
