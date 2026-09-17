import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'branded_logo.dart';

/// [BrandedLogo] with a repeating coin-flip animation — a 3D rotation
/// around the vertical axis (not a flat 2D spin) so the circular logo
/// genuinely reads as a flipping coin. Each flip eases in and out
/// (`Curves.easeInOutSine`: starts slow, speeds up through the middle,
/// slows back down to finish) rather than spinning at a constant rate,
/// then holds still for a beat before the next flip — a coin that's just
/// been flipped and is settling, repeating, rather than a wheel spinning
/// continuously.
class CoinFlipLogo extends StatefulWidget {
  const CoinFlipLogo({super.key, this.size});

  final double? size;

  @override
  State<CoinFlipLogo> createState() => _CoinFlipLogoState();
}

class _CoinFlipLogoState extends State<CoinFlipLogo>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  )..repeat();

  // 0 -> 85% of each lap is the actual flip (eased slow-fast-slow); the
  // remaining 15% holds at a full rotation (visually identical to 0, so the
  // loop restart is seamless) as the "settle" beat before the next flip.
  late final Animation<double> _angle = TweenSequence<double>([
    TweenSequenceItem(
      weight: 85,
      tween: Tween(
        begin: 0.0,
        end: 2 * math.pi,
      ).chain(CurveTween(curve: Curves.easeInOutSine)),
    ),
    TweenSequenceItem(weight: 15, tween: ConstantTween(2 * math.pi)),
  ]).animate(_controller);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _angle,
      child: BrandedLogo(size: widget.size),
      builder: (context, child) {
        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.0015)
            ..rotateY(_angle.value),
          child: child,
        );
      },
    );
  }
}
