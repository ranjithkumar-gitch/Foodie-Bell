import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/branding/branding_controller.dart';

/// The app logo, with an optional occasion overlay
/// ([activeBrandThemeProvider]'s `logoOverlayUrl`) drawn on top of the base
/// asset — every literal `Image.asset('assets/images/app_logo.png')` call
/// site should go through this instead, so a QuickyAdmin-activated occasion
/// theme shows up everywhere the logo renders (splash, sign-in, order
/// success, ...) without each screen wiring branding itself. Fails silent:
/// a broken/missing overlay image just leaves the base logo showing, never
/// an error icon.
class BrandedLogo extends ConsumerWidget {
  const BrandedLogo({super.key, this.size, this.fit = BoxFit.contain});

  final double? size;
  final BoxFit fit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overlayUrl = ref.watch(activeBrandThemeProvider)?.logoOverlayUrl;
    return Stack(
      alignment: Alignment.center,
      fit: StackFit.passthrough,
      children: [
        Image.asset('assets/images/app_logo.png', width: size, height: size, fit: fit),
        if (overlayUrl != null)
          CachedNetworkImage(
            imageUrl: overlayUrl,
            width: size,
            height: size,
            fit: fit,
            errorWidget: (_, _, _) => const SizedBox.shrink(),
            placeholder: (_, _) => const SizedBox.shrink(),
          ),
      ],
    );
  }
}
