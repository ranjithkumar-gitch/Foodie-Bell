import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';

/// Firebase Storage upload for a User's photo-order photos
/// (`list_order_capture_screen.dart`) — mirrors
/// `promotion_image_storage_provider.dart`: keyed by vendor id *and* a
/// timestamp since a User can submit more than one request to the same
/// vendor over time, each its own Firestore doc.
Reference _listOrderImageRef(String vendorId, int index) => FirebaseStorage.instance.ref(
  'list_order_images/${vendorId}_${DateTime.now().millisecondsSinceEpoch}_$index.jpg',
);

Future<String> _uploadListOrderImage(String vendorId, File file, int index) async {
  final ref = _listOrderImageRef(vendorId, index);
  await ref.putFile(file, SettableMetadata(contentType: 'image/jpeg'));
  return ref.getDownloadURL();
}

/// Uploads every photo the User captured for one request, in order.
Future<List<String>> uploadListOrderImages(String vendorId, List<File> files) async {
  final urls = <String>[];
  for (var i = 0; i < files.length; i++) {
    urls.add(await _uploadListOrderImage(vendorId, files[i], i));
  }
  return urls;
}

/// Uploads the Vendor's photo of the receipt taken when they confirm a paid
/// request (`vendor_order_queue_screen.dart`) — same scheme, separate
/// prefix so receipts and customer photos never collide.
Future<String> uploadListOrderReceiptImage(String vendorId, File file) async {
  final ref = FirebaseStorage.instance.ref(
    'list_order_receipts/${vendorId}_${DateTime.now().millisecondsSinceEpoch}.jpg',
  );
  await ref.putFile(file, SettableMetadata(contentType: 'image/jpeg'));
  return ref.getDownloadURL();
}
