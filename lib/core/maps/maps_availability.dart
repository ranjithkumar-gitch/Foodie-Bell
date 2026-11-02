import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/app_colors.dart';

/// Whether this build can show Google Maps (Phase I.8 Batch 3).
///
/// iOS: the Maps SDK raises as soon as a map is created without an API key,
/// so `AppDelegate.swift` reports over `com.quickmandi/maps_config` whether
/// it received `GMSApiKey` (from the git-ignored `ios/Flutter/Secrets.xcconfig`)
/// at launch. Any failure to ask counts as "not available" — a placeholder,
/// never a crash. Android carries its key in the manifest, so it's always
/// available there.
const mapsConfigChannel = MethodChannel('com.quickmandi/maps_config');

Future<bool> mapsConfigured({TargetPlatform? platform, bool isWeb = kIsWeb}) async {
  final p = platform ?? defaultTargetPlatform;
  if (isWeb || p != TargetPlatform.iOS) return true;
  try {
    return await mapsConfigChannel.invokeMethod<bool>('isConfigured') ?? false;
  } catch (_) {
    return false;
  }
}

final mapsAvailableProvider = FutureProvider<bool>((ref) => mapsConfigured());

/// Shows [child] (a `GoogleMap`) only when maps are available; otherwise a
/// placeholder the same size, so the rest of the screen keeps working.
class MapsGate extends ConsumerWidget {
  const MapsGate({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final available = ref.watch(mapsAvailableProvider);
    return available.when(
      data: (ok) => ok ? child : const _MapPlaceholder(),
      loading: () => const _MapPlaceholder(loading: true),
      error: (_, _) => const _MapPlaceholder(),
    );
  }
}

class _MapPlaceholder extends StatelessWidget {
  const _MapPlaceholder({this.loading = false});
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    return Container(
      key: const Key('mapUnavailable'),
      color: palette.surfaceMuted,
      alignment: Alignment.center,
      child: loading
          ? const CircularProgressIndicator()
          : Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.map_outlined, color: palette.textMuted, size: 36),
              const SizedBox(height: 8),
              Text('Map unavailable', style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w600)),
            ]),
    );
  }
}
