import 'menu_item.dart';

class Restaurant {
  const Restaurant({
    required this.id,
    required this.name,
    required this.coverImageUrl,
    required this.cuisines,
    required this.rating,
    required this.ratingCount,
    required this.deliveryTimeMinutes,
    required this.deliveryFee,
    required this.distanceKm,
    required this.menu,
    this.isPromoted = false,
    this.discountLabel,
  });

  final String id;
  final String name;
  final String coverImageUrl;
  final List<String> cuisines;
  final double rating;
  final int ratingCount;
  final int deliveryTimeMinutes;
  final double deliveryFee;
  final double distanceKm;
  final List<MenuItem> menu;
  final bool isPromoted;
  final String? discountLabel;

  String get cuisineLabel => cuisines.join(' • ');

  List<String> get menuCategories =>
      menu.map((item) => item.category).toSet().toList(growable: false);
}
