import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/account.dart';
import '../models/vendor_document.dart';
import 'mock_accounts_provider.dart';

/// Real, persistent Vendor identities created directly by a Manager (see
/// `manager_vendor_create_screen.dart`) — same Firestore pattern as
/// `firestore_managers_provider.dart`/`firestore_territories_provider.dart`.
///
/// Unlike Manager (whose Firebase Auth credential is still provisioned as
/// email+password by Admin in QuickyAdmin, even though Manager signs in by
/// phone+OTP the same as everyone else now — see `auth_login_screen.dart`),
/// Vendor/Driver have no provisioned Firebase Auth credential at all: the
/// client SDK has no way to provision one programmatically, since there's
/// no "create a phone-verified user" call the way
/// `createUserWithEmailAndPassword` exists for email. So a Manager-created
/// Vendor gets a real Firestore *profile* record here (territory, Manager
/// Code, category, active status) but no Firebase Auth credential; they
/// still sign in the same way every other Vendor does, at `/auth/phone`,
/// with whatever phone number this record was created against (a real
/// number, or one of the Firebase Console "test numbers" set up for the
/// project — the same pre-existing constraint phone auth already has for
/// every role in this build).
const vendorsCollectionPath = 'vendors';

CollectionReference<Map<String, dynamic>> get vendorsCollection =>
    FirebaseFirestore.instance.collection(vendorsCollectionPath);

Map<String, dynamic> accountToVendorDoc(Account account) => {
  'name': account.name,
  'phone': account.phone,
  'email': account.email?.toLowerCase(),
  'managerCode': account.managerCode,
  'territory': account.territory,
  'category': account.category,
  'subCategory': account.subCategory,
  'ownerName': account.ownerName,
  'rebatePercent': account.rebatePercent,
  'documentStatuses': account.documentStatuses.map(
    (type, status) => MapEntry(type.name, status.name),
  ),
  'documentUrls': account.documentUrls.map(
    (type, url) => MapEntry(type.name, url),
  ),
  'status': account.status.name,
  'isOpen': account.isOpen,
};

Account _accountFromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
  final data = doc.data();
  final rawDocumentStatuses =
      data['documentStatuses'] as Map<String, dynamic>? ?? const {};
  final rawDocumentUrls =
      data['documentUrls'] as Map<String, dynamic>? ?? const {};
  return Account(
    id: doc.id,
    role: AppRole.vendor,
    name: data['name'] as String? ?? '',
    phone: data['phone'] as String? ?? '',
    email: data['email'] as String?,
    managerCode: data['managerCode'] as String?,
    territory: data['territory'] as String?,
    category: data['category'] as String?,
    subCategory: data['subCategory'] as String?,
    ownerName: data['ownerName'] as String?,
    rebatePercent: (data['rebatePercent'] as num?)?.toDouble() ?? 15,
    documentStatuses: {
      for (final type in VendorDocumentType.values)
        if (rawDocumentStatuses[type.name] != null)
          type: VendorDocumentStatus.values.byName(
            rawDocumentStatuses[type.name] as String,
          ),
    },
    documentUrls: {
      for (final type in VendorDocumentType.values)
        if (rawDocumentUrls[type.name] != null)
          type: rawDocumentUrls[type.name] as String,
    },
    status: AccountStatus.values.byName(data['status'] as String? ?? 'active'),
    isOpen: data['isOpen'] as bool? ?? true,
    deletedAt: (data['deletedAt'] as Timestamp?)?.toDate(),
  );
}

