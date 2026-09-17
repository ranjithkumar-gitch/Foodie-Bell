import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/account.dart';
import '../models/driver_document.dart';
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
  'documentStatuses': account.driverDocumentStatuses.map((type, status) => MapEntry(type.name, status.name)),
  'documentUrls': account.driverDocumentUrls.map((type, url) => MapEntry(type.name, url)),
  'riskConsentAccepted': account.riskConsentAccepted,
  'isOnline': account.isOnline,
  'status': account.status.name,
};

Account _accountFromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
  final data = doc.data();
  final rawDocumentStatuses = data['documentStatuses'] as Map<String, dynamic>? ?? const {};
  final rawDocumentUrls = data['documentUrls'] as Map<String, dynamic>? ?? const {};
  return Account(
    id: doc.id,
    role: AppRole.driver,
    name: data['name'] as String? ?? '',
    phone: data['phone'] as String? ?? '',
    email: data['email'] as String?,
    managerCode: data['managerCode'] as String?,
    territory: data['territory'] as String?,
    driverDocumentStatuses: {
      for (final type in DriverDocumentType.values)
        if (rawDocumentStatuses[type.name] != null) type: VendorDocumentStatus.values.byName(rawDocumentStatuses[type.name] as String),
    },
    driverDocumentUrls: {
      for (final type in DriverDocumentType.values)
        if (rawDocumentUrls[type.name] != null) type: rawDocumentUrls[type.name] as String,
    },
    riskConsentAccepted: data['riskConsentAccepted'] as bool? ?? false,
    isOnline: data['isOnline'] as bool? ?? false,
    status: AccountStatus.values.byName(data['status'] as String? ?? 'active'),
  );
}

final firestoreDriversProvider = StreamProvider<List<Account>>((ref) {
  return driversCollection.orderBy('createdAt', descending: true).snapshots().map((snapshot) => snapshot.docs.map(_accountFromDoc).toList());
});

/// One-shot lookup for phone-login/session-resolution (`auth_navigation.dart`,
/// `splash_screen.dart`) — mirrors `findFirestoreVendorByPhone`.
Future<Account?> findFirestoreDriverByPhone(String phone) async {
  final normalized = phone.replaceFirst(RegExp(r'^\+91'), '');
  final snapshot = await driversCollection.where('phone', isEqualTo: normalized).limit(1).get();
  if (snapshot.docs.isEmpty) return null;
  return _accountFromDoc(snapshot.docs.first);
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

Future<void> updateDriverDocumentUrl(String driverId, DriverDocumentType type, String url) =>
    driversCollection.doc(driverId).update({'documentUrls.${type.name}': url});

Future<void> clearDriverDocumentUrl(String driverId, DriverDocumentType type) =>
    driversCollection.doc(driverId).update({'documentUrls.${type.name}': FieldValue.delete()});

Future<void> updateDriverConsent(String driverId, bool accepted) =>
    driversCollection.doc(driverId).update({'riskConsentAccepted': accepted});

/// Persists the Home screen's online/offline toggle so it's remembered
/// across app restarts and re-logins instead of always resetting to
/// offline.
Future<void> setDriverOnlineStatus(String driverId, bool isOnline) =>
    driversCollection.doc(driverId).update({'isOnline': isOnline});

/// One atomic write for the Driver's own "Upload" confirmation
/// (`driver_document_checklist.dart`) — every document the Driver staged
/// locally (already uploaded to Storage by the caller, [documentUrls] keyed
/// by type) plus risk consent land in the database together, in a single
/// `update()` call, only once the Driver explicitly confirms. Nothing here
/// fires until that tap — picking/cropping a photo only stages it in
/// memory, it doesn't touch Firestore.
Future<void> submitDriverDocuments(String driverId, Map<DriverDocumentType, String> documentUrls, {bool? riskConsentAccepted}) {
  final updates = <String, dynamic>{
    for (final entry in documentUrls.entries) ...{
      'documentStatuses.${entry.key.name}': VendorDocumentStatus.submitted.name,
      'documentUrls.${entry.key.name}': entry.value,
    },
    if (riskConsentAccepted == true) 'riskConsentAccepted': true,
  };
  if (updates.isEmpty) return Future.value();
  return driversCollection.doc(driverId).update(updates);
}
