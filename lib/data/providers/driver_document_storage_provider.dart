import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';

import '../models/driver_document.dart';

/// Firebase Storage upload/delete for real driver document images
/// (`driver_document_checklist.dart`) — mirrors
/// `vendor_document_storage_provider.dart`. One object per driver per
/// document type — re-uploading overwrites the previous file.
Reference _driverDocumentRef(String driverId, DriverDocumentType type) =>
    FirebaseStorage.instance.ref('driver_documents/$driverId/${type.name}.jpg');

Future<String> uploadDriverDocument(String driverId, DriverDocumentType type, File file) async {
  final ref = _driverDocumentRef(driverId, type);
  await ref.putFile(file, SettableMetadata(contentType: 'image/jpeg'));
  return ref.getDownloadURL();
}

Future<void> deleteDriverDocumentFile(String driverId, DriverDocumentType type) async {
  try {
    await _driverDocumentRef(driverId, type).delete();
  } on FirebaseException catch (e) {
    if (e.code != 'object-not-found') rethrow;
  }
}
