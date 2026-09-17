import 'package:flutter/material.dart';

import 'product.dart';

/// The four categories Quicky launches with (spec §2). Admin's dynamic
/// category list (see [Category]) can add more later without touching this
/// enum — it only backs the Vendor/registration/catalogue data shape.
enum VendorCategory { food, pharmacy, kirana, vegetables }

extension VendorCategoryX on VendorCategory {
  String get label => switch (this) {
    VendorCategory.food => 'Food',
    VendorCategory.pharmacy => 'Pharmacy',
    VendorCategory.kirana => 'Kirana & Grocery',
    VendorCategory.vegetables => 'Vegetables & Fruits',
  };

  IconData get icon => switch (this) {
    VendorCategory.food => Icons.restaurant_rounded,
    VendorCategory.pharmacy => Icons.local_pharmacy_rounded,
    VendorCategory.kirana => Icons.local_grocery_store_rounded,
    VendorCategory.vegetables => Icons.eco_rounded,
  };

  /// Vegetables & Fruits enforces a 10 AM - 6 PM ordering window (spec §2, §5.4).
  bool get hasOrderingWindow => this == VendorCategory.vegetables;
}

/// A vendor storefront (spec §4.6 "Vendor Storefront"), generalized across
/// all four categories so the same model drives User browsing screens and
/// the Vendor role's own catalogue-management screens.
class Vendor {
  const Vendor({
    required this.id,
    required this.name,
    required this.category,
    required this.coverImageUrl,
    required this.tags,
    required this.rating,
    required this.ratingCount,
    required this.deliveryTimeMinutes,
    required this.deliveryFee,
    required this.distanceKm,
    required this.products,
    this.isOpen = true,
    this.isPromoted = false,
    this.discountLabel,
    this.rebatePercent = 15,
    this.managerId = 'mgr1',
  });

  final String id;
  final String name;
  final VendorCategory category;
  final String coverImageUrl;
  final List<String> tags;
  final double rating;
  final int ratingCount;
  final int deliveryTimeMinutes;
  final double deliveryFee;
  final double distanceKm;
  final List<Product> products;
  final bool isOpen;
  final bool isPromoted;
  final String? discountLabel;

  /// Rebate % the Manager negotiated with this vendor (10-20 band, spec §5.5).
  final double rebatePercent;
  final String managerId;

  String get tagLabel => tags.join(' • ');

  List<String> get productSubCategories =>
      products.map((p) => p.subCategory).toSet().toList(growable: false);
}
