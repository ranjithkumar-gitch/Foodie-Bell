import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../mock/mock_categories.dart';
import '../models/category.dart';
import '../models/territory.dart';

/// Admin's dynamic Category list — real, persistent data (same Firestore
/// pattern as Territories and the Manager Directory), seeded once from
/// [MockCategories.seed] (the four categories Quicky launches with).
/// Manager's "Add Vendor" screen reads [activeCategoriesProvider] so a new
/// vendor can be tagged with a real, Admin-managed category.
const categoriesCollectionPath = 'categories';

CollectionReference<Map<String, dynamic>> get categoriesCollection =>
    FirebaseFirestore.instance.collection(categoriesCollectionPath);

Map<String, dynamic> _categoryToDoc(Category category) => {
  'name': category.name,
  'iconKey': category.iconKey,
  'hasOrderingWindow': category.hasOrderingWindow,
  'windowLabel': category.windowLabel,
  'isActive': category.isActive,
  'sortOrder': category.sortOrder,
  'subcategories': category.subcategories,
};

Category _categoryFromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
  final data = doc.data();
  return Category(
    id: doc.id,
    name: data['name'] as String? ?? '',
    iconKey: data['iconKey'] as String? ?? 'category',
    hasOrderingWindow: data['hasOrderingWindow'] as bool? ?? false,
    windowLabel: data['windowLabel'] as String?,
    isActive: data['isActive'] as bool? ?? true,
    sortOrder: (data['sortOrder'] as num?)?.toInt() ?? 0,
    subcategories: (data['subcategories'] as List<dynamic>? ?? const []).map((s) => s.toString()).toList(),
  );
}

Future<void> _seedInitialCategoriesIfMissing() async {
  final snapshot = await categoriesCollection.get();
  if (snapshot.docs.isEmpty) {
    final batch = FirebaseFirestore.instance.batch();
    for (final category in MockCategories.seed) {
      batch.set(categoriesCollection.doc(category.id), {
        ..._categoryToDoc(category),
        'createdAt': Timestamp.fromDate(DateTime(2024, 1, 1)),
      });
    }
    await batch.commit();
    return;
  }
  // Backfill for environments seeded before `subcategories` existed on this
  // doc shape (e.g. this one, mid-development) — without this, Food's
  // subcategory picker on Add Vendor would silently stay empty even though
  // the seed data now defines options for it.
  for (final category in MockCategories.seed) {
    if (category.subcategories.isEmpty) continue;
    final doc = snapshot.docs.where((d) => d.id == category.id).firstOrNull;
    if (doc != null && doc.data()['subcategories'] == null) {
      await categoriesCollection.doc(category.id).update({'subcategories': category.subcategories});
    }
  }
}

final firestoreCategoriesProvider = StreamProvider<List<Category>>((ref) async* {
  await _seedInitialCategoriesIfMissing();
  yield* categoriesCollection
      .orderBy('sortOrder')
      .snapshots()
      .map((snapshot) => snapshot.docs.map(_categoryFromDoc).toList());
});

/// Categories a Vendor can actually be tagged with right now — Admin can
/// deactivate a category (e.g. seasonal) without deleting it outright, so
/// Manager's "Add Vendor" picker should only offer live ones.
final activeCategoriesProvider = Provider<AsyncValue<List<Category>>>((ref) {
  final categoriesAsync = ref.watch(firestoreCategoriesProvider);
  return categoriesAsync.whenData((categories) => categories.where((c) => c.isActive).toList());
});

Future<void> addCategory(Category category) => categoriesCollection.add({
  ..._categoryToDoc(category),
  'createdAt': FieldValue.serverTimestamp(),
});

Future<void> setCategoryActive(String categoryId, bool isActive) =>
    categoriesCollection.doc(categoryId).update({'isActive': isActive});

/// [categories] (normally [activeCategoriesProvider]'s list) narrowed to
/// what [territory] actually shows — its Manager's own on/off picks
/// (`manager_categories_screen.dart`, `Territory.disabledCategoryIds`)
/// layered on top of, never overriding, Admin's global active/inactive
/// call. `territory: null` (not yet resolved) shows every category passed
/// in, unfiltered — the same as before this feature existed. The one place
/// `Territory.disabledCategoryIds` should be read; every other screen goes
/// through this rather than checking the list itself.
List<Category> categoriesForTerritory(List<Category> categories, Territory? territory) {
  if (territory == null || territory.disabledCategoryIds.isEmpty) return categories;
  return categories.where((c) => !territory.disabledCategoryIds.contains(c.id)).toList();
}
