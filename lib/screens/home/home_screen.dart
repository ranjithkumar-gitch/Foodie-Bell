import 'package:flutter/material.dart';

import '../../data/mock_data.dart';
import '../../models/restaurant.dart';
import '../../theme/app_colors.dart';
import '../../widgets/category_chip.dart';
import '../../widgets/promo_card.dart';
import '../../widgets/restaurant_card.dart';
import '../restaurant/restaurant_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _selectedCategory = 'All';
  final _searchController = TextEditingController();

  List<Restaurant> get _filtered {
    final byCategory = MockData.byCategory(_selectedCategory);
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return byCategory;
    return byCategory
        .where((r) => r.name.toLowerCase().contains(query) || r.cuisineLabel.toLowerCase().contains(query))
        .toList(growable: false);
  }

  void _openRestaurant(Restaurant restaurant) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => RestaurantDetailScreen(restaurant: restaurant)),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final restaurants = _filtered;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Deliver to', style: Theme.of(context).textTheme.bodySmall),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  const Icon(Icons.place_rounded, size: 18, color: AppColors.primary),
                                  const SizedBox(width: 4),
                                  Text('Home · 221B Baker Street', style: Theme.of(context).textTheme.titleMedium),
                                  const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.textSecondary),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: AppColors.surfaceMuted,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(Icons.notifications_none_rounded, color: AppColors.textPrimary),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Text('Hungry, Alex?', style: Theme.of(context).textTheme.displaySmall),
                    const SizedBox(height: 4),
                    Text(
                      'Find the best meals around you',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 18),
                    TextField(
                      controller: _searchController,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        hintText: 'Search restaurants or dishes',
                        prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textMuted),
                        suffixIcon: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Container(
                            decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(10)),
                            child: const Icon(Icons.tune_rounded, color: Colors.white, size: 20),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 40,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: MockData.categories.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 10),
                  itemBuilder: (context, i) {
                    final category = MockData.categories[i];
                    return CategoryChip(
                      label: category,
                      selected: _selectedCategory == category,
                      onTap: () => setState(() => _selectedCategory = category),
                    );
                  },
                ),
              ),
            ),
            if (MockData.promoted.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 26, 20, 12),
                  child: Text('Promoted for you', style: Theme.of(context).textTheme.headlineSmall),
                ),
              ),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 150,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: MockData.promoted.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 14),
                    itemBuilder: (context, i) {
                      final restaurant = MockData.promoted[i];
                      return PromoCard(restaurant: restaurant, onTap: () => _openRestaurant(restaurant));
                    },
                  ),
                ),
              ),
            ],
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 26, 20, 14),
                child: Text(
                  _selectedCategory == 'All' ? 'All restaurants' : _selectedCategory,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
            ),
            if (restaurants.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 60),
                  child: Column(
                    children: [
                      const Icon(Icons.search_off_rounded, size: 48, color: AppColors.textMuted),
                      const SizedBox(height: 12),
                      Text('No restaurants found', style: Theme.of(context).textTheme.bodyMedium),
                    ],
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverList.separated(
                  itemCount: restaurants.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 16),
                  itemBuilder: (context, i) {
                    final restaurant = restaurants[i];
                    return RestaurantCard(restaurant: restaurant, onTap: () => _openRestaurant(restaurant));
                  },
                ),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ),
      ),
    );
  }
}
