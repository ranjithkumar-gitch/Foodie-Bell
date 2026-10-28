import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import 'app_network_image.dart';

/// Largest private image the app will download — matches the biggest
/// upload `storage.rules` accepts for a private file.
const _maxPrivateImageBytes = 10 * 1024 * 1024;

/// The bytes of a private Storage file (KYC document, photo-order picture,
/// receipt), fetched by path so `storage.rules` checks every read. Null when
/// the rules refuse it or the file is gone. Download URLs are never used for
/// these: a URL works for anyone who holds it, whatever the rules say.
final privateStorageImageProvider = FutureProvider.family<Uint8List?, String>((ref, path) async {
  try {
    return await FirebaseStorage.instance.ref(path).getData(_maxPrivateImageBytes);
  } on FirebaseException {
    return null;
  }
});

/// An image that may be either public or private:
///  - an `http(s)` URL (catalogue/product photos, storefront covers, and
///    private records written before they moved to paths) is shown as a
///    normal network image;
///  - anything else is a private Storage path, read through the rules.
class StorageImage extends ConsumerWidget {
  const StorageImage({
    super.key,
    required this.source,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
  });

  final String source;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (source.startsWith('http')) {
      return AppNetworkImage(url: source, width: width, height: height, fit: fit, borderRadius: borderRadius);
    }
    final palette = context.colors;
    final bytes = ref.watch(privateStorageImageProvider(source));
    final Widget image = switch (bytes) {
      AsyncData(value: final data?) => Image.memory(
        data,
        width: width,
        height: height,
        fit: fit,
        // Not an image after all (the rules can only check the declared
        // type) — show the placeholder instead of failing.
        errorBuilder: (context, _, _) => _placeholder(palette),
      ),
      AsyncLoading() => Container(width: width, height: height, color: palette.surfaceMuted),
      _ => _placeholder(palette),
    };
    if (borderRadius == null) return image;
    return ClipRRect(borderRadius: borderRadius!, child: image);
  }

  Widget _placeholder(AppPalette palette) => Container(
    width: width,
    height: height,
    color: palette.surfaceMuted,
    alignment: Alignment.center,
    child: Icon(Icons.lock_outline_rounded, color: palette.textMuted, size: 24),
  );
}
