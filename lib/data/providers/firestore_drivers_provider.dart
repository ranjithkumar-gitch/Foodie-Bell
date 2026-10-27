import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/session/access_scope.dart';
import '../models/account.dart';
import '../models/driver_document.dart';
import '../models/driver_location.dart';
import '../models/vendor_document.dart';
import 'mock_accounts_provider.dart';

/// Real, persistent Driver identities created directly by a Manager (see
/// `manager_driver_create_screen.dart`) — same Firestore pattern as
/// `firestore_vendors_provider.dart`, which this file mirrors field-for-field.
///
/// Driver authenticates by phone+OTP same as Vendor, so a Manager-created
/// Driver gets a real Firestore *profile* record here (territory, Manager
/// Code, active status) but no Firebase Auth credential — see
/// `firestore_vendors_provider.dart`'s doc comment for why.
const driversCollectionPath = 'drivers';

CollectionReference<Map<String, dynamic>> get driversCollection =>
    FirebaseFirestore.instance.collection(driversCollectionPath);

Map<String, dynamic> accountToDriverDoc(Account account) => {
  'name': account.name,
  'phone': account.phone,
  'email': account.email?.toLowerCase(),
  'managerCode': account.managerCode,
  'territory': account.territory,
  'territoryId': account.territoryId,
  'documentStatuses': account.driverDocumentStatuses.map((type, status) => MapEntry(type.name, status.name)),
  'documentPaths': account.driverDocumentPaths.map((type, url) => MapEntry(type.name, url)),
  'riskConsentAccepted': account.riskConsentAccepted,
  'isOnline': account.isOnline,
  'status': account.status.name,
};

Account _accountFromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
  final data = doc.data() ?? const <String, dynamic>{};
  final rawDocumentStatuses = data['documentStatuses'] as Map<String, dynamic>? ?? const {};
  final rawDocumentPaths = data['documentPaths'] as Map<String, dynamic>? ?? const {};
  return Account(
    id: doc.id,
    role: AppRole.driver,
    name: data['name'] as String? ?? '',
    phone: data['phone'] as String? ?? '',
    email: data['email'] as String?,
    managerCode: data['managerCode'] as String?,
    territory: data['territory'] as String?,
    territoryId: data['territoryId'] as String?,
    driverDocumentStatuses: {
      for (final type in DriverDocumentType.values)
        if (rawDocumentStatuses[type.name] != null) type: VendorDocumentStatus.values.byName(rawDocumentStatuses[type.name] as String),
    },
    driverDocumentPaths: {
      for (final type in DriverDocumentType.values)
        if (rawDocumentPaths[type.name] != null) type: rawDocumentPaths[type.name] as String,
    },
    riskConsentAccepted: data['riskConsentAccepted'] as bool? ?? false,
    isOnline: data['isOnline'] as bool? ?? false,
    status: AccountStatus.values.byName(data['status'] as String? ?? 'active'),
  );
}

/// The Driver accounts the signed-in account may see: a Manager's whole
/// territory, or a Driver's own record — nobody else can read drivers
/// (Customers follow their Driver through the order instead). Newest first,
/// sorted client-side so no composite index is needed.
final firestoreDriversProvider = StreamProvider<List<Account>>((ref) {
  final scope = ref.watch(accessScopeProvider);
  if (scope == null) return Stream.value(const []);
  final territoryId = scope.territoryId;
  if (scope.role == AppRole.driver) {
    return driversCollection.doc(scope.accountId).snapshots().map((doc) => doc.exists ? [_accountFromDoc(doc)] : const []);
  }
  if (scope.role != AppRole.manager || territoryId == null) return Stream.value(const []);
  return driversCollection.where('territoryId', isEqualTo: territoryId).snapshots().map((snapshot) {
    final createdAt = {for (final doc in snapshot.docs) doc.id: doc.data()['createdAt'] as Timestamp?};
    return snapshot.docs.map(_accountFromDoc).toList()
      ..sort((a, b) => (createdAt[b.id]?.millisecondsSinceEpoch ?? 0).compareTo(createdAt[a.id]?.millisecondsSinceEpoch ?? 0));
  });
});

/// One-shot read of a single Driver account by doc id — what
/// `account_resolver.dart` loads once the `resolveSession` Cloud Function
/// has said which account a verified phone sign-in belongs to. A direct
/// document read, which the per-account Firestore rules allow for the
/// account's own owner.
Future<Account?> findFirestoreDriverById(String id) async {
  final snapshot = await driversCollection.doc(id).get();
  if (!snapshot.exists) return null;
  return _accountFromDoc(snapshot);
}

