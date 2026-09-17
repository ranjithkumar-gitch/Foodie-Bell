import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';

/// Firebase Storage upload/delete for real product photos
/// (`vendor_add_edit_product_screen.dart`) — same pattern as
/// `vendor_document_storage_provider.dart`. One object per product; a
/// changed photo re-uploads to the same path (overwrites, no orphan) since
/// only the current photo ever matters.
Reference _productImageRef(String vendorId, String productId) =>
    FirebaseStorage.instance.ref('product_images/$vendorId/$productId.jpg');

Future<String> uploadProductImage(
  String vendorId,
  String productId,
  File file,
) async {
  final ref = _productImageRef(vendorId, productId);
  await ref.putFile(file, SettableMetadata(contentType: 'image/jpeg'));
  return ref.getDownloadURL();
}

Future<void> deleteProductImage(String vendorId, String productId) async {
  try {
    await _productImageRef(vendorId, productId).delete();
  } on FirebaseException catch (e) {
    if (e.code != 'object-not-found') rethrow;
  }
}
