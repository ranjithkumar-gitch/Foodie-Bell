import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/menu_item.dart';
import '../../models/restaurant.dart';
import '../../providers/cart_provider.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_network_image.dart';
import '../../widgets/menu_item_tile.dart';
import '../../widgets/rating_badge.dart';
import '../cart/cart_screen.dart';

class RestaurantDetailScreen extends ConsumerStatefulWidget {
  const RestaurantDetailScreen({super.key, required this.restaurant});

  final Restaurant restaurant;

  @override
  ConsumerState<RestaurantDetailScreen> createState() => _RestaurantDetailScreenState();
}

class _RestaurantDetailScreenState extends ConsumerState<RestaurantDetailScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController =
      TabController(length: widget.restaurant.menuCategories.length, vsync: this);

  Future<void> _addToCart(MenuItem item) async {
    final notifier = ref.read(cartProvider.notifier);
    final added = notifier.addItem(item, widget.restaurant);
    if (added) return;

    final shouldReplace = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _ReplaceCartSheet(newRestaurantName: widget.restaurant.name),
    );
    if (shouldReplace == true) {
      notifier.replaceWithItem(item, widget.restaurant);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final restaurant = widget.restaurant;
    final cart = ref.watch(cartProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 240,
            backgroundColor: AppColors.background,
            surfaceTintColor: Colors.transparent,
            leading: Padding(
              padding: const EdgeInsets.all(8),
              child: _CircleIconButton(icon: Icons.arrow_back_rounded, onTap: () => Navigator.pop(context)),
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.all(8),
                child: _CircleIconButton(icon: Icons.favorite_border_rounded, onTap: () {}),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  AppNetworkImage(url: restaurant.coverImageUrl, fit: BoxFit.cover),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.black.withValues(alpha: 0.0), Colors.black.withValues(alpha: 0.45)],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(restaurant.name, style: Theme.of(context).textTheme.displaySmall)),
                      RatingBadge(rating: restaurant.rating),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${restaurant.cuisineLabel} · ${restaurant.ratingCount} ratings',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        _InfoStat(icon: Icons.access_time_rounded, label: '${restaurant.deliveryTimeMinutes} min'),
                        _VerticalDivider(),
                        _InfoStat(
                          icon: Icons.moped_outlined,
                          label: restaurant.deliveryFee == 0 ? 'Free' : '\$${restaurant.deliveryFee.toStringAsFixed(2)}',
                        ),
                        _VerticalDivider(),
                        _InfoStat(icon: Icons.place_outlined, label: '${restaurant.distanceKm.toStringAsFixed(1)} km'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverPersistentHeader(
            pinned: true,
            delegate: _TabBarDelegate(
              TabBar(
                controller: _tabController,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                labelColor: AppColors.primary,
                unselectedLabelColor: AppColors.textSecondary,
                indicatorColor: AppColors.primary,
                indicatorSize: TabBarIndicatorSize.label,
                labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                tabs: [for (final c in restaurant.menuCategories) Tab(text: c)],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
            sliver: SliverList.separated(
              itemCount: _currentCategoryItems.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, i) {
                final item = _currentCategoryItems[i];
                return MenuItemTile(
                  item: item,
                  quantity: ref.read(cartProvider.notifier).quantityOf(item.id),
                  onAdd: () => _addToCart(item),
                  onIncrement: () => ref.read(cartProvider.notifier).increment(item.id),
                  onDecrement: () => ref.read(cartProvider.notifier).decrement(item.id),
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: cart.isEmpty || cart.restaurantId != restaurant.id
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CartScreen())),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text('${cart.totalQuantity} items', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                      ),
                      const Text('View Cart', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                      Text('\$${cart.subtotal.toStringAsFixed(2)}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  List<MenuItem> get _currentCategoryItems {
    final categories = widget.restaurant.menuCategories;
    if (categories.isEmpty) return const [];
    final selected = categories[_tabController.index];
    return widget.restaurant.menu.where((m) => m.category == selected).toList(growable: false);
  }
}

class _InfoStat extends StatelessWidget {
  const _InfoStat({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: AppColors.primary, size: 20),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5, color: AppColors.textPrimary)),
        ],
      ),
    );
  }
}

class _VerticalDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(width: 1, height: 32, color: AppColors.border);
}

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.35), shape: BoxShape.circle),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }
}

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  _TabBarDelegate(this.tabBar);
  final TabBar tabBar;

  @override
  double get minExtent => 48;
  @override
  double get maxExtent => 48;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return ColoredBox(color: AppColors.background, child: tabBar);
  }

  @override
  bool shouldRebuild(covariant _TabBarDelegate oldDelegate) => oldDelegate.tabBar != tabBar;
}

class _ReplaceCartSheet extends StatelessWidget {
  const _ReplaceCartSheet({required this.newRestaurantName});
  final String newRestaurantName;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 20),
          const Icon(Icons.shopping_bag_outlined, size: 40, color: AppColors.primary),
          const SizedBox(height: 14),
          Text('Start a new cart?', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(
            'Your cart has items from another restaurant. Add items from $newRestaurantName instead?',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Start New'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
