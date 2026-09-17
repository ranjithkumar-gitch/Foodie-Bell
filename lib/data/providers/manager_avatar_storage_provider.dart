import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';

/// Firebase Storage upload for a Manager's own profile photo
/// (`manager_profile_screen.dart`) — mirrors `user_avatar_storage_provider.dart`.
/// One object per manager — re-uploading overwrites the previous photo
/// rather than leaving orphans behind, since only the latest photo ever matters.
Reference _managerAvatarRef(String managerId) => FirebaseStorage.instance.ref('manager_avatars/$managerId.jpg');

Future<String> uploadManagerAvatar(String managerId, File file) async {
  final ref = _managerAvatarRef(managerId);
  await ref.putFile(file, SettableMetadata(contentType: 'image/jpeg'));
  return ref.getDownloadURL();
}
