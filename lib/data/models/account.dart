import 'driver_document.dart';
import 'vendor_document.dart';

enum AppRole { user, vendor, driver, manager, admin }

extension AppRoleX on AppRole {
  String get label => switch (this) {
    AppRole.user => 'User',
    AppRole.vendor => 'Vendor',
    AppRole.driver => 'Driver',
    AppRole.manager => 'Manager',
    AppRole.admin => 'Admin',
  };

  /// Vendor/Driver register against a Manager Code and go through document
  /// review before activation. Manager accounts are created directly by
  /// Admin (see Admin's "Add Manager" screen) — there's no Manager
  /// self-registration, so they're active immediately, same as User/Admin.
  bool get requiresApproval => this == AppRole.vendor || this == AppRole.driver;
}

enum AccountStatus { active, pendingReview, rejected, suspended }

/// A role-scoped profile — the same shape backs every role's "Profile"
/// screen and every Admin/Manager directory listing, so one mock repo
/// (`mockAccountsProvider`) is the single source of truth across roles.
class Account {
  const Account({
    required this.id,
    required this.role,
    required this.name,
    required this.phone,
    this.email,
    this.avatarUrl,
    this.status = AccountStatus.active,
    this.managerCode,
    this.rejectionReason,
    this.territory,
    this.territoryFee = 200000,
    this.category,
    this.subCategory,
    this.ownerName,
    this.rebatePercent = 15,
    this.documentStatuses = const {},
    this.documentUrls = const {},
    this.driverDocumentStatuses = const {},
    this.driverDocumentUrls = const {},
    this.riskConsentAccepted = false,
    this.isOnline = false,
    this.isOpen = true,
    this.languageCode,
    this.deletedAt,
    this.bankAccountHolder,
    this.bankAccountNumber,
    this.bankIfsc,
  });

  final String id;
  final AppRole role;
  final String name;
  final String phone;
  final String? email;
  final String? avatarUrl;
  final AccountStatus status;

  /// For Vendor/Driver: the Manager Code they registered against (spec's
  /// "golden rule"). For Manager: the code Admin issued them on creation.
  final String? managerCode;
  final String? rejectionReason;

  /// Manager-only: the territory/pincode cluster Admin assigned on creation.
  final String? territory;

  /// Manager-only: the one-time territory/location fee Admin set for this
  /// Manager on `manager_create_screen.dart` — defaults to ₹2,00,000 there
  /// but is Admin-editable per manager, both at creation and later from
  /// `manager_detail_screen.dart`, unlike Vendor's [rebatePercent] which
  /// locks forever once set.
  final double territoryFee;

  /// Vendor-only: the Admin-managed [Category] name (`firestore_categories_provider.dart`)
  /// this vendor was tagged with on creation — see Manager's "Add Vendor" screen.
  final String? category;

  /// Vendor-only: a finer-grained subcategory within [category] (e.g.
  /// "Restaurant"/"Fast Food"/"Tiffins"/"Bakery" within Food) — only some
  /// categories offer one, see `manager_vendor_create_screen.dart`.
  final String? subCategory;

  /// Vendor-only: the person running the shop, distinct from [name] (the
  /// shop/business name itself) — see Manager's "Add Vendor" screen.
  final String? ownerName;

  /// Vendor-only: the negotiated Manager/Company rebate split, 10-20 band
  /// (spec §5.5) — Manager-editable from the Vendor Detail screen.
  final double rebatePercent;

  /// Vendor-only: Manager sets which of the fixed document checklist
  /// applies to this vendor (required/not required); Vendor moves their own
  /// entries to submitted from their own login. Any [VendorDocumentType]
  /// missing from this map defaults to [VendorDocumentStatus.required] —
  /// see [documentStatus].
  final Map<VendorDocumentType, VendorDocumentStatus> documentStatuses;

  /// Vendor-only: download URL for each document that's been actually
  /// uploaded to Storage (`vendor_document_storage_provider.dart`) — keyed
  /// the same as [documentStatuses], but only populated once a document has
  /// gone through a real pick/crop/upload rather than just been marked
  /// required/not-required.
  final Map<VendorDocumentType, String> documentUrls;

  /// Driver-only: same Required/Not Required/Submitted checklist as
  /// [documentStatuses], but keyed by [DriverDocumentType] — Manager sets
  /// which apply, only the signed-in Driver can move one to submitted (see
  /// `driver_document_checklist.dart`).
  final Map<DriverDocumentType, VendorDocumentStatus> driverDocumentStatuses;

  /// Driver-only: download URL for each submitted document, mirrors
  /// [documentUrls] (`driver_document_storage_provider.dart`).
  final Map<DriverDocumentType, String> driverDocumentUrls;

  /// Driver-only: explicit acknowledgment that driving carries inherent
  /// risk and they're taking up the work willingly, without pressure —
  /// only the Driver can set this true, from their own login; it never
  /// reverts to false once given.
  final bool riskConsentAccepted;

