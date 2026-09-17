import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/account.dart';
import '../models/territory.dart';
import 'firestore_managers_provider.dart';

/// Admin's Territories list — real, persistent data (same Firestore-backed
/// pattern as `firestore_managers_provider.dart`). Purely a read of
/// whatever's actually in Firestore — no demo/mock records are seeded into
/// it.
const territoriesCollectionPath = 'territories';

CollectionReference<Map<String, dynamic>> get territoriesCollection =>
    FirebaseFirestore.instance.collection(territoriesCollectionPath);

Territory _territoryFromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
  final data = doc.data();
  return Territory(
    id: doc.id,
    name: data['name'] as String? ?? '',
    city: data['city'] as String?,
    zipcodes: (data['zipcodes'] as List<dynamic>? ?? const []).map((z) => z.toString()).toList(),
    assignedManagerId: data['assignedManagerId'] as String?,
    assignedManagerName: data['assignedManagerName'] as String?,
    deletedAt: (data['deletedAt'] as Timestamp?)?.toDate(),
    isActive: data['isActive'] as bool? ?? false,
    disabledCategoryIds: (data['disabledCategoryIds'] as List<dynamic>? ?? const []).map((id) => id.toString()).toList(),
  );
}

/// Every territory the User app can show — deleted ones excluded (as
/// before), and now also every territory Admin hasn't activated yet
/// (`territory_list_screen.dart`'s Activate/Deactivate in QuickyAdmin): a
/// territory mid-setup (Manager just assigned, vendors still being
/// onboarded) shouldn't be selectable in the "Deliver to" picker until
/// Admin says it's ready.
final firestoreTerritoriesProvider = StreamProvider<List<Territory>>((ref) {
  return territoriesCollection
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((snapshot) => snapshot.docs.map(_territoryFromDoc).where((t) => t.deletedAt == null && t.isActive).toList());
});

/// Soft-deletes a Territory (Admin-only, `territory_list_screen.dart`) —
/// callers must confirm [Territory.assignedManagerId] is already null
/// first; a Territory currently held by a Manager can't be deleted out from
/// under them.
Future<void> softDeleteTerritory(String territoryId) =>
    territoriesCollection.doc(territoryId).update({'deletedAt': FieldValue.serverTimestamp()});

/// Territories a Manager can actually be assigned to right now: unassigned
/// ones, plus ones whose recorded holder is no longer an active Manager
/// (suspended, or — if delete is ever added — gone entirely). This is a
/// live, derived computation over both streams rather than a stored
/// "available" flag, so there's nothing that can drift out of sync when a
/// Manager's status changes elsewhere.
final availableTerritoriesProvider = Provider<AsyncValue<List<Territory>>>((ref) {
  final territoriesAsync = ref.watch(firestoreTerritoriesProvider);
  final managers = ref.watch(firestoreManagersProvider).valueOrNull ?? const [];
  final activeManagerIds = managers.where((m) => m.status == AccountStatus.active).map((m) => m.id).toSet();

  return territoriesAsync.whenData(
    (territories) => territories.where((t) => t.assignedManagerId == null || !activeManagerIds.contains(t.assignedManagerId)).toList(),
  );
});

/// Assigns a Territory to a newly-created Manager — called once, right
/// after the Manager's Firebase user + Firestore record are created (see
/// `manager_create_screen.dart`). Overwrites any previous
/// `assignedManagerId` unconditionally: the caller is expected to have only
/// offered this territory as a choice because `availableTerritoriesProvider`
/// already confirmed its previous holder (if any) isn't active anymore.
Future<void> assignTerritory(String territoryId, {required String managerId, required String managerName}) {
  return territoriesCollection.doc(territoryId).update({
    'assignedManagerId': managerId,
    'assignedManagerName': managerName,
  });
}

/// A Manager turning a category on/off for their own territory
/// (`manager_categories_screen.dart`) — replaces the whole
/// [Territory.disabledCategoryIds] list with [disabledCategoryIds]; the
/// caller always sends the full intended list, not a single toggle.
Future<void> setTerritoryDisabledCategories(String territoryId, List<String> disabledCategoryIds) =>
    territoriesCollection.doc(territoryId).update({'disabledCategoryIds': disabledCategoryIds});
