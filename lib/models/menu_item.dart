class MenuItem {
  const MenuItem({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.imageUrl,
    required this.category,
    this.isVeg = true,
    this.isPopular = false,
    this.spiceLevel = 0,
  });

  final String id;
  final String name;
  final String description;
  final double price;
  final String imageUrl;
  final String category;
  final bool isVeg;
  final bool isPopular;

  /// 0 = not spicy, 1-3 = mild to hot.
  final int spiceLevel;
}