/// Merges Firestore-persisted drivers with any in-memory mock ones, deduped
/// by id — mirrors `mergeVendorAccounts`. Firestore wins on a shared id: the
/// mock entry for a Manager-created driver is only a frozen snapshot from
/// the moment of creation (`manager_driver_create_screen.dart`) meant to
/// cover the brief window before Firestore's own stream has delivered the
/// new doc — every real update after that (status, documents, consent)
/// only ever writes to Firestore, so once it's present there it must take
/// priority, or those updates would stay invisible behind the stale mock
/// copy for the rest of the session.
List<Account> mergeDriverAccounts(List<Account> mockDrivers, List<Account> firestoreDrivers) {
  final byId = <String, Account>{for (final d in mockDrivers) d.id: d};
  for (final d in firestoreDrivers) {
    byId[d.id] = d;
  }
  return byId.values.toList();
}

/// Reactive single-driver lookup, merging Firestore and mock stores — mirrors
/// `liveVendorAccountProvider`.
final liveDriverAccountProvider = Provider.family<Account?, String>((ref, id) {
  final matches = mergeDriverAccounts(
    ref.watch(mockAccountsProvider),
    ref.watch(firestoreDriversProvider).valueOrNull ?? const [],
  ).where((a) => a.id == id);
  return matches.isEmpty ? null : matches.first;
});

Future<void> updateDriverStatus(String driverId, AccountStatus status, {String? rejectionReason}) => driversCollection.doc(driverId).update({
  'status': status.name,
  'rejectionReason': ?rejectionReason,
});

Future<void> updateDriverDocumentStatus(String driverId, DriverDocumentType type, VendorDocumentStatus status) =>
    driversCollection.doc(driverId).update({'documentStatuses.${type.name}': status.name});

Future<void> updateDriverDocumentPath(String driverId, DriverDocumentType type, String url) =>
    driversCollection.doc(driverId).update({'documentPaths.${type.name}': url});

Future<void> clearDriverDocumentPath(String driverId, DriverDocumentType type) =>
    driversCollection.doc(driverId).update({'documentPaths.${type.name}': FieldValue.delete()});

Future<void> updateDriverConsent(String driverId, bool accepted) =>
    driversCollection.doc(driverId).update({'riskConsentAccepted': accepted});

/// Persists the Home screen's online/offline toggle so it's remembered
/// across app restarts and re-logins instead of always resetting to
/// offline.
Future<void> setDriverOnlineStatus(String driverId, bool isOnline) =>
    driversCollection.doc(driverId).update({'isOnline': isOnline});

/// Stamps the Driver's current GPS position onto their own doc — called by
/// `driver_location_tracker.dart` once at login/registration and then again
/// every time they move, so the User's order tracking map can follow them.
Future<void> updateDriverLocation(String driverId, {required double latitude, required double longitude}) =>
    driversCollection.doc(driverId).update({
      'latitude': latitude,
      'longitude': longitude,
      'locationUpdatedAt': FieldValue.serverTimestamp(),
    });

/// A single Driver's position, live — its own one-doc listener rather than
/// a slice of [firestoreDriversProvider], so a User tracking one order
/// isn't re-reading the whole drivers collection on every GPS update. Null
/// until that Driver has reported a position at least once.
final driverLocationProvider = StreamProvider.family<DriverLocation?, String>((ref, driverId) {
  return driversCollection.doc(driverId).snapshots().map((doc) {
    final data = doc.data();
    final latitude = (data?['latitude'] as num?)?.toDouble();
    final longitude = (data?['longitude'] as num?)?.toDouble();
    if (latitude == null || longitude == null) return null;
    return DriverLocation(
      latitude: latitude,
      longitude: longitude,
      updatedAt: (data?['locationUpdatedAt'] as Timestamp?)?.toDate(),
    );
  });
});

/// One atomic write for the Driver's own "Upload" confirmation
/// (`driver_document_checklist.dart`) — every document the Driver staged
/// locally (already uploaded to Storage by the caller, [documentPaths] keyed
/// by type) plus risk consent land in the database together, in a single
/// `update()` call, only once the Driver explicitly confirms. Nothing here
/// fires until that tap — picking/cropping a photo only stages it in
/// memory, it doesn't touch Firestore.
Future<void> submitDriverDocuments(String driverId, Map<DriverDocumentType, String> documentPaths, {bool? riskConsentAccepted}) {
  final updates = <String, dynamic>{
    for (final entry in documentPaths.entries) ...{
      'documentStatuses.${entry.key.name}': VendorDocumentStatus.submitted.name,
      'documentPaths.${entry.key.name}': entry.value,
    },
    if (riskConsentAccepted == true) 'riskConsentAccepted': true,
  };
  if (updates.isEmpty) return Future.value();
  return driversCollection.doc(driverId).update(updates);
}
