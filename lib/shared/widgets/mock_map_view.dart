import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// A fake map surface — a CustomPainter road grid plus a pin and/or an
/// animated route line. Stands in everywhere the spec says "map" (address
/// pin-drop, live driver location, territory boundary, order oversight) so
/// the app never needs a real maps SDK / API key.
class MockMapView extends StatefulWidget {
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
  State<MockMapView> createState() => _MockMapViewState();
}

class _MockMapViewState extends State<MockMapView> with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    final content = SizedBox(
      height: widget.height,
      width: double.infinity,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size.infinite,
            painter: _RoadGridPainter(color: palette.divider, background: palette.surfaceMuted),
          ),
          if (widget.showRoute)
            AnimatedBuilder(
              animation: _controller,
              builder: (context, _) => CustomPaint(
                size: Size.infinite,
                painter: _RoutePainter(color: palette.primary, progress: _controller.value),
              ),
            ),
          if (widget.showPin)
            Icon(Icons.location_on_rounded, color: palette.error, size: 36),
        ],
      ),
    );

    if (widget.borderRadius == null) return content;
    return ClipRRect(borderRadius: widget.borderRadius!, child: content);
  }
}

class _RoadGridPainter extends CustomPainter {
  _RoadGridPainter({required this.color, required this.background});
  final Color color;
  final Color background;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = background);
    final paint = Paint()
      ..color = color
      ..strokeWidth = 3;
    for (double x = 0; x < size.width; x += size.width / 5) {
      canvas.drawLine(Offset(x, 0), Offset(x - 30, size.height), paint);
    }
    for (double y = size.height / 4; y < size.height; y += size.height / 3) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y - 20), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _RoadGridPainter oldDelegate) => false;
}

class _RoutePainter extends CustomPainter {
  _RoutePainter({required this.color, required this.progress});
  final Color color;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final start = Offset(size.width * 0.2, size.height * 0.75);
    final end = Offset(size.width * 0.75, size.height * 0.25);
    final paint = Paint()
      ..color = color
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(start, end, paint..color = color.withValues(alpha: 0.35));
    final dot = Offset.lerp(start, end, progress)!;
    canvas.drawCircle(dot, 7, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _RoutePainter oldDelegate) => oldDelegate.progress != progress;
}
