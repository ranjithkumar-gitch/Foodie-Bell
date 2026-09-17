import 'package:flutter/foundation.dart' show setEquals;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/account.dart';
import '../../../data/models/product.dart';
import '../../../data/models/vendor_document.dart';
import '../../../data/providers/cart_provider.dart';
import '../../../data/providers/firestore_categories_provider.dart';
import '../../../data/providers/firestore_products_provider.dart';
import '../../../data/providers/firestore_reviews_provider.dart';
import '../../../data/providers/firestore_vendors_provider.dart';
import '../../../l10n/app_localizations_context.dart';
import '../../../shared/error_reporting.dart';
import '../../../shared/widgets/app_network_image.dart';
import '../../../shared/widgets/currency_text.dart';
import '../translation/translated_text.dart';
import '../user_constants.dart';
import '../widgets/product_tile.dart';

/// "Order via Photo" (`list_order_capture_screen.dart`) is only worth
/// offering for vendors where customers realistically order off a photo of
/// what they want rather than a fixed catalogue — Pharmacy, Kirana/Grocery,
/// Vegetables & Fruits — not a restaurant/Food vendor's plated-menu
/// ordering. Checks
/// both [Category.id] and its display label since [Account.category] can
/// hold either (see `home_screen.dart`'s `matchesCategory` doc comment).
bool supportsListOrdering(Account account) {
  final raw = account.category?.toLowerCase() ?? '';
  return raw.contains('pharmacy') ||
      raw.contains('kirana') ||
      raw.contains('grocery') ||
      raw.contains('vegetable') ||
      raw.contains('fruit');
}

/// Vendor Storefront (spec §4.6): banner, product grid grouped by
/// sub-category — now backed by the real, Manager-approved Vendor `Account`
/// (`firestoreVendorsProvider`) and that vendor's real catalogue
/// (`vendorProductsProvider`) instead of the mock `Vendor`/`MockVendors`
/// model. Rating is real too (`firestoreReviewsProvider`, spec §4.15) —
/// tapping it opens the public reviews list every User can see, not just
/// this vendor's own "Reviews & Ratings" screen. No delivery-time/distance
/// shown — that data doesn't exist on a real vendor account.
class VendorDetailScreen extends ConsumerWidget {
  const VendorDetailScreen({super.key, required this.vendorId});

  final String vendorId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vendorsAsync = ref.watch(firestoreVendorsProvider);
    final productsAsync = ref.watch(vendorProductsProvider(vendorId));

    return vendorsAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, st) => Scaffold(
        appBar: AppBar(),
        body: Center(
          child: Text(
            friendlyError(e, action: 'Loading vendor', stackTrace: st),
          ),
        ),
      ),
      data: (vendors) {
        final account = vendors.where((a) => a.id == vendorId).firstOrNull;
        if (account == null) {
          return Scaffold(
            appBar: AppBar(),
            body: Center(child: Text(context.l10n.storefrontVendorNotFound)),
          );
        }
        return productsAsync.when(
          loading: () => Scaffold(
            appBar: AppBar(title: Text(account.name)),
            body: const Center(child: CircularProgressIndicator()),
          ),
          error: (e, st) => Scaffold(
            appBar: AppBar(title: Text(account.name)),
            body: Center(
              child: Text(
                friendlyError(e, action: 'Loading products', stackTrace: st),
              ),
            ),
          ),
          data: (products) =>
              _VendorDetailBody(account: account, products: products),
        );
      },
    );
  }
}

class _VendorDetailBody extends ConsumerStatefulWidget {
  const _VendorDetailBody({required this.account, required this.products});
  final Account account;
  final List<Product> products;

  @override
  ConsumerState<_VendorDetailBody> createState() => _VendorDetailBodyState();
}

