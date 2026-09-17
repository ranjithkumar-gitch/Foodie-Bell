import '../models/category.dart';
import '../models/vendor.dart';

/// Seed data for the Admin-managed dynamic category list (spec §8.8) — the
/// four categories Quicky launches with. Written once into Firestore's
/// `categories` collection by `firestore_categories_provider.dart` (doc ids
/// match [VendorCategory]'s names so they line up with the closed
/// vendor-registration enum); this list itself is no longer read directly
/// at runtime.
class MockCategories {
  MockCategories._();

  static final List<Category> seed = [
    Category(
      id: VendorCategory.food.name,
      name: VendorCategory.food.label,
      iconKey: 'restaurant',
      sortOrder: 0,
      subcategories: const ['Restaurant', 'Fast Food', 'Tiffins', 'Bakery'],
    ),
    Category(
      id: VendorCategory.pharmacy.name,
      name: VendorCategory.pharmacy.label,
      iconKey: 'pharmacy',
      sortOrder: 1,
    ),
    Category(
      id: VendorCategory.kirana.name,
      name: VendorCategory.kirana.label,
      iconKey: 'grocery',
      sortOrder: 2,
    ),
    Category(
      id: VendorCategory.vegetables.name,
      name: VendorCategory.vegetables.label,
      iconKey: 'eco',
      hasOrderingWindow: true,
      windowLabel: '10 AM - 6 PM',
      sortOrder: 3,
    ),
  ];
}
