import 'package:flutter/material.dart';

/// A small glowing status indicator for a list row — solid, steadily-glowing
/// green when live/active, pulsing amber when not, so an inactive
/// vendor/driver visually stands out at a glance without reading a status
/// chip.
class StatusBulb extends StatefulWidget {
  const StatusBulb({super.key, required this.isLive, this.size = 10});

  final bool isLive;
  final double size;

  @override
  State<StatusBulb> createState() => _StatusBulbState();
}

class _StatusBulbState extends State<StatusBulb> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isLive) {
      return Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          color: Colors.green,
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: Colors.green.withValues(alpha: 0.65), blurRadius: 6, spreadRadius: 1.5)],
        ),
      );
    }
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value;
        return Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            color: Colors.amber,
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: Colors.amber.withValues(alpha: 0.35 + t * 0.45), blurRadius: 4 + t * 8, spreadRadius: 1 + t * 2)],
          ),
        );
      },
    );
  }
}
