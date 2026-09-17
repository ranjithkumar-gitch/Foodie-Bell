/// An Admin-defined operating territory — a named zone with the pincodes it
/// covers. Distinct from `Account.territory` (a denormalized display string
/// Managers carry once assigned), this is the master list Admin maintains
/// network-wide.
///
/// [assignedManagerId]/[assignedManagerName] record who currently holds
/// this territory — but that link alone doesn't mean the territory is
/// unavailable: a territory is only actually "taken" while the holding
/// Manager's `Account.status` is active. See `availableTerritoriesProvider`
/// in `firestore_territories_provider.dart`, which cross-references live
/// Manager status rather than trusting this field in isolation — that way
/// suspending (or, if ever added, deleting) a Manager frees their territory
/// up automatically, with nothing to keep in sync by hand.
class Territory {
  const Territory({
    required this.id,
    required this.name,
    required this.zipcodes,
    this.city,
    this.assignedManagerId,
    this.assignedManagerName,
    this.deletedAt,
    this.isActive = false,
    this.disabledCategoryIds = const [],
  });

  final String id;
  final String name;
  final String? city;
  final List<String> zipcodes;
  final String? assignedManagerId;
  final String? assignedManagerName;

  /// [Category.id]s this territory's Manager has turned off for their own
  /// territory (`manager_categories_screen.dart`) — on top of, never
  /// overriding, Admin's own global [Category.isActive] flag. Empty by
  /// default so an existing territory that's never touched this shows every
  /// globally-active category, same as before this feature existed. See
  /// `categoriesForTerritory` (`firestore_categories_provider.dart`), the
  /// one place this should be applied.
  final List<String> disabledCategoryIds;

  /// Set once Admin soft-deletes this territory — `firestoreTerritoriesProvider`
  /// filters these out entirely. Blocked while [assignedManagerId] is set
  /// (see `territory_list_screen.dart`'s `_delete`) — a Manager must be
  /// freed from it first.
  final DateTime? deletedAt;

  /// Whether Admin has activated this territory (QuickyAdmin's Territories
  /// screen) — until then it's still being set up (Manager assigned,
  /// vendors onboarded) and `firestoreTerritoriesProvider` here filters it
  /// out, so it never appears in the "Deliver to" picker or anywhere else
  /// a User could select it.
  final bool isActive;

  String get zipcodesLabel => zipcodes.join(', ');
}