// Sorted client-side rather than via `.orderBy('createdAt')` — Firestore
// excludes documents that don't have the ordered field set at all (e.g. a
// vendor doc added by hand in the console without a `createdAt`), which
// would otherwise silently vanish from every screen that reads this
// provider. Docs missing it just sort last instead of disappearing.
final firestoreVendorsProvider = StreamProvider<List<Account>>((ref) {
  return vendorsCollection.snapshots().map((snapshot) {
    final accounts = snapshot.docs
        .map(_accountFromDoc)
        .where((a) => a.deletedAt == null)
        .toList();
    final createdAtById = {
      for (final doc in snapshot.docs)
        doc.id: doc.data()['createdAt'] as Timestamp?,
    };
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

/// Soft-deletes a Vendor (Admin-only, `vendor_directory_screen.dart`) —
/// callers must confirm there's no uncleared settlement first (an
/// in-progress order, or a delivered COD order whose cash hasn't been
/// marked collected), since there's no real ledger to enforce that
/// server-side in this build.
Future<void> softDeleteVendor(String vendorId) => vendorsCollection
    .doc(vendorId)
    .update({'deletedAt': FieldValue.serverTimestamp()});

/// One-shot lookup for phone-login/session-resolution (`auth_navigation.dart`,
/// `splash_screen.dart`) — a Vendor a Manager created only lives in
/// Firestore, not the in-memory `mockAccountsProvider` which resets on
/// restart. Mirrors `findFirestoreManagerByEmail`'s reasoning, phone-keyed
/// since Vendor logs in by phone rather than email.
Future<Account?> findFirestoreVendorByPhone(String phone) async {
  final normalized = phone.replaceFirst(RegExp(r'^\+91'), '');
  final snapshot = await vendorsCollection
      .where('phone', isEqualTo: normalized)
      .limit(1)
      .get();
  if (snapshot.docs.isEmpty) return null;
  return _accountFromDoc(snapshot.docs.first);
}

/// Merges Firestore-persisted vendors with any in-memory mock ones
/// (self-registered demo vendors, or same-session mirrors of ones a
/// Manager just added — see `manager_vendor_create_screen.dart`), deduped
/// by id. Shared by the Vendor Management list and detail screens so both
/// look a vendor up the same way regardless of which store it actually
/// lives in. Firestore wins on a shared id: the mock mirror is only a
/// frozen snapshot from the moment of creation, meant to cover the brief
/// window before Firestore's own stream has delivered the new doc — every
/// real update after that (status, documents, rebate) only ever writes to
/// Firestore, so once it's present there it must take priority, or those
/// updates would stay invisible behind the stale mock copy for the rest of
/// the session.
List<Account> mergeVendorAccounts(
  List<Account> mockVendors,
  List<Account> firestoreVendors,
) {
  final byId = <String, Account>{for (final v in mockVendors) v.id: v};
  for (final v in firestoreVendors) {
    byId[v.id] = v;
  }
  return byId.values.toList();
}

/// Reactive single-vendor lookup, merging Firestore and mock stores the same
/// way [mergeVendorAccounts] does for the Vendor list screens — lets a
/// pending Vendor's own session notice a Manager's status/document change
/// live (`auth_under_review_screen.dart`) instead of only on next login.
final liveVendorAccountProvider = Provider.family<Account?, String>((ref, id) {
  final matches = mergeVendorAccounts(
    ref.watch(mockAccountsProvider),
    ref.watch(firestoreVendorsProvider).valueOrNull ?? const [],
  ).where((a) => a.id == id);
  return matches.isEmpty ? null : matches.first;
});

Future<void> updateVendorStatus(
  String vendorId,
  AccountStatus status, {
  String? rejectionReason,
}) => vendorsCollection.doc(vendorId).update({
  'status': status.name,
  'rejectionReason': ?rejectionReason,
});

/// Vendor's own Dashboard/Profile "Open/Closed" switch — independent of
/// [AccountStatus] (Admin/Manager's approval state). `home_screen.dart`'s
/// storefront listing and `vendor_detail_screen.dart` both read
/// [Account.isOpen] to keep a closed vendor from being ordered from.
Future<void> setVendorOpen(String vendorId, bool isOpen) =>
    vendorsCollection.doc(vendorId).update({'isOpen': isOpen});

/// Vendor editing their own shop name/owner name/email
/// (`vendor_profile_edit_screen.dart`) — territory/managerCode/category
/// stay Manager-assigned, not editable here.
Future<void> updateVendorProfile(
  String vendorId, {
  required String name,
  String? ownerName,
  String? email,
}) => vendorsCollection.doc(vendorId).update({
  'name': name,
  'ownerName': ownerName,
  'email': email,
});

Future<void> updateVendorDocumentStatus(
  String vendorId,
  VendorDocumentType type,
  VendorDocumentStatus status,
) => vendorsCollection.doc(vendorId).update({
  'documentStatuses.${type.name}': status.name,
});

Future<void> updateVendorDocumentUrl(
  String vendorId,
  VendorDocumentType type,
  String url,
) => vendorsCollection.doc(vendorId).update({'documentUrls.${type.name}': url});

Future<void> clearVendorDocumentUrl(String vendorId, VendorDocumentType type) =>
    vendorsCollection.doc(vendorId).update({
      'documentUrls.${type.name}': FieldValue.delete(),
    });
