import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A viewable URL for a KYC document stored by Storage path
/// (`Account.documentPaths`/`driverDocumentPaths`). Resolving it is itself
/// the access check: Storage only hands out a download URL to someone
/// `storage.rules` lets read the file — the account owner, their territory's
/// Manager, or the Super Admin. Values that are already URLs (records not
/// yet migrated, or the in-memory mock store) are passed through as-is.
final kycDocumentUrlProvider = FutureProvider.family<String?, String>((ref, pathOrUrl) async {
  if (pathOrUrl.startsWith('http')) return pathOrUrl;
  try {
    return await FirebaseStorage.instance.ref(pathOrUrl).getDownloadURL();
  } on FirebaseException {
    return null;
  }
});

/// Watches [kycDocumentUrlProvider] for an optional path — for widgets that
/// show a thumbnail only once a document exists.
String? watchKycDocumentUrl(WidgetRef ref, String? pathOrUrl) =>
    pathOrUrl == null ? null : ref.watch(kycDocumentUrlProvider(pathOrUrl)).valueOrNull;
