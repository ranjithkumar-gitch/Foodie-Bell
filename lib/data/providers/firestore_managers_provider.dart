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
  // Lowercased so it compares reliably (Firestore has no case-insensitive
  // match) regardless of how the email was capitalized when typed on the
  // "Add Manager" form.
  'email': account.email?.toLowerCase(),
  'managerCode': account.managerCode,
  'territory': account.territory,
  'territoryId': account.territoryId,
  'territoryFee': account.territoryFee,
  'status': account.status.name,
  'avatarUrl': account.avatarUrl,
};

Account _accountFromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
  final data = doc.data() ?? const <String, dynamic>{};
  return Account(
    id: doc.id,
    role: AppRole.manager,
    name: data['name'] as String? ?? '',
    phone: data['phone'] as String? ?? '',
    email: data['email'] as String?,
    managerCode: data['managerCode'] as String?,
    territory: data['territory'] as String?,
    territoryId: data['territoryId'] as String?,
    territoryFee: (data['territoryFee'] as num?)?.toDouble() ?? 200000,
    status: AccountStatus.values.byName(data['status'] as String? ?? 'active'),
    avatarUrl: data['avatarUrl'] as String?,
    deletedAt: (data['deletedAt'] as Timestamp?)?.toDate(),
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
}) => _managerBankDoc(managerId).set({
  'bankAccountHolder': accountHolder,
  'bankAccountNumber': accountNumber,
  'bankIfsc': ifsc,
}, SetOptions(merge: true));

/// Bank/payout details live in `managers/{id}/private/bank` — readable only
/// by that Manager and the Super Admin — rather than on the Manager's own
/// doc, which every role reads for support contact details.
DocumentReference<Map<String, dynamic>> _managerBankDoc(String managerId) =>
    managersCollection.doc(managerId).collection('private').doc('bank');

/// One-shot read of a single Manager account by doc id — what
/// `account_resolver.dart` loads once the `resolveSession` Cloud Function
/// has said which account a verified phone sign-in belongs to. A direct
/// document read, which the per-account Firestore rules allow for the
/// account's own owner.
Future<Account?> findFirestoreManagerById(String id) async {
  final snapshot = await managersCollection.doc(id).get();
  if (!snapshot.exists) return null;
  final bank = (await _managerBankDoc(id).get()).data() ?? const <String, dynamic>{};
  return _accountFromDoc(snapshot).copyWith(
    bankAccountHolder: bank['bankAccountHolder'] as String?,
    bankAccountNumber: bank['bankAccountNumber'] as String?,
    bankIfsc: bank['bankIfsc'] as String?,
  );
}
