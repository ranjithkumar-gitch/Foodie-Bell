import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';

import '../models/vendor_document.dart';

/// Firebase Storage upload/delete for real vendor document images
/// (`vendor_document_checklist.dart`). One object per vendor per document
/// type — re-uploading overwrites the previous file rather than leaving
/// orphans behind, since only the latest submission ever matters.
Reference _vendorDocumentRef(String vendorId, VendorDocumentType type) =>
    FirebaseStorage.instance.ref('vendor_documents/$vendorId/${type.name}.jpg');

/// Uploads a KYC document and returns its Storage [path] — what the vendor
/// record keeps (see `Account.documentPaths`) — plus a download [url], used
/// only for the shop-front photo's public storefront copy.
Future<({String path, String url})> uploadVendorDocument(String vendorId, VendorDocumentType type, File file) async {
  final ref = _vendorDocumentRef(vendorId, type);
  await ref.putFile(file, SettableMetadata(contentType: 'image/jpeg'));
  return (path: ref.fullPath, url: await ref.getDownloadURL());
}

Future<void> deleteVendorDocumentFile(String vendorId, VendorDocumentType type) async {
  try {
    await _vendorDocumentRef(vendorId, type).delete();
  } on FirebaseException catch (e) {
    if (e.code != 'object-not-found') rethrow;
  }
}
