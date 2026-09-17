import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/brand_theme.dart';
import '../../data/providers/brand_theme_cache.dart';
import '../../data/providers/firestore_branding_provider.dart';
import 'app_icon_channel.dart';

/// The brand theme loaded from local storage at startup (`main.dart`,
/// before `runApp`) — overridden via `ProviderScope(overrides: [...])` so
/// the very first frame already reflects the last-known theme instead of
/// flashing default branding while [brandThemeStreamProvider] connects.
final cachedBrandThemeProvider = Provider<BrandTheme?>((ref) => null);

/// The theme every consumer (app theme, logo, dashboard banner) should
/// actually render: the live Firestore value once it's loaded, falling
/// back to the cached one while still loading or if the stream errors
/// (offline, etc.) — never clears branding just because the network blipped.
final activeBrandThemeProvider = Provider<BrandTheme?>((ref) {
  final live = ref.watch(brandThemeStreamProvider);
  return live.when(
    data: (theme) => theme,
    loading: () => ref.watch(cachedBrandThemeProvider),
    error: (_, _) => ref.watch(cachedBrandThemeProvider),
  );
});

/// Wired once at the app root (`app.dart`) — best-effort precaches a newly
/// received theme's images (so the swap doesn't flash unstyled network
/// images mid-load) then persists it as the new cold-start cache. Never
/// blocks: a slow/broken image still lets the theme apply, it just skips
/// the head start.
void listenForBrandThemeChanges(BuildContext context, WidgetRef ref) {
  ref.listen(brandThemeStreamProvider, (previous, next) {
    final theme = next.valueOrNull;
    final prevTheme = previous?.valueOrNull;
    // Bail out only when nothing this listener actually acts on changed —
    // comparing just `occasionId` would miss an Admin editing images/icon
    // on the *same* still-active occasion (a real Firestore update, just
    // not one that swaps which occasion is active).
    final unchanged =
        prevTheme?.occasionId == theme?.occasionId &&
        prevTheme?.logoOverlayUrl == theme?.logoOverlayUrl &&
        prevTheme?.dashboardThemeUrl == theme?.dashboardThemeUrl &&
        prevTheme?.appIconKey == theme?.appIconKey;
    if (unchanged) return;

    Future<void> precache(String? url) async {
      if (url == null) return;
      try {
        await precacheImage(CachedNetworkImageProvider(url), context);
      } catch (_) {
        // Best-effort — a broken/slow image shouldn't hold up applying the
        // rest of the theme.
      }
    }

    // The home-screen icon switch is independent of the image precache —
    // it doesn't need the network at all, so it isn't worth delaying behind
    // (or bundling into) that timeout.
    setAppIcon(theme?.appIconKey);

    Future(() async {
      await Future.wait([
        precache(theme?.logoOverlayUrl),
        precache(theme?.dashboardThemeUrl),
      ]).timeout(const Duration(seconds: 3), onTimeout: () => const []);
      await saveCachedBrandTheme(theme);
    });
  });
}
