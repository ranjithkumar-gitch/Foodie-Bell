import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// The sign-in screens' one full-screen illustration (2026-11-20,
/// `login_bg1.webp`, a full-screen picture replacing the old two-image pair):
/// the "Quick Mandi" title is painted into its sky, a plain green band in the
/// middle holds the card, and the "Local Stores · Faster Delivery · Stronger
/// Communities" strip runs along the bottom.
///
/// Covers the screen anchored to the top, so the title always shows; on a
/// screen wider than the picture's 941×1672 shape the bottom is what gets
/// cropped.
class AuthBackground extends StatelessWidget {
  const AuthBackground({super.key});

  static const asset = 'assets/images/login_bg1.webp';
  static const _width = 941.0;
  static const _height = 1672.0;

  /// Where the bottom strip (its skyline) starts in the picture's pixels.
  static const _footerTop = 1340.0;

  @override
  Widget build(BuildContext context) => const Positioned.fill(
    child: Image(image: AssetImage(asset), fit: BoxFit.cover, alignment: Alignment.topCenter),
  );
}

/// How much room to leave under the card, inside a [SafeArea], so it ends
/// just above the picture's bottom strip — at least [min].
double authFooterReserve(BuildContext context, {double min = 16}) {
  final size = MediaQuery.sizeOf(context);
  final scale = math.max(size.width / AuthBackground._width, size.height / AuthBackground._height);
  final footerTop = AuthBackground._footerTop * scale;
  final reserve = size.height - footerTop - MediaQuery.paddingOf(context).bottom;
  return math.max(reserve, min);
}
