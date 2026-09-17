import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';

/// Firebase Storage upload/delete for Global Catalogue template photos
/// (`admin_global_product_edit_screen.dart`) — same pattern as
/// `vendor_product_storage_provider.dart`, just not vendor-scoped since a
/// template isn't owned by any one vendor.
Reference _globalProductImageRef(String productId) =>
    FirebaseStorage.instance.ref('global_product_images/$productId.jpg');

Future<String> uploadGlobalProductImage(String productId, File file) async {
  final ref = _globalProductImageRef(productId);
  await ref.putFile(file, SettableMetadata(contentType: 'image/jpeg'));
  return ref.getDownloadURL();
}

Future<void> deleteGlobalProductImage(String productId) async {
  try {
    await _globalProductImageRef(productId).delete();
  } on FirebaseException catch (e) {
    if (e.code != 'object-not-found') rethrow;
  }
}
