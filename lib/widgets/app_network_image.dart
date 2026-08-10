import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Network image with a shimmer-style placeholder and graceful fallback.
class AppNetworkImage extends StatelessWidget {
  const AppNetworkImage({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
  });

  final String url;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    final image = CachedNetworkImage(
      imageUrl: url,
      width: width,
      height: height,
      fit: fit,
      placeholder: (context, _) => Container(
        width: width,
        height: height,
        color: AppColors.surfaceMuted,
      ),
      errorWidget: (context, _, _) => Container(
        width: width,
        height: height,
        color: AppColors.surfaceMuted,
        alignment: Alignment.center,
        child: const Icon(Icons.restaurant_rounded, color: AppColors.textMuted, size: 28),
      ),
    );

    if (borderRadius == null) return image;
    return ClipRRect(borderRadius: borderRadius!, child: image);
  }
}
