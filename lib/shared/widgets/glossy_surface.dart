import 'package:flutter/material.dart';

/// The glossy-card look shared by the sign-in screen's intro carousel, CTA
/// button, and (white variant) input fields — a gradient base, a soft
/// sheen across the top, and a drop shadow to lift the surface off the
/// page's own green background (without the shadow a flat green-on-green
/// card would have no visible edge at all). Deliberately a plain linear
/// top-to-transparent sheen rather than a rotated floating highlight —
/// that scales cleanly whether this wraps a tall carousel card or a
/// 56px-tall input field, which a fixed-position highlight blob wouldn't.
///
/// [light] swaps the green gradient for a white/off-white one — used for
/// input fields (`AppTextField`'s `glossy` flag), where green-on-green
/// text would be unreadable and the fields need to stay visually distinct
/// from the carousel/button as "the thing you type into".
class GlossySurface extends StatelessWidget {
  const GlossySurface({
    super.key,
    required this.child,
    this.borderRadius = 22,
    this.padding,
    this.light = false,
  });

  final Widget child;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;
  final bool light;

  static const _greenGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF4CAF6D), Color(0xFF1B8A3D), Color(0xFF0F5C26)],
  );

  static const _whiteGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFFFFFF), Color(0xFFF4F6F1)],
  );

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: light ? 0.14 : 0.22),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: Stack(
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: light ? _whiteGradient : _greenGradient,
                ),
              ),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: light
                        ? [
                            Colors.white.withValues(alpha: 0.9),
                            Colors.white.withValues(alpha: 0.0),
                          ]
                        : [
                            Colors.white.withValues(alpha: 0.22),
                            Colors.white.withValues(alpha: 0.0),
                          ],
                    stops: const [0.0, 0.55],
                  ),
                ),
              ),
            ),
            padding == null ? child : Padding(padding: padding!, child: child),
          ],
        ),
      ),
    );
  }
}