  /// Driver-only: whether they're currently marked available for delivery
  /// requests — persisted so it survives app restarts/re-logins instead of
  /// always resetting to offline (`driver_home_screen.dart`'s online/offline
  /// toggle).
  final bool isOnline;

  /// Vendor-only: whether they're currently accepting orders — Vendor's own
  /// Dashboard/Profile "Open/Closed" switch. Independent of [status]
  /// (`AccountStatus.active` is Admin/Manager's approval state; this is the
  /// vendor's own day-to-day availability, e.g. closed for the night or
  /// temporarily out of everything). Defaults true so a vendor who's never
  /// touched the toggle still shows as open. Read by `home_screen.dart`'s
  /// storefront listing and `vendor_detail_screen.dart` to keep a closed
  /// vendor from being ordered from.
  final bool isOpen;

  /// User-only: preferred app language ('en'/'te') set from Profile's
  /// language switcher — null means "no preference set yet", which the
  /// User module treats as English. Persisted so it survives logout/app
  /// restart, same reasoning as [isOnline]/[isOpen].
  final String? languageCode;

  /// Manager/Vendor-only: set once Admin soft-deletes this account —
  /// `firestore_managers_provider.dart`/`firestore_vendors_provider.dart`
  /// filter these out of their streams entirely rather than exposing a
  /// "deleted" `AccountStatus` (which would ripple through every existing
  /// status switch across the app). Deleting a Manager frees their
  /// Territory (see `manager_directory_screen.dart`'s `_delete`); deleting a
  /// Vendor is blocked while they have any uncleared settlement.
  final DateTime? deletedAt;

  /// Manager-only: payout bank details (`manager_profile_screen.dart`'s
  /// "Bank & payout details" form) — Manager-editable, unlike [territory]/
  /// [territoryFee] which only Admin sets.
  final String? bankAccountHolder;
  final String? bankAccountNumber;
  final String? bankIfsc;

  VendorDocumentStatus documentStatus(VendorDocumentType type) => documentStatuses[type] ?? VendorDocumentStatus.required;

  String? documentUrl(VendorDocumentType type) => documentUrls[type];

  /// True once every document Manager marked required has been submitted —
  /// Manager Vendor Detail surfaces this as "Ready to Activate" while the
  /// vendor is still `pendingReview`.
  bool get readyToActivate => VendorDocumentType.values.every((t) => documentStatus(t) != VendorDocumentStatus.required);

  VendorDocumentStatus driverDocumentStatus(DriverDocumentType type) => driverDocumentStatuses[type] ?? VendorDocumentStatus.required;

  String? driverDocumentUrl(DriverDocumentType type) => driverDocumentUrls[type];

  /// True once every driver document is submitted and risk consent has been
  /// given — Manager Driver Detail surfaces this as "Ready to Activate"
  /// while the driver is still `pendingReview`.
  bool get driverReadyToActivate =>
      riskConsentAccepted && DriverDocumentType.values.every((t) => driverDocumentStatus(t) != VendorDocumentStatus.required);

  Account copyWith({
    String? name,
    String? email,
    String? avatarUrl,
    String? ownerName,
    AccountStatus? status,
    String? rejectionReason,
    double? rebatePercent,
    Map<VendorDocumentType, VendorDocumentStatus>? documentStatuses,
    Map<VendorDocumentType, String>? documentUrls,
    Map<DriverDocumentType, VendorDocumentStatus>? driverDocumentStatuses,
    Map<DriverDocumentType, String>? driverDocumentUrls,
    bool? riskConsentAccepted,
    bool? isOnline,
    bool? isOpen,
    String? languageCode,
    String? bankAccountHolder,
    String? bankAccountNumber,
    String? bankIfsc,
  }) => Account(
    id: id,
    role: role,
    name: name ?? this.name,
    phone: phone,
    email: email ?? this.email,
    avatarUrl: avatarUrl ?? this.avatarUrl,
    status: status ?? this.status,
    managerCode: managerCode,
    rejectionReason: rejectionReason ?? this.rejectionReason,
    territory: territory,
    territoryFee: territoryFee,
    category: category,
    subCategory: subCategory,
    ownerName: ownerName ?? this.ownerName,
    rebatePercent: rebatePercent ?? this.rebatePercent,
    documentStatuses: documentStatuses ?? this.documentStatuses,
    documentUrls: documentUrls ?? this.documentUrls,
    driverDocumentStatuses: driverDocumentStatuses ?? this.driverDocumentStatuses,
    driverDocumentUrls: driverDocumentUrls ?? this.driverDocumentUrls,
    riskConsentAccepted: riskConsentAccepted ?? this.riskConsentAccepted,
    isOnline: isOnline ?? this.isOnline,
    isOpen: isOpen ?? this.isOpen,
    languageCode: languageCode ?? this.languageCode,
    deletedAt: deletedAt,
    bankAccountHolder: bankAccountHolder ?? this.bankAccountHolder,
    bankAccountNumber: bankAccountNumber ?? this.bankAccountNumber,
    bankIfsc: bankIfsc ?? this.bankIfsc,
  );
}
