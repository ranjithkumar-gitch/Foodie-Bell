import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';

import '../models/vendor_document.dart';

/// Firebase Storage upload/delete for real vendor document images
/// (`vendor_document_checklist.dart`). One object per vendor per document
/// type — re-uploading overwrites the previous file rather than leaving
/// orphans behind, since only the latest submission ever matters.
///
/// KYC files are private (`storage.rules`: the Vendor, their territory's
/// Manager, the Super Admin) and are only ever read by path through the
/// rules (`StorageImage`) — this file never asks for a KYC download URL,
/// since anyone holding one could open the file whatever the rules say.
Reference _vendorDocumentRef(String vendorId, VendorDocumentType type) =>
    FirebaseStorage.instance.ref('vendor_documents/$vendorId/${type.name}.jpg');

/// The public storefront copy of the shop-front photo — a separate object
/// in the public `vendor_covers/` folder, so the KYC original stays private.
Reference _vendorCoverRef(String vendorId) => FirebaseStorage.instance.ref('vendor_covers/$vendorId.jpg');

/// Uploads a KYC document and returns its Storage [path] — what the vendor
/// record keeps (see `Account.documentPaths`). For the shop-front photo it
/// also publishes the storefront copy and returns its download [coverUrl].
Future<({String path, String? coverUrl})> uploadVendorDocument(String vendorId, VendorDocumentType type, File file) async {
  final ref = _vendorDocumentRef(vendorId, type);
  await ref.putFile(file, SettableMetadata(contentType: 'image/jpeg'));
  String? coverUrl;
  if (type == VendorDocumentType.shopFrontPhoto) {
    final cover = _vendorCoverRef(vendorId);
    await cover.putFile(file, SettableMetadata(contentType: 'image/jpeg'));
    coverUrl = await cover.getDownloadURL();
  }
  return (path: ref.fullPath, coverUrl: coverUrl);
}

Future<void> deleteVendorDocumentFile(String vendorId, VendorDocumentType type) async {
  await _deleteIfPresent(_vendorDocumentRef(vendorId, type));
  if (type == VendorDocumentType.shopFrontPhoto) await _deleteIfPresent(_vendorCoverRef(vendorId));
}

Future<void> _deleteIfPresent(Reference ref) async {
  try {
    await ref.delete();
  } on FirebaseException catch (e) {
    if (e.code != 'object-not-found') rethrow;
  }
}
