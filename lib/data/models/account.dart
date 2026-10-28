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
    this.territoryId,
    this.territoryFee = 200000,
    this.category,
    this.subCategory,
    this.ownerName,
    this.address,
    this.latitude,
    this.longitude,
    this.rebatePercent = 15,
    this.documentStatuses = const {},
    this.documentPaths = const {},
    this.coverPhotoUrl,
    this.driverDocumentStatuses = const {},
    this.driverDocumentPaths = const {},
    this.riskConsentAccepted = false,
    this.isOnline = false,
    this.isOpen = true,
    this.languageCode,
    this.deletedAt,
    this.bankAccountHolder,
    this.bankAccountNumber,
    this.bankIfsc,
    this.upiIds = const [],
    this.ratingAverage,
    this.ratingCount = 0,
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
  /// Vendor/Driver: the territory they operate in. Display name only —
  /// [territoryId] is what access control keys off.
  final String? territory;

  /// Manager/Vendor/Driver: the `territories` doc id they belong to — the
  /// same value the server puts in the account's `territoryId` claim, which
  /// Firestore rules scope a Manager's (and a Driver's offers') access by.
  final String? territoryId;

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

  /// Vendor-only: the shop's street address and its map position, set by
  /// the Vendor themselves from `vendor_profile_edit_screen.dart` — null
  /// until they've filled it in. [latitude]/[longitude] are always set
  /// together.
  final String? address;
  final double? latitude;
  final double? longitude;

  /// Vendor-only: the negotiated Manager/Company rebate split, 10-20 band
  /// (spec §5.5) — Manager-editable from the Vendor Detail screen.
  final double rebatePercent;

  /// Vendor-only: Manager sets which of the fixed document checklist
  /// applies to this vendor (required/not required); Vendor moves their own
  /// entries to submitted from their own login. Any [VendorDocumentType]
  /// missing from this map defaults to [VendorDocumentStatus.required] —
  /// see [documentStatus].
  final Map<VendorDocumentType, VendorDocumentStatus> documentStatuses;

  /// Vendor-only: Storage *path* of each document that's actually been
  /// uploaded (`vendor_document_storage_provider.dart`) — keyed the same as
  /// [documentStatuses]. Paths, not download URLs: a download URL works for
  /// anyone who has it, while a path only resolves to one for someone
  /// `storage.rules` lets read the file (the Vendor, their territory's
  /// Manager, the Super Admin) — see `KycImage`.
  final Map<VendorDocumentType, String> documentPaths;

  /// Vendor-only: public storefront photo shown to Customers — a copy of the
  /// shop-front document's download URL, kept separate so the KYC document
  /// itself can stay private.
  final String? coverPhotoUrl;

  /// Driver-only: same Required/Not Required/Submitted checklist as
  /// [documentStatuses], but keyed by [DriverDocumentType] — Manager sets
  /// which apply, only the signed-in Driver can move one to submitted (see
  /// `driver_document_checklist.dart`).
  final Map<DriverDocumentType, VendorDocumentStatus> driverDocumentStatuses;

  /// Driver-only: Storage path of each submitted document, mirrors
  /// [documentPaths] (`driver_document_storage_provider.dart`).
  final Map<DriverDocumentType, String> driverDocumentPaths;

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

  /// Vendor-only: UPI IDs (VPAs) customers pay this shop on directly when
  /// they choose UPI at checkout (`checkout_payment_screen.dart`). The first
  /// is the one payments go to; the rest are kept as alternates the Vendor
  /// can switch to from `vendor_upi_screen.dart`. Empty until set — the
  /// Vendor can't accept orders until they add one (`ensureVendorUpiSetUp`).
  final List<String> upiIds;

  /// Average review rating (1–5) and how many reviews it is from — kept on
  /// the Vendor/Driver record by the server (`onReviewWritten`), so screens
  /// never download the reviews to average them. Null until the first review.
  final double? ratingAverage;
  final int ratingCount;

  /// The UPI ID payments go to, or null when none is set.
  String? get primaryUpiId => upiIds.isEmpty ? null : upiIds.first;

  VendorDocumentStatus documentStatus(VendorDocumentType type) => documentStatuses[type] ?? VendorDocumentStatus.required;

  String? documentPath(VendorDocumentType type) => documentPaths[type];

  /// True once every document Manager marked required has been submitted —
  /// Manager Vendor Detail surfaces this as "Ready to Activate" while the
  /// vendor is still `pendingReview`.
  bool get readyToActivate => VendorDocumentType.values.every((t) => documentStatus(t) != VendorDocumentStatus.required);

  VendorDocumentStatus driverDocumentStatus(DriverDocumentType type) => driverDocumentStatuses[type] ?? VendorDocumentStatus.required;

  String? driverDocumentPath(DriverDocumentType type) => driverDocumentPaths[type];

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
    String? address,
    double? latitude,
    double? longitude,
    AccountStatus? status,
    String? rejectionReason,
    double? rebatePercent,
    Map<VendorDocumentType, VendorDocumentStatus>? documentStatuses,
    Map<VendorDocumentType, String>? documentPaths,
    String? coverPhotoUrl,
    String? territoryId,
    Map<DriverDocumentType, VendorDocumentStatus>? driverDocumentStatuses,
    Map<DriverDocumentType, String>? driverDocumentPaths,
    bool? riskConsentAccepted,
    bool? isOnline,
    bool? isOpen,
    String? languageCode,
    String? bankAccountHolder,
    String? bankAccountNumber,
    String? bankIfsc,
    List<String>? upiIds,
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
    territoryId: territoryId ?? this.territoryId,
    territoryFee: territoryFee,
    category: category,
    subCategory: subCategory,
    ownerName: ownerName ?? this.ownerName,
    address: address ?? this.address,
    latitude: latitude ?? this.latitude,
    longitude: longitude ?? this.longitude,
    rebatePercent: rebatePercent ?? this.rebatePercent,
    documentStatuses: documentStatuses ?? this.documentStatuses,
    documentPaths: documentPaths ?? this.documentPaths,
    coverPhotoUrl: coverPhotoUrl ?? this.coverPhotoUrl,
    driverDocumentStatuses: driverDocumentStatuses ?? this.driverDocumentStatuses,
    driverDocumentPaths: driverDocumentPaths ?? this.driverDocumentPaths,
    riskConsentAccepted: riskConsentAccepted ?? this.riskConsentAccepted,
    isOnline: isOnline ?? this.isOnline,
    isOpen: isOpen ?? this.isOpen,
    languageCode: languageCode ?? this.languageCode,
    deletedAt: deletedAt,
    bankAccountHolder: bankAccountHolder ?? this.bankAccountHolder,
    bankAccountNumber: bankAccountNumber ?? this.bankAccountNumber,
    bankIfsc: bankIfsc ?? this.bankIfsc,
    upiIds: upiIds ?? this.upiIds,
    ratingAverage: ratingAverage,
    ratingCount: ratingCount,
  );
}