class _VendorDetailBodyState extends ConsumerState<_VendorDetailBody>
    with SingleTickerProviderStateMixin {
  static const _expandedHeight = 200.0;

  late List<String> _subCategories;
  late TabController _tabController;
  final _scrollController = ScrollController();
  bool _showAppBarTitle = false;

  static List<String> _deriveSubCategories(List<Product> products) =>
      products.map((p) => p.subCategory).toSet().toList();

  @override
  void initState() {
    super.initState();
    _subCategories = _deriveSubCategories(widget.products);
    _tabController = TabController(length: _subCategories.length, vsync: this);
    _scrollController.addListener(_handleScroll);
  }

  // Firestore's product stream (`firestore_products_provider.dart`) can
  // emit more than once for the same screen visit — a fast, possibly-
  // incomplete snapshot from local cache first, then the full one from the
  // server. `_subCategories`/`_tabController` used to be `late final`,
  // computed once from whichever snapshot happened to arrive first: on a
  // cold cache that's the partial one, so some subcategories' tabs (and
  // every product under them) silently never appeared — "sometimes full
  // catalogue, sometimes broken," depending on cache timing. Recomputing
  // here on every `widget.products` update, and only actually rebuilding
  // the TabController when the *set* of subcategories genuinely changed
  // (not on every minor product-field refresh, so a price edit doesn't
  // reset whichever tab the User is looking at), fixes that at the source.
  @override
  void didUpdateWidget(covariant _VendorDetailBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    final updated = _deriveSubCategories(widget.products);
    if (!setEquals(updated.toSet(), _subCategories.toSet())) {
      final previousIndex = _tabController.index;
      _subCategories = updated;
      _tabController.dispose();
      _tabController = TabController(
        length: _subCategories.length,
        vsync: this,
        initialIndex: previousIndex < _subCategories.length ? previousIndex : 0,
      );
    }
  }

  // The app bar title only fades in once scroll has passed the point where
  // the header photo AND the "name below image" heading (right after it)
  // have both scrolled out of view — so the name visually hands off from
  // the body into the app bar as you scroll, rather than ever being drawn
  // over the shop-front photo itself.
  void _handleScroll() {
    final collapsed =
        _scrollController.offset >= _expandedHeight - kToolbarHeight;
    if (collapsed != _showAppBarTitle) {
      setState(() => _showAppBarTitle = collapsed);
    }
  }

  Future<void> _addToCart(Product product) async {
    if (!widget.account.isOpen) return;
    final notifier = ref.read(cartProvider.notifier);
    final added = notifier.addItem(
      product,
      vendorId: widget.account.id,
      vendorName: widget.account.name,
      deliveryFee: UserConstants.defaultDeliveryFee,
      rebatePercent: widget.account.rebatePercent,
    );
    if (added) return;

    final shouldReplace = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) =>
          _ReplaceCartSheet(newVendorName: widget.account.name),
    );
    if (shouldReplace == true) {
      notifier.replaceWithItem(
        product,
        vendorId: widget.account.id,
        vendorName: widget.account.name,
        deliveryFee: UserConstants.defaultDeliveryFee,
        rebatePercent: widget.account.rebatePercent,
      );
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_handleScroll);
    _scrollController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  List<Product> get _currentSubCategoryProducts {
    if (_subCategories.isEmpty) return const [];
    final selected = _subCategories[_tabController.index];
    return widget.products
        .where((p) => p.subCategory == selected)
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    final cart = ref.watch(cartProvider);
    final account = widget.account;
    final categoriesAsync = ref.watch(activeCategoriesProvider);
    // Matches on the category's display name too, not just its id — a
    // vendor's `category` field can hold either depending on when/how it
    // was set (see `home_screen.dart`'s `matchesCategory` doc comment).
    final categoryName =
        categoriesAsync.valueOrNull
            ?.where(
              (c) =>
                  c.id == account.category ||
                  c.name.toLowerCase() == account.category?.toLowerCase(),
            )
            .firstOrNull
            ?.name ??
        account.category;
    final coverUrl = account.documentUrl(VendorDocumentType.shopFrontPhoto);
    final vendorReviews =
        (ref.watch(firestoreReviewsProvider).valueOrNull ?? const [])
            .where((r) => r.vendorId == account.id)
            .toList();
    final reviewCount = vendorReviews.length;
    final averageRating = reviewCount == 0
        ? 0.0
        : vendorReviews.map((r) => r.vendorRating).reduce((a, b) => a + b) /
              reviewCount;

    return Scaffold(
      backgroundColor: palette.background,
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: _expandedHeight,
            backgroundColor: palette.background,
            surfaceTintColor: Colors.transparent,
            leading: Padding(
              padding: const EdgeInsets.all(8),
              child: _CircleIconButton(
                icon: Icons.arrow_back_rounded,
                onTap: () => context.pop(),
              ),
            ),
            title: AnimatedOpacity(
              opacity: _showAppBarTitle ? 1 : 0,
              duration: const Duration(milliseconds: 200),
              child: Text(
                account.name,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: palette.textPrimary,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  coverUrl != null
                      ? AppNetworkImage(url: coverUrl, fit: BoxFit.cover)
                      : Container(
                          color: palette.surfaceMuted,
                          child: Icon(
                            Icons.storefront_rounded,
                            size: 56,
                            color: palette.textMuted,
                          ),
                        ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.0),
                          Colors.black.withValues(alpha: 0.45),
                        ],
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
                  Text(
                    account.name,
                    style: Theme.of(context).textTheme.displaySmall,
                  ),
                  if (categoryName != null) ...[
                    const SizedBox(height: 6),
                    TranslatedText(
                      categoryName,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: palette.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: palette.border),
                    ),
                    child: Row(
                      children: [
                        _InfoStat(
                          icon: Icons.moped_outlined,
                          label: AppFormat.currency(
                            UserConstants.defaultDeliveryFee,
                          ),
                        ),
                        _VerticalDivider(),
                        _InfoStat(
                          icon: Icons.place_outlined,
                          label: account.territory ?? '—',
                        ),
                        _VerticalDivider(),
                        _InfoStat(
                          icon: Icons.star_rounded,
                          label: reviewCount == 0
                              ? context.l10n.storefrontNoRatings
                              : context.l10n.storefrontRatingSummary(
                                  averageRating.toStringAsFixed(1),
                                  reviewCount,
                                ),
                          onTap: () => context.push(
                            '/user/vendor/${account.id}/reviews',
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!account.isOpen) ...[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: palette.error.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: palette.error.withValues(alpha: 0.35),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.storefront_outlined,
                            color: palette.error,
                            size: 18,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              context.l10n.storefrontClosedMessage,
                              style: TextStyle(
                                color: palette.error,
                                fontWeight: FontWeight.w600,
                                fontSize: 12.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (account.isOpen && supportsListOrdering(account)) ...[
                    const SizedBox(height: 12),
                    InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => context.push(
                        '/user/vendor/${account.id}/list-order',
                        extra: account.name,
                      ),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: palette.promoGradient,
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.18),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.document_scanner_outlined,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Order via Photo',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 14.5,
                                    ),
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    'Snap a photo of what you want instead of browsing',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 11.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(
                              Icons.arrow_forward_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (_subCategories.isNotEmpty)
            SliverPersistentHeader(
              pinned: true,
              delegate: _TabBarDelegate(
                TabBar(
                  controller: _tabController,
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  labelColor: palette.primary,
                  unselectedLabelColor: palette.textSecondary,
                  indicatorColor: palette.primary,
                  indicatorSize: TabBarIndicatorSize.label,
                  labelStyle: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                  onTap: (_) => setState(() {}),
                  tabs: [
                    for (final c in _subCategories)
                      Tab(child: TranslatedText(c)),
                  ],
                ),
                background: palette.background,
              ),
            ),
          if (widget.products.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 60),
                child: Column(
                  children: [
                    Icon(
                      Icons.inventory_2_outlined,
                      size: 48,
                      color: palette.textMuted,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      context.l10n.storefrontNoProductsYet,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
              sliver: SliverList.separated(
                itemCount: _currentSubCategoryProducts.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, i) {
                  final product = _currentSubCategoryProducts[i];
                  return ProductTile(
                    product: product,
                    quantity: ref
                        .read(cartProvider.notifier)
                        .quantityOf(product.id),
                    onAdd: () => _addToCart(product),
                    onIncrement: () =>
                        ref.read(cartProvider.notifier).increment(product.id),
                    onDecrement: () =>
                        ref.read(cartProvider.notifier).decrement(product.id),
                    vendorClosed: !account.isOpen,
                  );
                },
              ),
            ),
        ],
      ),
      bottomNavigationBar: cart.isEmpty || cart.vendorId != account.id
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: ElevatedButton(
                  onPressed: () => context.go('/user/cart'),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          context.l10n.storefrontCartItemsBadge(
                            cart.totalQuantity,
                          ),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Text(
                        context.l10n.storefrontViewCart,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      CurrencyText(
                        cart.subtotal,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}

class _InfoStat extends StatelessWidget {
  const _InfoStat({required this.icon, required this.label, this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    final content = Column(
      children: [
        Icon(icon, color: palette.primary, size: 20),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 12.5,
            color: palette.textPrimary,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
    return Expanded(
      child: onTap == null
          ? content
          : InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(10),
              child: content,
            ),
    );
  }
}

class _VerticalDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      Container(width: 1, height: 32, color: context.colors.border);
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
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.35),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }
}

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  _TabBarDelegate(this.tabBar, {required this.background});
  final TabBar tabBar;
  final Color background;

  @override
  double get minExtent => 48;
  @override
  double get maxExtent => 48;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) => ColoredBox(color: background, child: tabBar);

  @override
  bool shouldRebuild(covariant _TabBarDelegate oldDelegate) =>
      oldDelegate.tabBar != tabBar;
}

class _ReplaceCartSheet extends StatelessWidget {
  const _ReplaceCartSheet({required this.newVendorName});
  final String newVendorName;

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: palette.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          Icon(Icons.shopping_bag_outlined, size: 40, color: palette.primary),
          const SizedBox(height: 14),
          Text(
            context.l10n.storefrontStartNewCartTitle,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            context.l10n.storefrontStartNewCartMessage(newVendorName),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text(context.l10n.actionCancel),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: Text(context.l10n.storefrontStartNew),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
