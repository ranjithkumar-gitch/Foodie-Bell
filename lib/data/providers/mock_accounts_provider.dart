import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/account.dart';
import '../models/driver_document.dart';
import '../models/vendor_document.dart';

/// Local mirror of Vendor/Driver accounts a Manager just created for
/// immediate same-session visibility in their own Vendor/Driver Management
/// lists (`manager_vendor_create_screen.dart`/`manager_driver_create_screen.dart`
/// call [addAccount] right after the real Firestore write) — those screens
/// merge this with `firestoreVendorsProvider`/`firestoreDriversProvider`
/// rather than waiting on a stream round-trip. Starts empty: nothing is
/// seeded into it.
class AccountsNotifier extends StateNotifier<List<Account>> {
  AccountsNotifier() : super(const []);

  void setStatus(String accountId, AccountStatus status, {String? rejectionReason}) {
    state = [
      for (final a in state)
        if (a.id == accountId) a.copyWith(status: status, rejectionReason: rejectionReason) else a,
    ];
  }

  /// Admin creating a new Manager (or any account) directly — see
  /// `manager_create_screen.dart`. Additive: doesn't affect `setStatus`.
  void addAccount(Account account) => state = [...state, account];

  /// Vendor editing their own name/email/avatar/ownerName
  /// (`vendor_profile_edit_screen.dart`) — mirrors `updateVendorProfile` for
  /// a just-created Vendor account still only in this local mirror, before
  /// the real `vendors` Firestore stream has caught up to it.
  void updateProfile(String accountId, {required String name, String? email, String? avatarUrl, String? ownerName}) {
    state = [
      for (final a in state)
        if (a.id == accountId) a.copyWith(name: name, email: email, avatarUrl: avatarUrl, ownerName: ownerName) else a,
    ];
  }

  /// Mirrors `setVendorOpen` for a just-created Vendor account still only in
  /// this local mirror, before the real `vendors` Firestore stream has
  /// caught up to it.
  void setOpen(String accountId, bool isOpen) {
    state = [
      for (final a in state)
        if (a.id == accountId) a.copyWith(isOpen: isOpen) else a,
    ];
  }

  /// Mirrors `updateVendorDocumentStatus` for a Vendor account still only in
  /// this local mirror — Manager setting required/not-required, or Vendor
  /// marking their own submission.
  void updateDocumentStatus(String accountId, VendorDocumentType type, VendorDocumentStatus status) {
    state = [
      for (final a in state)
        if (a.id == accountId) a.copyWith(documentStatuses: {...a.documentStatuses, type: status}) else a,
    ];
  }

  /// Mirrors `updateVendorDocumentUrl` for a Vendor account still only in
  /// this local mirror — set once a real upload
  /// (`vendor_document_storage_provider.dart`) succeeds.
  void updateDocumentUrl(String accountId, VendorDocumentType type, String url) {
    state = [
      for (final a in state)
        if (a.id == accountId) a.copyWith(documentUrls: {...a.documentUrls, type: url}) else a,
    ];
  }

  /// Mirrors `clearVendorDocumentUrl` — Vendor deleting their own upload.
  void clearDocumentUrl(String accountId, VendorDocumentType type) {
    state = [
      for (final a in state)
        if (a.id == accountId) a.copyWith(documentUrls: {...a.documentUrls}..remove(type)) else a,
    ];
  }

  /// Mirrors `updateVendorDocumentStatus` for a Driver account still only in
  /// this local mirror.
  void updateDriverDocumentStatus(String accountId, DriverDocumentType type, VendorDocumentStatus status) {
    state = [
      for (final a in state)
        if (a.id == accountId) a.copyWith(driverDocumentStatuses: {...a.driverDocumentStatuses, type: status}) else a,
    ];
  }

  /// Mirrors `updateVendorDocumentUrl` for a Driver account still only in
  /// this local mirror.
  void updateDriverDocumentUrl(String accountId, DriverDocumentType type, String url) {
    state = [
      for (final a in state)
        if (a.id == accountId) a.copyWith(driverDocumentUrls: {...a.driverDocumentUrls, type: url}) else a,
    ];
  }

  /// Mirrors `clearVendorDocumentUrl` for a Driver account still only in
  /// this local mirror.
  void clearDriverDocumentUrl(String accountId, DriverDocumentType type) {
    state = [
      for (final a in state)
        if (a.id == accountId) a.copyWith(driverDocumentUrls: {...a.driverDocumentUrls}..remove(type)) else a,
    ];
  }

  /// Driver giving explicit risk consent from their own login — mirrors the
  /// document-status mutators above but for the one-way consent flag.
  void updateDriverConsent(String accountId, bool accepted) {
    state = [
      for (final a in state)
        if (a.id == accountId) a.copyWith(riskConsentAccepted: accepted) else a,
    ];
  }

  /// Mirrors `submitDriverDocuments` for a Driver account still only in this
  /// local mirror — one atomic update for the Driver's "Upload"
  /// confirmation, applying every staged document plus consent together
  /// instead of one field at a time.
  void submitDriverDocuments(String accountId, Map<DriverDocumentType, String> documentUrls, {bool? riskConsentAccepted}) {
    if (documentUrls.isEmpty && riskConsentAccepted != true) return;
    state = [
      for (final a in state)
        if (a.id == accountId)
          a.copyWith(
            driverDocumentStatuses: {...a.driverDocumentStatuses, for (final type in documentUrls.keys) type: VendorDocumentStatus.submitted},
            driverDocumentUrls: {...a.driverDocumentUrls, ...documentUrls},
            riskConsentAccepted: riskConsentAccepted == true ? true : a.riskConsentAccepted,
          )
        else
          a,
    ];
  }
}

final mockAccountsProvider = StateNotifierProvider<AccountsNotifier, List<Account>>((ref) => AccountsNotifier());
