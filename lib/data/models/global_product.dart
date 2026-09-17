import 'tax_category.dart';
import 'vendor.dart';

/// A template product in Admin's platform-wide Global Catalogue — lets a
/// Vendor bulk-copy the common products for their category
/// (`vendor_global_catalogue_screen.dart`) instead of typing every one in
/// by hand via Add Product. Deliberately its own model rather than reusing
/// [Product]: a global entry isn't scoped to any one vendor, so unlike
/// [Product] it carries an explicit [category] — a vendor's own products
/// get theirs implicitly from the vendor itself.
class GlobalProduct {
  const GlobalProduct({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.imageUrl,
    required this.category,
    required this.subCategory,
    this.unit = '1 pc',
    this.isVeg,
    this.spiceLevel = 0,
    this.taxCategoryId,
    this.gstOverride,
  });

  final String id;
  final String name;
  final String description;
  final double price;
  final String imageUrl;
  final VendorCategory category;

  /// e.g. "Pizza", "Tablets", "Dairy", "Leafy Greens" — same grouping [Product] uses.
  final String subCategory;

  final String unit;

  /// Null when the veg/non-veg distinction doesn't apply (Pharmacy, Kirana non-food SKUs).
  final bool? isVeg;

  /// 0 = not spicy, 1-3 = mild to hot. Food category only.
  final int spiceLevel;

  /// FK into `tax_categories` — carried over onto a vendor's own [Product]
  /// copy when they "Copy to my catalogue" (`copyGlobalProducts`), same as
  /// every other field on this template.
  final String? taxCategoryId;
  final GstOverride? gstOverride;
}
