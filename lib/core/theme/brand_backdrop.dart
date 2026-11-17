import 'package:flutter/material.dart';

import 'app_colors.dart';

/// The home page's background, everywhere (owner request, 2026-11-17): the
/// normal background with a soft brand-green wash across the top that fades
/// out by halfway down the screen. Painted behind every page by
/// [BrandPageTransitionsBuilder]; screens' [Scaffold]s and [AppBar]s are
/// transparent (`app_theme.dart`) so it shows through. Home paints its own
/// copy (it also layers an occasion's banner image under the wash).
class BrandBackdrop extends StatelessWidget {
  const BrandBackdrop({super.key, required this.child});
  final Widget child;

  /// The wash, as on Home (`home_screen.dart`).
  static LinearGradient washOf(AppPalette palette) => LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      palette.primaryLight.withValues(alpha: 0.22),
      palette.primaryLight.withValues(alpha: 0.05),
      palette.background,
    ],
    stops: const [0.0, 0.22, 0.5],
  );

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    // Opaque (background first), so pages never show through each other
    // while one slides over another.
    return ColoredBox(
      color: palette.background,
      child: DecoratedBox(decoration: BoxDecoration(gradient: washOf(palette)), child: child),
    );
  }
}

/// Wraps a page transition so the page sits on [BrandBackdrop]; the
/// animation itself is [inner]'s (the platform's usual one).
class BrandPageTransitionsBuilder extends PageTransitionsBuilder {
  const BrandPageTransitionsBuilder(this.inner);
  final PageTransitionsBuilder inner;

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => inner.buildTransitions(route, context, animation, secondaryAnimation, BrandBackdrop(child: child));
}

/// The platform's default page transitions, each on [BrandBackdrop].
PageTransitionsTheme brandPageTransitionsTheme() => PageTransitionsTheme(
  builders: {
    for (final e in const PageTransitionsTheme().builders.entries) e.key: BrandPageTransitionsBuilder(e.value),
  },
);
