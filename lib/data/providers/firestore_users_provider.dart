import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/account.dart';

/// Real, persistent User identities — unlike Vendor/Driver (created by a
/// Manager first, then claimed at login) or Manager (created by Admin),
/// User self-registers directly: `auth_register_screen.dart` collects
/// name/email, `auth_terms_screen.dart` writes the doc once phone
/// verification succeeds. No Firebase Auth credential is tied to the doc
/// id either, same reasoning as Vendor/Driver
/// (`firestore_vendors_provider.dart`'s doc comment) — User authenticates
/// by phone+OTP, so this doc is looked up by phone at login instead.
///
/// Deliberately minimal compared to `firestore_vendors_provider.dart`/
/// `firestore_drivers_provider.dart`: no live stream, merge, or
/// Manager/Admin directory screen depends on User today, so there's no
/// `firestoreUsersProvider`/`mergeUserAccounts` — just what registration
/// and login actually need.
const usersCollectionPath = 'users';

CollectionReference<Map<String, dynamic>> get usersCollection =>
    FirebaseFirestore.instance.collection(usersCollectionPath);

Map<String, dynamic> accountToUserDoc(Account account) => {
  'name': account.name,
  'phone': account.phone,
  'email': account.email?.toLowerCase(),
  'avatarUrl': account.avatarUrl,
  'status': account.status.name,
  'languageCode': account.languageCode,
};

Account _accountFromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
  final data = doc.data();
  return Account(
    id: doc.id,
    role: AppRole.user,
    name: data['name'] as String? ?? '',
    phone: data['phone'] as String? ?? '',
    email: data['email'] as String?,
    avatarUrl: data['avatarUrl'] as String?,
    status: AccountStatus.values.byName(data['status'] as String? ?? 'active'),
    languageCode: data['languageCode'] as String?,
  );
}

/// Admin's User Directory (`user_directory_screen.dart`/`user_detail_screen.dart`)
/// — real, live data instead of the in-memory `mockAccountsProvider`, same
/// pattern `firestoreVendorsProvider` uses. Sorted client-side rather than
/// via `.orderBy('createdAt')` since Firestore excludes any doc missing
/// that field entirely (see `firestore_vendors_provider.dart`'s doc comment
/// for the bug this avoids).
final firestoreUsersProvider = StreamProvider<List<Account>>((ref) {
  return usersCollection.snapshots().map((snapshot) {
    final accounts = snapshot.docs.map(_accountFromDoc).toList();
    final createdAtById = {for (final doc in snapshot.docs) doc.id: doc.data()['createdAt'] as Timestamp?};
    accounts.sort((a, b) {
      final aTime = createdAtById[a.id];
      final bTime = createdAtById[b.id];
      if (aTime == null && bTime == null) return 0;
      if (aTime == null) return 1;
      if (bTime == null) return -1;
      return bTime.compareTo(aTime);
    });
    return accounts;
  });
});

/// One-shot lookup for phone-login/session-resolution
/// (`auth_navigation.dart`, `splash_screen.dart`) — mirrors
/// `findFirestoreVendorByPhone`/`findFirestoreDriverByPhone`.
Future<Account?> findFirestoreUserByPhone(String phone) async {
  final normalized = phone.replaceFirst(RegExp(r'^\+91'), '');
  final snapshot = await usersCollection.where('phone', isEqualTo: normalized).limit(1).get();
  if (snapshot.docs.isEmpty) return null;
  return _accountFromDoc(snapshot.docs.first);
}

/// User editing their own name/email/avatar (`user_profile_edit_screen.dart`).
Future<void> updateUserProfile(String userId, {required String name, String? email, String? avatarUrl}) => usersCollection.doc(userId).update({
  'name': name,
  'email': email,
  'avatarUrl': ?avatarUrl,
});

/// User's own language switcher (`profile_screen.dart`) — 'en' or 'te'.
Future<void> setUserLanguage(String userId, String languageCode) => usersCollection.doc(userId).update({'languageCode': languageCode});
