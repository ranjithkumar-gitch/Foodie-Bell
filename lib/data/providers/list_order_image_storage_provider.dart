import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';

/// Firebase Storage upload for a User's photo-order photos
/// (`list_order_capture_screen.dart`) and the Vendor's receipt for them.
///
/// Both are private to that Customer and that Vendor (`storage.rules`
/// checks the two ids in the path), so the request keeps Storage *paths*,
/// not download URLs — screens read them through the rules with
/// `StorageImage`. Each upload gets a timestamp since a User can send the
/// same vendor more than one request over time.
Future<String> _upload(String path, File file) async {
  final ref = FirebaseStorage.instance.ref(path);
  await ref.putFile(file, SettableMetadata(contentType: 'image/jpeg'));
  return ref.fullPath;
}

/// Uploads every photo the User captured for one request, in order, and
/// returns their Storage paths.
Future<List<String>> uploadListOrderImages(String userId, String vendorId, List<File> files) async {
  final stamp = DateTime.now().millisecondsSinceEpoch;
  return [
    for (var i = 0; i < files.length; i++)
      await _upload('list_order_images/$userId/$vendorId/${stamp}_$i.jpg', files[i]),
  ];
}

/// Uploads the Vendor's photo of the receipt taken when they confirm a paid
/// request (`vendor_order_queue_screen.dart`) and returns its Storage path.
Future<String> uploadListOrderReceiptImage(String vendorId, String userId, File file) =>
    _upload('list_order_receipts/$vendorId/$userId/${DateTime.now().millisecondsSinceEpoch}.jpg', file);
