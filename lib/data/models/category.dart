import 'package:flutter/material.dart';

/// [Category.icon] is stored in Firestore as one of these string keys
/// (`IconData` itself isn't serializable) — shared between the Firestore
/// read/write mapping (`firestore_categories_provider.dart`) and the icon
/// picker on Admin's "Add category" sheet, so every icon offered there has
/// somewhere to round-trip to.
const categoryIconChoices = <String, IconData>{
  'category': Icons.category_rounded,
  'restaurant': Icons.restaurant_rounded,
  'pharmacy': Icons.local_pharmacy_rounded,
  'grocery': Icons.local_grocery_store_rounded,
  'eco': Icons.eco_rounded,
  'seafood': Icons.set_meal_rounded,
  'florist': Icons.local_florist_rounded,
  'bakery': Icons.cake_rounded,
  'pets': Icons.pets_rounded,
  'cafe': Icons.local_cafe_rounded,
};

/// Admin-managed, reorderable category shown on the User Home screen (spec
/// §8.8 "Dynamic Categories") — deliberately separate from [VendorCategory]
/// so Admin can add future categories (meat/seafood, stationery, ...)
/// without touching the closed vendor-registration enum. Firestore-backed
/// (`firestore_categories_provider.dart`), same real/persistent pattern as
/// Territories and the Manager Directory.
class Category {
  const Category({
    required this.id,
    required this.name,
    required this.iconKey,
    this.hasOrderingWindow = false,
    this.windowLabel,
    this.isActive = true,
    this.sortOrder = 0,
    this.subcategories = const [],
  });

  final String id;
  final String name;
  final String iconKey;
  final bool hasOrderingWindow;
  final String? windowLabel;
  final bool isActive;
  final int sortOrder;

  /// Finer-grained groupings within this category (e.g. Food ->
  /// Restaurant/Fast Food/Tiffins/Bakery) — Admin-managed data, not a fixed
  /// enum, so Manager's "Add Vendor" subcategory picker
  /// (`manager_vendor_create_screen.dart`) stays in sync with whatever
  /// Admin has configured rather than a hardcoded list in that screen.
  /// Empty for categories with no subcategory breakdown.
  final List<String> subcategories;

  IconData get icon => categoryIconChoices[iconKey] ?? Icons.category_rounded;

  Category copyWith({bool? isActive, int? sortOrder}) => Category(
    id: id,
    name: name,
    iconKey: iconKey,
    hasOrderingWindow: hasOrderingWindow,
    windowLabel: windowLabel,
    isActive: isActive ?? this.isActive,
    sortOrder: sortOrder ?? this.sortOrder,
    subcategories: subcategories,
  );
}
