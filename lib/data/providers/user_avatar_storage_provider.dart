import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';

/// Firebase Storage upload for a User's own profile photo
/// (`user_profile_edit_screen.dart`) — mirrors
/// `vendor_document_storage_provider.dart`/`driver_document_storage_provider.dart`.
/// One object per user — re-uploading overwrites the previous photo rather
/// than leaving orphans behind, since only the latest photo ever matters.
Reference _userAvatarRef(String userId) => FirebaseStorage.instance.ref('user_avatars/$userId.jpg');

Future<String> uploadUserAvatar(String userId, File file) async {
  final ref = _userAvatarRef(userId);
  await ref.putFile(file, SettableMetadata(contentType: 'image/jpeg'));
  return ref.getDownloadURL();
}
