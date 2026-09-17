import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';

/// Firebase Storage upload for a Vendor's promotion banner image
/// (`vendor_promotions_screen.dart`'s "Request Promotion" sheet) — mirrors
/// `user_avatar_storage_provider.dart`/`manager_avatar_storage_provider.dart`.
/// Keyed by vendor id *and* a timestamp, unlike those single-object-per-user
/// uploaders: a vendor can submit more than one promotion request over time
/// (a rejected one, then a new one), and each request is its own Firestore
/// doc — overwriting a fixed `{vendorId}.jpg` path would silently swap the
/// image out from under an older request that still references the same URL.
Reference _promotionImageRef(String vendorId) =>
    FirebaseStorage.instance.ref('promotion_images/${vendorId}_${DateTime.now().millisecondsSinceEpoch}.jpg');

Future<String> uploadPromotionImage(String vendorId, File file) async {
  final ref = _promotionImageRef(vendorId);
  await ref.putFile(file, SettableMetadata(contentType: 'image/jpeg'));
  return ref.getDownloadURL();
}
