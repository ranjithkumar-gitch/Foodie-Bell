import 'package:flutter/material.dart';

/// "Quick Mandi" as text on the sign-in screens (2026-11-20, replacing the
/// lettering and banner images): bold italic white, with a soft shadow so
/// it reads on the green photo background.
class BrandWordmark extends StatelessWidget {
  const BrandWordmark({super.key, this.size = 40});

  final double size;

  @override
  Widget build(BuildContext context) => Text(
    'Quick Mandi',
    key: const Key('brandWordmark'),
    maxLines: 1,
    style: TextStyle(
      color: Colors.white,
      fontSize: size,
      fontWeight: FontWeight.w900,
      fontStyle: FontStyle.italic,
      letterSpacing: -0.5,
      height: 1.1,
      shadows: const [Shadow(color: Color(0x55000000), offset: Offset(0, 2), blurRadius: 8)],
    ),
  );
}
