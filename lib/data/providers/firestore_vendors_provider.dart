import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/session/access_scope.dart';
import '../models/account.dart';
import '../models/vendor_document.dart';
import '../../features/user/home/selected_territory_provider.dart';
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
  'territoryId': account.territoryId,
  'category': account.category,
  'subCategory': account.subCategory,
  'ownerName': account.ownerName,
  'address': account.address,
  'latitude': account.latitude,
  'longitude': account.longitude,
  'rebatePercent': account.rebatePercent,
  'documentStatuses': account.documentStatuses.map(
    (type, status) => MapEntry(type.name, status.name),
  ),
  'documentPaths': account.documentPaths.map(
    (type, url) => MapEntry(type.name, url),
  ),
  'status': account.status.name,
  'isOpen': account.isOpen,
  'upiIds': account.upiIds,
};

Account _accountFromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
  final data = doc.data() ?? const <String, dynamic>{};
  final rawDocumentStatuses =
      data['documentStatuses'] as Map<String, dynamic>? ?? const {};
  final rawDocumentPaths =
      data['documentPaths'] as Map<String, dynamic>? ?? const {};
  return Account(
    id: doc.id,
    role: AppRole.vendor,
    name: data['name'] as String? ?? '',
    phone: data['phone'] as String? ?? '',
    email: data['email'] as String?,
    managerCode: data['managerCode'] as String?,
    territory: data['territory'] as String?,
    territoryId: data['territoryId'] as String?,
    category: data['category'] as String?,
    subCategory: data['subCategory'] as String?,
    ownerName: data['ownerName'] as String?,
    address: data['address'] as String?,
    latitude: (data['latitude'] as num?)?.toDouble(),
    longitude: (data['longitude'] as num?)?.toDouble(),
    rebatePercent: (data['rebatePercent'] as num?)?.toDouble() ?? 15,
    documentStatuses: {
      for (final type in VendorDocumentType.values)
        if (rawDocumentStatuses[type.name] != null)
          type: VendorDocumentStatus.values.byName(
            rawDocumentStatuses[type.name] as String,
          ),
    },
    documentPaths: {
      for (final type in VendorDocumentType.values)
        if (rawDocumentPaths[type.name] != null)
          type: rawDocumentPaths[type.name] as String,
    },
    coverPhotoUrl: data['coverPhotoUrl'] as String?,
    status: AccountStatus.values.byName(data['status'] as String? ?? 'active'),
    isOpen: data['isOpen'] as bool? ?? true,
    upiIds: (data['upiIds'] as List<dynamic>? ?? const []).cast<String>(),
    deletedAt: (data['deletedAt'] as Timestamp?)?.toDate(),
    ratingAverage: ((data['rating'] as Map?)?['average'] as num?)?.toDouble(),
    ratingCount: ((data['rating'] as Map?)?['count'] as num?)?.toInt() ?? 0,
  );
}

