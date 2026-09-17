import 'tax_category.dart';

/// A single sellable item within a [Vendor]'s catalogue — a dish, a
/// medicine, a grocery SKU, or a bunch of vegetables. Generalizes the
/// original Food-only `MenuItem`.
class Product {
  const Product({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.imageUrl,
    required this.subCategory,
    this.unit = '1 pc',
    this.isVeg,
    this.isPopular = false,
    this.inStock = true,
    this.spiceLevel = 0,
    this.globalProductId,
    this.taxCategoryId,
    this.gstOverride,
  });

  final String id;
  final String name;
  final String description;
  final double price;
  final String imageUrl;

  /// e.g. "Pizza", "Tablets", "Dairy", "Leafy Greens" — grouping within a vendor.
  final String subCategory;

  /// e.g. "1 kg", "500 ml", "1 pc", "strip of 10".
  final String unit;

  /// Null when the veg/non-veg distinction doesn't apply (Pharmacy, Kirana non-food SKUs).
  final bool? isVeg;
  final bool isPopular;
  final bool inStock;

  /// 0 = not spicy, 1-3 = mild to hot. Food category only.
  final int spiceLevel;

  /// Set when this product was copied from Admin's Global Catalogue
  /// (`global_product.dart`, `vendor_global_catalogue_screen.dart`) rather
  /// than typed in by hand — traces back to the [GlobalProduct] it came
  /// from purely so that screen can show "Added" instead of "Copy" for one
  /// already in this vendor's catalogue. The copy itself is a fully
  /// independent doc from that point on: editing price/details here never
  /// touches the template, and a vendor-authored product just leaves this null.
  final String? globalProductId;

  /// FK into `tax_categories` (`firestore_tax_categories_provider.dart`) —
  /// the GST rate/HSN code this product inherits, suggested from its
  /// category + [subCategory] on the Add/Edit Product form
  /// (`suggestTaxCategory`) but stored explicitly rather than re-derived
  /// each time, so an Admin can point a specific product at a different
  /// bracket than its siblings without that being an "override".
  final String? taxCategoryId;

  /// A per-product exception to [taxCategoryId]'s rate — see
  /// [GstOverride]'s doc comment. Null for the overwhelming majority of
  /// products, which just inherit their tax category's rate as-is.
  final GstOverride? gstOverride;

  Product copyWith({bool? inStock, double? price}) => Product(
    id: id,
    name: name,
    description: description,
    price: price ?? this.price,
    imageUrl: imageUrl,
    subCategory: subCategory,
    unit: unit,
    isVeg: isVeg,
    isPopular: isPopular,
    inStock: inStock ?? this.inStock,
    spiceLevel: spiceLevel,
    globalProductId: globalProductId,
    taxCategoryId: taxCategoryId,
    gstOverride: gstOverride,
  );
}
