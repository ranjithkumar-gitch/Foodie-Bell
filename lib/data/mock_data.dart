import '../models/menu_item.dart';
import '../models/restaurant.dart';

/// Static, in-memory catalog used to drive the UI. No network/backend yet.
class MockData {
  MockData._();

  static const List<String> categories = [
    'All',
    'Pizza',
    'Burgers',
    'Sushi',
    'Indian',
    'Mexican',
    'Healthy',
    'Desserts',
  ];

  static final List<Restaurant> restaurants = [
    Restaurant(
      id: 'r1',
      name: 'Bella Napoli',
      coverImageUrl:
          'https://images.unsplash.com/photo-1513104890138-7c749659a591?w=1000&q=80',
      cuisines: const ['Pizza', 'Italian'],
      rating: 4.7,
      ratingCount: 812,
      deliveryTimeMinutes: 25,
      deliveryFee: 1.99,
      distanceKm: 1.8,
      isPromoted: true,
      discountLabel: '20% OFF',
      menu: [
        const MenuItem(
          id: 'r1i1',
          name: 'Margherita Pizza',
          description: 'San Marzano tomato, fior di latte, fresh basil',
          price: 12.5,
          imageUrl:
              'https://images.unsplash.com/photo-1595854341625-f33ee10dbf94?w=800&q=80',
          category: 'Pizza',
          isPopular: true,
        ),
        const MenuItem(
          id: 'r1i2',
          name: 'Pepperoni Feast',
          description: 'Double pepperoni, mozzarella, oregano',
          price: 14.0,
          imageUrl:
              'https://images.unsplash.com/photo-1628840042765-356cda07504e?w=800&q=80',
          category: 'Pizza',
          isVeg: false,
          isPopular: true,
        ),
        const MenuItem(
          id: 'r1i3',
          name: 'Garlic Breadsticks',
          description: 'Baked to order with garlic butter & parmesan',
          price: 5.5,
          imageUrl:
              'https://images.unsplash.com/photo-1573140401552-3fab0b24427f?w=800&q=80',
          category: 'Starters',
        ),
        const MenuItem(
          id: 'r1i4',
          name: 'Caprese Salad',
          description: 'Buffalo mozzarella, heirloom tomato, basil oil',
          price: 8.0,
          imageUrl:
              'https://images.unsplash.com/photo-1592417817098-8fd3d9eb14a5?w=800&q=80',
          category: 'Starters',
        ),
        const MenuItem(
          id: 'r1i5',
          name: 'Tiramisu',
          description: 'Espresso-soaked ladyfingers, mascarpone cream',
          price: 6.5,
          imageUrl:
              'https://images.unsplash.com/photo-1571877227200-a0d98ea607e9?w=800&q=80',
          category: 'Desserts',
        ),
      ],
    ),
    Restaurant(
      id: 'r2',
      name: 'Smoke & Patty',
      coverImageUrl:
          'https://images.unsplash.com/photo-1571091718767-18b5b1457add?w=1000&q=80',
      cuisines: const ['Burgers', 'American'],
      rating: 4.5,
      ratingCount: 1204,
      deliveryTimeMinutes: 20,
      deliveryFee: 0.0,
      distanceKm: 1.2,
      isPromoted: true,
      discountLabel: 'Free delivery',
      menu: [
        const MenuItem(
          id: 'r2i1',
          name: 'Classic Smash Burger',
          description: 'Double smashed patty, cheddar, house sauce',
          price: 9.5,
          imageUrl:
              'https://images.unsplash.com/photo-1550547660-d9450f859349?w=800&q=80',
          category: 'Burgers',
          isVeg: false,
          isPopular: true,
        ),
        const MenuItem(
          id: 'r2i2',
          name: 'BBQ Bacon Burger',
          description: 'Smoked bacon, cheddar, crispy onions, BBQ sauce',
          price: 11.0,
          imageUrl:
              'https://images.unsplash.com/photo-1568901346375-23c9450c58cd?w=800&q=80',
          category: 'Burgers',
          isVeg: false,
          isPopular: true,
        ),
        const MenuItem(
          id: 'r2i3',
          name: 'Loaded Fries',
          description: 'Cheese sauce, jalapeños, crispy bacon bits',
          price: 6.0,
          imageUrl:
              'https://images.unsplash.com/photo-1585109649139-366815a0d713?w=800&q=80',
          category: 'Sides',
          isVeg: false,
        ),
        const MenuItem(
          id: 'r2i4',
          name: 'Onion Rings',
          description: 'Crispy battered onion rings with dip',
          price: 4.5,
          imageUrl:
              'https://images.unsplash.com/photo-1639024471283-03518883512d?w=800&q=80',
          category: 'Sides',
        ),
        const MenuItem(
          id: 'r2i5',
          name: 'Oreo Milkshake',
          description: 'Thick vanilla shake blended with Oreo crumble',
          price: 5.5,
          imageUrl:
              'https://images.unsplash.com/photo-1541658016709-82535e94bc69?w=800&q=80',
          category: 'Drinks',
        ),
      ],
    ),
    Restaurant(
      id: 'r3',
      name: 'Sakura Sushi Bar',
      coverImageUrl:
          'https://images.unsplash.com/photo-1553621042-f6e147245754?w=1000&q=80',
      cuisines: const ['Sushi', 'Japanese'],
      rating: 4.8,
      ratingCount: 956,
      deliveryTimeMinutes: 30,
      deliveryFee: 2.49,
      distanceKm: 3.1,
      menu: [
        const MenuItem(
          id: 'r3i1',
          name: 'Salmon Nigiri Set',
          description: '8 pieces of fresh salmon nigiri',
          price: 13.0,
          imageUrl:
              'https://images.unsplash.com/photo-1579584425555-c3ce17fd4351?w=800&q=80',
          category: 'Nigiri',
          isVeg: false,
          isPopular: true,
        ),
        const MenuItem(
          id: 'r3i2',
          name: 'Dragon Roll',
          description: 'Shrimp tempura, avocado, eel sauce',
          price: 12.0,
          imageUrl:
              'https://images.unsplash.com/photo-1617196034183-421b4917c92d?w=800&q=80',
          category: 'Rolls',
          isVeg: false,
          isPopular: true,
        ),
        const MenuItem(
          id: 'r3i3',
          name: 'Vegetable Gyoza',
          description: 'Pan-seared dumplings with ponzu dip',
          price: 7.0,
          imageUrl:
              'https://images.unsplash.com/photo-1496116218417-1a781b1c416c?w=800&q=80',
          category: 'Starters',
        ),
        const MenuItem(
          id: 'r3i4',
          name: 'Miso Soup',
          description: 'Tofu, wakame seaweed, scallion',
          price: 3.5,
          imageUrl:
              'https://images.unsplash.com/photo-1607301405390-d831c242f59b?w=800&q=80',
          category: 'Starters',
        ),
      ],
    ),
    Restaurant(
      id: 'r4',
      name: 'Spice Route',
      coverImageUrl:
          'https://images.unsplash.com/photo-1585937421612-70a008356fbe?w=1000&q=80',
      cuisines: const ['Indian', 'Curry'],
      rating: 4.6,
      ratingCount: 1489,
      deliveryTimeMinutes: 35,
      deliveryFee: 1.5,
      distanceKm: 2.4,
      discountLabel: '10% OFF',
      menu: [
        const MenuItem(
          id: 'r4i1',
          name: 'Butter Chicken',
          description: 'Tandoori chicken in creamy tomato gravy',
          price: 11.5,
          imageUrl:
              'https://images.unsplash.com/photo-1603894584373-5ac82b2ae398?w=800&q=80',
          category: 'Curry',
          isVeg: false,
          isPopular: true,
          spiceLevel: 1,
        ),
        const MenuItem(
          id: 'r4i2',
          name: 'Paneer Tikka Masala',
          description: 'Grilled cottage cheese in spiced curry',
          price: 10.0,
          imageUrl:
              'https://images.unsplash.com/photo-1631452180519-c014fe946bc7?w=800&q=80',
          category: 'Curry',
          isPopular: true,
          spiceLevel: 2,
        ),
        const MenuItem(
          id: 'r4i3',
          name: 'Garlic Naan',
          description: 'Tandoor-baked flatbread with garlic butter',
          price: 3.0,
          imageUrl:
              'https://images.unsplash.com/photo-1617692855027-33b14f061079?w=800&q=80',
          category: 'Breads',
        ),
        const MenuItem(
          id: 'r4i4',
          name: 'Chicken Biryani',
          description: 'Fragrant basmati rice, saffron, slow-cooked chicken',
          price: 12.5,
          imageUrl:
              'https://images.unsplash.com/photo-1633945274405-b6c8069047b0?w=800&q=80',
          category: 'Rice',
          isVeg: false,
          spiceLevel: 2,
        ),
        const MenuItem(
          id: 'r4i5',
          name: 'Gulab Jamun',
          description: 'Warm milk dumplings in rose sugar syrup',
          price: 4.5,
          imageUrl:
              'https://images.unsplash.com/photo-1601050690597-df0568f70950?w=800&q=80',
          category: 'Desserts',
        ),
      ],
    ),
    Restaurant(
      id: 'r5',
      name: 'El Taco Loco',
      coverImageUrl:
          'https://images.unsplash.com/photo-1565299585323-38d6b0865b47?w=1000&q=80',
      cuisines: const ['Mexican'],
      rating: 4.4,
      ratingCount: 673,
      deliveryTimeMinutes: 22,
      deliveryFee: 1.99,
      distanceKm: 1.6,
      menu: [
        const MenuItem(
          id: 'r5i1',
          name: 'Carne Asada Tacos',
          description: 'Grilled steak, onion, cilantro, salsa verde (3pc)',
          price: 9.0,
          imageUrl:
              'https://images.unsplash.com/photo-1551504734-5ee1c4a1479b?w=800&q=80',
          category: 'Tacos',
          isVeg: false,
          isPopular: true,
          spiceLevel: 2,
        ),
        const MenuItem(
          id: 'r5i2',
          name: 'Loaded Nachos',
          description: 'Beef, cheese, jalapeños, guacamole, sour cream',
          price: 8.5,
          imageUrl:
              'https://images.unsplash.com/photo-1582169296194-e4d644c48063?w=800&q=80',
          category: 'Starters',
          isVeg: false,
          spiceLevel: 1,
        ),
        const MenuItem(
          id: 'r5i3',
          name: 'Veggie Burrito Bowl',
          description: 'Cilantro rice, black beans, corn, pico de gallo',
          price: 8.0,
          imageUrl:
              'https://images.unsplash.com/photo-1626700051175-6818013e1d4f?w=800&q=80',
          category: 'Bowls',
        ),
      ],
    ),
    Restaurant(
      id: 'r6',
      name: 'Green Bowl Co.',
      coverImageUrl:
          'https://images.unsplash.com/photo-1512621776951-a57141f2eefd?w=1000&q=80',
      cuisines: const ['Healthy', 'Salads'],
      rating: 4.9,
      ratingCount: 421,
      deliveryTimeMinutes: 18,
      deliveryFee: 0.99,
      distanceKm: 0.9,
      discountLabel: 'New',
      menu: [
        const MenuItem(
          id: 'r6i1',
          name: 'Quinoa Power Bowl',
          description: 'Quinoa, kale, avocado, chickpeas, tahini dressing',
          price: 10.5,
          imageUrl:
              'https://images.unsplash.com/photo-1512621776951-a57141f2eefd?w=800&q=80',
          category: 'Bowls',
          isPopular: true,
        ),
        const MenuItem(
          id: 'r6i2',
          name: 'Grilled Chicken Salad',
          description: 'Mixed greens, grilled chicken, citrus vinaigrette',
          price: 11.0,
          imageUrl:
              'https://images.unsplash.com/photo-1546069901-ba9599a7e63c?w=800&q=80',
          category: 'Salads',
          isVeg: false,
          isPopular: true,
        ),
        const MenuItem(
          id: 'r6i3',
          name: 'Berry Smoothie Bowl',
          description: 'Acai, mixed berries, granola, banana',
          price: 8.5,
          imageUrl:
              'https://images.unsplash.com/photo-1484723091739-30a097e8f929?w=800&q=80',
          category: 'Bowls',
        ),
      ],
    ),
  ];

  static List<Restaurant> get promoted =>
      restaurants.where((r) => r.isPromoted).toList(growable: false);

  static List<Restaurant> byCategory(String category) {
    if (category == 'All') return restaurants;
    return restaurants
        .where((r) => r.cuisines.any((c) => c.toLowerCase() == category.toLowerCase()))
        .toList(growable: false);
  }
}