/// The Vendor accounts the signed-in account needs, live, each query scoped
/// by territory ID (Phase 3 — it used to stream every approved vendor on
/// the platform to every customer):
///  - Customer: approved (`active`) vendors in the territory they browse.
///  - Driver: approved vendors in their own territory (pickup points).
///  - Vendor: their own record (whatever its status).
///  - Manager: every vendor in their territory, pending ones included.
// Sorted client-side rather than via `.orderBy('createdAt')` — Firestore
// excludes documents that don't have the ordered field set at all (e.g. a
// vendor doc added by hand in the console without a `createdAt`), which
// would otherwise silently vanish from every screen that reads this
// provider. Docs missing it just sort last instead of disappearing.
final firestoreVendorsProvider = StreamProvider<List<Account>>((ref) {
  final scope = ref.watch(accessScopeProvider);
  if (scope == null) return Stream.value(const []);
  Stream<List<(Account, Timestamp?)>> run(Query<Map<String, dynamic>> query) => query.snapshots().map(
    (snapshot) => [for (final doc in snapshot.docs) (_accountFromDoc(doc), doc.data()['createdAt'] as Timestamp?)],
  );
  Stream<List<(Account, Timestamp?)>> approvedIn(String? territoryId) => territoryId == null
      ? Stream.value(const [])
      : run(vendorsCollection.where('status', isEqualTo: AccountStatus.active.name).where('territoryId', isEqualTo: territoryId));
  final territoryId = scope.territoryId;
  final Stream<List<(Account, Timestamp?)>> vendors = switch (scope.role) {
    AppRole.user => approvedIn(ref.watch(browsingTerritoryIdProvider)),
    AppRole.driver => approvedIn(territoryId),
    AppRole.vendor => vendorsCollection.doc(scope.accountId).snapshots().map(
      (doc) => doc.exists ? [(_accountFromDoc(doc), doc.data()?['createdAt'] as Timestamp?)] : const <(Account, Timestamp?)>[],
    ),
    AppRole.manager => territoryId == null ? Stream.value(const []) : run(vendorsCollection.where('territoryId', isEqualTo: territoryId)),
    AppRole.admin => Stream.value(const []),
  };
  return vendors.map((entries) {
    final live = entries.where((e) => e.$1.deletedAt == null).toList()
      ..sort((a, b) {
        final aTime = a.$2;
        final bTime = b.$2;
        if (aTime == null && bTime == null) return 0;
        if (aTime == null) return 1;
        if (bTime == null) return -1;
        return bTime.compareTo(aTime);
      });
    return [for (final e in live) e.$1];
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

/// One-shot read of a single Vendor account by doc id — what
/// `account_resolver.dart` loads once the `resolveSession` Cloud Function
/// has said which account a verified phone sign-in belongs to. A direct
/// document read, which the per-account Firestore rules allow for the
/// account's own owner.
Future<Account?> findFirestoreVendorById(String id) async {
  final snapshot = await vendorsCollection.doc(id).get();
  if (!snapshot.exists) return null;
  return _accountFromDoc(snapshot);
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
  if (matches.isNotEmpty) return matches.first;
  // Not in the scoped list (a shop outside the territory being browsed,
  // opened from an old order): read that one document.
  return ref.watch(_vendorDocProvider(id)).valueOrNull;
});

final _vendorDocProvider = StreamProvider.autoDispose.family<Account?, String>((ref, id) {
  return vendorsCollection.doc(id).snapshots().map((doc) => doc.exists ? _accountFromDoc(doc) : null);
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

/// Vendor's own UPI IDs (`vendor_upi_screen.dart`) — the whole list is
/// written at once since order matters (the first is the one customers
/// pay to, see [Account.upiIds]).
Future<void> setVendorUpiIds(String vendorId, List<String> upiIds) =>
    vendorsCollection.doc(vendorId).update({'upiIds': upiIds});

/// Vendor editing their own shop name/owner name/email/address
/// (`vendor_profile_edit_screen.dart`) — territory/managerCode/category
/// stay Manager-assigned, not editable here. [latitude]/[longitude] are
/// only written when given, so saving the form without a pinned location
/// never wipes one that's already on record.
Future<void> updateVendorProfile(
  String vendorId, {
  required String name,
  String? ownerName,
  String? email,
  String? address,
  double? latitude,
  double? longitude,
}) => vendorsCollection.doc(vendorId).update({
  'name': name,
  'ownerName': ownerName,
  'email': email,
  'address': address,
  if (latitude != null && longitude != null) ...{
    'latitude': latitude,
    'longitude': longitude,
    'locationUpdatedAt': FieldValue.serverTimestamp(),
  },
});

Future<void> updateVendorDocumentStatus(
  String vendorId,
  VendorDocumentType type,
  VendorDocumentStatus status,
) => vendorsCollection.doc(vendorId).update({
  'documentStatuses.${type.name}': status.name,
});

/// Records an uploaded KYC document by its Storage [path]. The shop-front
/// photo doubles as the public storefront picture, so its download URL
/// ([coverPhotoUrl]) is copied to the vendor's public `coverPhotoUrl` too.
Future<void> updateVendorDocumentPath(
  String vendorId,
  VendorDocumentType type,
  String path, {
  String? coverPhotoUrl,
}) => vendorsCollection.doc(vendorId).update({
  'documentPaths.${type.name}': path,
  if (type == VendorDocumentType.shopFrontPhoto && coverPhotoUrl != null) 'coverPhotoUrl': coverPhotoUrl,
});

Future<void> clearVendorDocumentPath(String vendorId, VendorDocumentType type) =>
    vendorsCollection.doc(vendorId).update({
      'documentPaths.${type.name}': FieldValue.delete(),
      if (type == VendorDocumentType.shopFrontPhoto) 'coverPhotoUrl': FieldValue.delete(),
    });
