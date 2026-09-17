import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/account.dart';

/// Manager Directory's real, persistent data source — replaces the
/// in-memory `mockAccountsProvider` (which resets on every app restart) for
/// Manager accounts specifically. Firestore doc id == the Manager's real
/// Firebase Auth uid (see `manager_create_screen.dart`), so the credential
/// and the profile record are directly linked. Purely a read of whatever's
/// actually in Firestore — no demo/mock records are seeded into it.
const managersCollectionPath = 'managers';

CollectionReference<Map<String, dynamic>> get managersCollection =>
    FirebaseFirestore.instance.collection(managersCollectionPath);

Map<String, dynamic> accountToManagerDoc(Account account) => {
  'name': account.name,
  'phone': account.phone,
  // Lowercased so `findFirestoreManagerByEmail`'s query (Firestore has no
  // case-insensitive match) reliably finds it regardless of how the email
  // was capitalized when typed on the "Add Manager" form.
  'email': account.email?.toLowerCase(),
  'managerCode': account.managerCode,
  'territory': account.territory,
  'territoryFee': account.territoryFee,
  'status': account.status.name,
  'avatarUrl': account.avatarUrl,
  'bankAccountHolder': account.bankAccountHolder,
  'bankAccountNumber': account.bankAccountNumber,
  'bankIfsc': account.bankIfsc,
};

Account _accountFromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
  final data = doc.data();
  return Account(
    id: doc.id,
    role: AppRole.manager,
    name: data['name'] as String? ?? '',
    phone: data['phone'] as String? ?? '',
    email: data['email'] as String?,
    managerCode: data['managerCode'] as String?,
    territory: data['territory'] as String?,
    territoryFee: (data['territoryFee'] as num?)?.toDouble() ?? 200000,
    status: AccountStatus.values.byName(data['status'] as String? ?? 'active'),
    avatarUrl: data['avatarUrl'] as String?,
    deletedAt: (data['deletedAt'] as Timestamp?)?.toDate(),
    bankAccountHolder: data['bankAccountHolder'] as String?,
    bankAccountNumber: data['bankAccountNumber'] as String?,
    bankIfsc: data['bankIfsc'] as String?,
  );
}

final firestoreManagersProvider = StreamProvider<List<Account>>((ref) {
  return managersCollection
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map(
        (snapshot) => snapshot.docs
            .map(_accountFromDoc)
            .where((a) => a.deletedAt == null)
            .toList(),
      );
});

/// Soft-deletes a Manager (Admin-only, `manager_directory_screen.dart`/
/// `manager_detail_screen.dart`) — the caller is responsible for freeing any
/// Territory this Manager held (see those screens' `_delete`), since that's
/// a `territories` collection write and this file has no dependency on
/// `firestore_territories_provider.dart` to keep the two decoupled.
Future<void> softDeleteManager(String managerId) => managersCollection
    .doc(managerId)
    .update({'deletedAt': FieldValue.serverTimestamp()});

/// Manager updating their own profile photo (`manager_profile_screen.dart`)
/// — mirrors `updateUserProfile`'s `avatarUrl` handling.
Future<void> updateManagerAvatar(String managerId, String avatarUrl) =>
    managersCollection.doc(managerId).update({'avatarUrl': avatarUrl});

/// Admin revising a Manager's territory fee (`manager_detail_screen.dart`)
/// — unlike Vendor's rebate %, this stays editable indefinitely, not just
/// at creation.
Future<void> updateManagerTerritoryFee(String managerId, double territoryFee) =>
    managersCollection.doc(managerId).update({'territoryFee': territoryFee});

/// Manager updating their own bank/payout details
/// (`manager_profile_screen.dart`'s "Bank & payout details" form).
Future<void> updateManagerBankDetails(
  String managerId, {
  required String accountHolder,
  required String accountNumber,
  required String ifsc,
}) => managersCollection.doc(managerId).update({
  'bankAccountHolder': accountHolder,
  'bankAccountNumber': accountNumber,
  'bankIfsc': ifsc,
});

/// One-shot lookup for `splash_screen.dart` session restore, and for any
/// Manager whose Firebase Auth session still carries an email (accounts
/// provisioned before Manager login switched to phone+OTP, or Admin ever
/// signing in this same way) — a Manager created in a *previous* session
/// only lives in Firestore, not the in-memory `mockAccountsProvider` (which
/// resets on restart), so session-resolution needs a direct query fallback
/// rather than relying on `firestoreManagersProvider`'s stream having
/// already been watched and populated by some other screen. Not used by
/// the sign-in screen itself anymore — see [findFirestoreManagerByPhone].
Future<Account?> findFirestoreManagerByEmail(String email) async {
  final normalized = email.trim().toLowerCase();
  final snapshot = await managersCollection
      .where('email', isEqualTo: normalized)
      .limit(1)
      .get();
  if (snapshot.docs.isEmpty) return null;
  return _accountFromDoc(snapshot.docs.first);
}

/// Manager's phone-keyed counterpart to [findFirestoreManagerByEmail] —
/// the unified sign-in screen (`auth_login_screen.dart`) now takes only a
/// phone number for every role, Manager included, matching how
/// Vendor/Driver/User already log in (see `findFirestoreVendorByPhone`'s
/// doc comment). Manager's own Firestore doc has carried a `phone` field
/// since it was first created (`accountToManagerDoc` above), so no backfill
/// was needed to support this.
Future<Account?> findFirestoreManagerByPhone(String phone) async {
  final normalized = phone.replaceFirst(RegExp(r'^\+91'), '');
  final snapshot = await managersCollection
      .where('phone', isEqualTo: normalized)
      .limit(1)
      .get();
  if (snapshot.docs.isEmpty) return null;
  return _accountFromDoc(snapshot.docs.first);
}
