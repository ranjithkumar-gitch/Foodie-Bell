import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/branding/branding_controller.dart';
import '../../../core/session/session_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/account.dart';
import '../../../data/models/category.dart';
import '../../../data/models/coupon.dart';
import '../../../data/models/list_order_request.dart';
import '../../../data/models/order.dart';
import '../../../data/models/promotion.dart';
import '../../../data/models/territory.dart';
import '../../../data/providers/cart_provider.dart';
import '../../../data/providers/device_position_provider.dart';
import '../../../data/providers/firestore_categories_provider.dart';
import '../../../data/providers/firestore_coupons_provider.dart';
import '../../../data/providers/firestore_list_order_requests_provider.dart';
import '../../../data/providers/firestore_orders_provider.dart';
import '../../../data/providers/firestore_products_provider.dart';
import '../../../data/providers/firestore_promotions_provider.dart';
import '../../../data/providers/firestore_reviews_provider.dart';
import '../../../data/providers/firestore_territories_provider.dart';
import '../../../data/providers/firestore_vendors_provider.dart';
import '../../../data/providers/order_codes_provider.dart';
import '../../../l10n/app_localizations_context.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/error_reporting.dart';
import '../../../shared/widgets/app_network_image.dart';
import '../../../shared/widgets/currency_text.dart';
import '../../../shared/widgets/driver_live_map.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/order_status_timestamp.dart';
import '../../../shared/widgets/promotion_card_visual.dart';
import '../../../shared/widgets/status_chip.dart';
import '../orders/order_tracking_widgets.dart';
import '../translation/translated_text.dart';
import '../widgets/category_chip.dart';
import '../widgets/vendor_account_card.dart';
import '../widgets/vendor_distance.dart';
import 'selected_territory_provider.dart';

/// User Home (spec §4.4): territory picker, category chips, and the list of
/// real, Manager-approved Vendor accounts in that territory/category —
/// replaces the old fully-mock `MockVendors` catalogue so a Vendor a
/// Manager actually onboarded and approved shows up here.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  Category? _selectedCategory;
  // Categories load async (Firestore), so the "default to Food" pick can't
  // happen in initState — this fires once, the first build after the real
  // category list arrives, and never again, so it doesn't fight a User's
  // own selection (including deliberately clearing back to "all").
  bool _defaultCategoryApplied = false;
  // Null = "All" — the trending-dish filter row shown only under the Food
  // category (see `_isFoodCategory`), same idea as Search's own trending
  // chips (`search_screen.dart`) but selectable/highlightable here since
  // it filters the vendor list below instead of firing off a search.
  String? _selectedTrendingItem;

  // Swiggy/Zomato-style quick filters above the vendor list — independent
  // of the category/trending selection, and kept across category switches.
  bool _filterOpenNow = false;
  bool _filterRating4 = false;
  bool _filterPureVeg = false;
  bool _sortNearest = false;

  bool get _anyQuickFilter =>
      _filterOpenNow || _filterRating4 || _filterPureVeg || _sortNearest;

  void _clearQuickFilters() => setState(() {
    _filterOpenNow = false;
    _filterRating4 = false;
    _filterPureVeg = false;
    _sortNearest = false;
  });

  bool get _isFoodCategory =>
      _selectedCategory != null &&
      (_selectedCategory!.id.toLowerCase() == 'food' ||
          _selectedCategory!.name.toLowerCase() == 'food');

  List<String> _fallbackTrending(AppLocalizations l10n) => [
    l10n.searchFallbackBiryani,
    l10n.searchFallbackBurgers,
    l10n.searchFallbackVitaminC,
    l10n.searchFallbackFreshVegetables,
    l10n.searchFallbackMilkshake,
  ];

  /// Same computation as Search's own `_trendingTerms` — product names
  /// ordered most often across every User on the platform, most-ordered
  /// first, falling back to a small static list only when there's no order
  /// history yet to compute from.
  List<String> _trendingTerms(List<Order> orders, AppLocalizations l10n) {
    final counts = <String, int>{};
    for (final order in orders) {
      for (final item in order.items) {
        counts.update(
          item.name,
          (c) => c + item.quantity,
          ifAbsent: () => item.quantity,
        );
      }
    }
    if (counts.isEmpty) return _fallbackTrending(l10n);
    final names = counts.keys.toList()
      ..sort((a, b) => counts[b]!.compareTo(counts[a]!));
    return names.take(6).toList();
  }

  // viewportFraction < 1 is what gives the peeking-neighbor-card look
  // (Swiggy/Zomato's promo carousel) instead of one full-width card per
  // page with dead space on either side.
  final _promoPageController = PageController(viewportFraction: 0.86);
  int _promoPageIndex = 0;
  int _promoCount = 0;
  Timer? _promoAutoScrollTimer;

  @override
  void initState() {
    super.initState();
    _promoAutoScrollTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _advancePromoPage(),
    );
  }

  void _advancePromoPage() {
    if (!_promoPageController.hasClients || _promoCount <= 1) return;
    final next = (_promoPageIndex + 1) % _promoCount;
    _promoPageController.animateToPage(
      next,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
    );
  }

  void _openVendor(Account account) =>
      context.push('/user/vendor/${account.id}');

  Future<void> _openTerritoryPicker(List<Territory> territories) async {
    final picked = await showModalBottomSheet<Territory>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _TerritoryPickerSheet(territories: territories),
    );
    if (picked != null) {
      ref.read(selectedTerritoryProvider.notifier).state = picked;
      // A category chip selected for the previous territory may not apply
      // to this one at all — leaving it selected would silently filter the
      // new territory down to zero vendors, which reads as "nothing was
      // fetched" even though the switch worked correctly. Reset to "All"
      // so the newly picked territory's vendors are actually visible.
      // The trending-dish filter goes with it — it's Food-specific and
      // meaningless once the category filter itself is cleared.
      setState(() {
        _selectedCategory = null;
        _selectedTrendingItem = null;
      });
    }
  }

  @override
  void dispose() {
    _promoAutoScrollTimer?.cancel();
    _promoPageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    final account = ref.watch(
      sessionControllerProvider.select((s) => s.account),
    );
    final territoriesAsync = ref.watch(firestoreTerritoriesProvider);
    final territories = territoriesAsync.valueOrNull ?? const [];
    final selectedTerritory =
        ref.watch(selectedTerritoryProvider) ??
        resolveDefaultTerritory(territories);
    final categoriesAsync = ref.watch(activeCategoriesProvider);
    final categories = categoriesForTerritory(
      categoriesAsync.valueOrNull ?? const [],
      selectedTerritory,
    );
    if (!_defaultCategoryApplied && categories.isNotEmpty) {
      _defaultCategoryApplied = true;
      _selectedCategory = categories
          .where(
            (c) =>
                c.id.toLowerCase() == 'food' || c.name.toLowerCase() == 'food',
          )
          .firstOrNull;
    }
    final vendorsAsync = ref.watch(firestoreVendorsProvider);
    final firstName = account?.name.split(' ').first ?? 'there';
    final allOrders =
        ref.watch(firestoreOrdersProvider).valueOrNull ?? const [];
    final activeOrders =
        allOrders
            .where((o) => o.userId == account?.id && !o.status.isTerminal)
            .toList()
          ..sort((a, b) => b.placedAt.compareTo(a.placedAt));
    // Trending-dish chips under the Food category — same "most-ordered
    // product names, platform-wide" computation Search's own trending row
    // uses (`search_screen.dart`), just selectable here instead of firing
    // a search: picking one narrows the Food vendor list below to vendors
    // that actually sell it.
    final trendingTerms = _isFoodCategory
        ? _trendingTerms(allOrders, context.l10n)
        : const <String>[];
    final trendingVendorIds = (_isFoodCategory && _selectedTrendingItem != null)
        ? (ref.watch(allProductsProvider).valueOrNull ?? const [])
              .where(
                (r) =>
                    r.product.inStock &&
                    r.product.name.toLowerCase() ==
                        _selectedTrendingItem!.toLowerCase(),
              )
              .map((r) => r.vendorId)
              .toSet()
        : null;
    // Photo-order requests that haven't become a real Order yet (see
    // `list_order_status_screen.dart`) — once the vendor confirms
    // (`accepted`), the request hands off to a real `Order` which already
    // shows up in [activeOrders] above, so it's excluded here to avoid
    // showing the same order twice.
    const activePhotoStatuses = {
      ListOrderStatus.pending,
      ListOrderStatus.quoted,
      ListOrderStatus.paid,
    };
    final activePhotoOrders =
        (ref.watch(firestoreListOrderRequestsProvider).valueOrNull ?? const [])
            .where(
              (r) =>
                  r.userId == account?.id &&
                  activePhotoStatuses.contains(r.status),
            )
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    // isLiveNow requires status == active AND today within the vendor-picked
    // start/duration window — a Manager-approved promotion scheduled for a
    // future date, or one whose run has ended, correctly stays hidden here
    // without needing its status flipped by anything.
    final promotedVendors =
        (ref.watch(firestorePromotionsProvider).valueOrNull ?? const [])
            .where(
              (p) => p.isLiveNow && p.matchesTerritory(selectedTerritory?.name),
            )
            .toList();
    // Coupons published below Promotions — only from vendors that are
    // actually orderable right now (active + in the selected territory),
    // same gating `territoryVendors` below applies to the vendor list
    // itself, so a coupon never routes a User to a vendor they can't order
    // from.
    final orderableVendorIds = (vendorsAsync.valueOrNull ?? const [])
        .where(
          (a) =>
              a.status == AccountStatus.active &&
              (selectedTerritory == null ||
                  a.territory == selectedTerritory.name),
        )
        .map((a) => a.id)
        .toSet();
    final liveCoupons =
        (ref.watch(firestoreCouponsProvider).valueOrNull ?? const [])
            .where(
              (c) => c.isLiveNow && orderableVendorIds.contains(c.vendorId),
            )
            .toList();
    // QuickyAdmin-activated occasion theme's dashboard banner image
    // (`Quicky_Branding_UserApp.md`) — layered behind the same gradient
    // wash Home already uses, rather than replacing it, so header text
    // stays legible over whatever photo an occasion picks.
    final dashboardThemeUrl = ref
        .watch(activeBrandThemeProvider)
        ?.dashboardThemeUrl;
    final position = ref.watch(devicePositionProvider).valueOrNull;
    // Average rating per vendor, computed once here for the "Rated 4.0+"
    // filter rather than per card.
    final ratingSums = <String, ({double sum, int count})>{};
    for (final r in ref.watch(firestoreReviewsProvider).valueOrNull ?? const []) {
      final prev = ratingSums[r.vendorId];
      ratingSums[r.vendorId] = (
        sum: (prev?.sum ?? 0) + r.vendorRating,
        count: (prev?.count ?? 0) + 1,
      );
    }
    double? ratingOf(String vendorId) {
      final s = ratingSums[vendorId];
      return s == null ? null : s.sum / s.count;
    }

    // "Pure Veg" = every product the vendor lists is marked veg. Only
    // watched while that filter is on, so Home doesn't stream the whole
    // product catalogue just to sit there.
    Set<String>? pureVegVendorIds;
    if (_filterPureVeg) {
      final hasNonVeg = <String>{};
      final hasVeg = <String>{};
      for (final r in ref.watch(allProductsProvider).valueOrNull ?? const []) {
        if (r.product.isVeg == true) {
          hasVeg.add(r.vendorId);
        } else {
          hasNonVeg.add(r.vendorId);
        }
      }
      pureVegVendorIds = hasVeg.difference(hasNonVeg);
    }

    List<Account> applyQuickFilters(List<Account> vendors) {
      var result = vendors.where((v) {
        if (_filterOpenNow && !v.isOpen) return false;
        if (_filterRating4 && (ratingOf(v.id) ?? 0) < 4) return false;
        if (pureVegVendorIds != null && !pureVegVendorIds.contains(v.id)) {
          return false;
        }
        return true;
      }).toList();
      // Open vendors always above closed ones (stable — keeps the existing
      // order within each group); "Nearest" then sorts by distance, vendors
      // with no pinned location last.
      int openRank(Account v) => v.isOpen ? 0 : 1;
      if (_sortNearest && position != null) {
        double dist(Account v) => vendorDistanceKm(v, position) ?? double.infinity;
        result.sort((a, b) {
          final byOpen = openRank(a).compareTo(openRank(b));
          return byOpen != 0 ? byOpen : dist(a).compareTo(dist(b));
        });
      } else {
        result = [
          ...result.where((v) => v.isOpen),
          ...result.where((v) => !v.isOpen),
        ];
      }
      return result;
    }

    // "Order again" — vendors this User has had orders delivered from,
    // most recent first, limited to ones still orderable in this territory.
    final allVendorsById = {
      for (final v in vendorsAsync.valueOrNull ?? const <Account>[]) v.id: v,
    };
    final pastOrders =
        allOrders
            .where(
              (o) =>
                  o.userId == account?.id &&
                  o.status == OrderStatus.delivered,
            )
            .toList()
          ..sort((a, b) => b.placedAt.compareTo(a.placedAt));
    final orderAgainVendors = <Account>[];
    for (final o in pastOrders) {
      final v = allVendorsById[o.vendorId];
      if (v == null ||
          !orderableVendorIds.contains(v.id) ||
          orderAgainVendors.any((x) => x.id == v.id)) {
        continue;
      }
      orderAgainVendors.add(v);
      if (orderAgainVendors.length == 10) break;
    }
    final cart = ref.watch(cartProvider);

    return Scaffold(
      backgroundColor: palette.background,
      body: Stack(
        children: [
          if (dashboardThemeUrl != null)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 280,
              child: CachedNetworkImage(
                imageUrl: dashboardThemeUrl,
                fit: BoxFit.cover,
                alignment: Alignment.topCenter,
                errorWidget: (_, _, _) => const SizedBox.shrink(),
                placeholder: (_, _) => const SizedBox.shrink(),
              ),
            ),
          DecoratedBox(
            // A soft brand-green wash behind the top of the page — fades into
            // the normal background by the time content scrolls under it, so
            // it reads as an accent rather than tinting the whole screen. Also
            // doubles as the scrim over an active occasion's dashboard banner
            // image above, keeping header text legible either way.
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: dashboardThemeUrl != null
                    ? [
                        palette.background.withValues(alpha: 0.05),
                        palette.background.withValues(alpha: 0.55),
                        palette.background,
                      ]
                    : [
                        palette.primaryLight.withValues(alpha: 0.22),
                        palette.primaryLight.withValues(alpha: 0.05),
                        palette.background,
                      ],
                stops: const [0.0, 0.22, 0.5],
              ),
            ),
            child: SafeArea(
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
                                child: InkWell(
                                  onTap: territories.isEmpty
                                      ? null
                                      : () => _openTerritoryPicker(territories),
                                  borderRadius: BorderRadius.circular(10),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        context.l10n.homeSelectedTerritoryLabel,
                                        style: Theme.of(
                                          context,
                                        ).textTheme.bodySmall,
                                      ),
                                      const SizedBox(height: 2),
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.place_rounded,
                                            size: 18,
                                            color: palette.primary,
                                          ),
                                          const SizedBox(width: 4),
                                          Flexible(
                                            child: Text(
                                              selectedTerritory?.name ??
                                                  (territoriesAsync.isLoading
                                                      ? context
                                                            .l10n
                                                            .homeLoadingTerritories
                                                      : context
                                                            .l10n
                                                            .homeSelectTerritory),
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .titleMedium
                                                  ?.copyWith(
                                                    color: palette.primary,
                                                  ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          Icon(
                                            Icons.keyboard_arrow_down_rounded,
                                            color: palette.primary,
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              // Was the notification bell — this spot now
                              // just shows who's signed in: the account's
                              // avatar, or its first-name initial when
                              // there isn't one. Plain display, no
                              // onTap/action.
                              account?.avatarUrl != null
                                  ? AppNetworkImage(
                                      url: account!.avatarUrl!,
                                      width: 44,
                                      height: 44,
                                      borderRadius: BorderRadius.circular(22),
                                    )
                                  : Container(
                                      width: 44,
                                      height: 44,
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        color: palette.primary.withValues(
                                          alpha: 0.1,
                                        ),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Text(
                                        firstName.isEmpty
                                            ? '?'
                                            : firstName[0].toUpperCase(),
                                        style: TextStyle(
                                          color: palette.primary,
                                          fontWeight: FontWeight.w800,
                                          fontSize: 18,
                                        ),
                                      ),
                                    ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          InkWell(
                            onTap: () => context.push('/user/search'),
                            borderRadius: BorderRadius.circular(18),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                              decoration: BoxDecoration(
                                color: palette.surface,
                                borderRadius: BorderRadius.circular(18),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.05),
                                    blurRadius: 16,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.search_rounded,
                                    color: palette.primary,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      context.l10n.searchHint,
                                      style: TextStyle(
                                        color: palette.textMuted,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    width: 30,
                                    height: 30,
                                    decoration: BoxDecoration(
                                      color: palette.primary.withValues(
                                        alpha: 0.1,
                                      ),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Icon(
                                      Icons.tune_rounded,
                                      size: 16,
                                      color: palette.primary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),
                  // Promotions moved above the active-order tracking card
                  // (was below it) — right under the search bar, first
                  // thing after it, same as Swiggy/Zomato's own promo
                  // carousel placement.
                  if (promotedVendors.isNotEmpty)
                    SliverToBoxAdapter(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Builder(
                            builder: (context) {
                              // True 3:2 frame sized off the card's actual
                              // on-screen width, not a guessed fixed pixel
                              // height — otherwise AppNetworkImage's
                              // BoxFit.cover would crop the image to
                              // whatever mismatched ratio the SizedBox
                              // happened to force. Width is the *page's*
                              // width (viewportFraction of the full
                              // screen), not the screen width itself, since
                              // each page no longer spans edge to edge.
                              final pageWidth =
                                  MediaQuery.sizeOf(context).width * 0.86;
                              final cardWidth = pageWidth - 16;
                              final imageHeight = cardWidth * 2 / 3;
                              _promoCount = promotedVendors.length;
                              return SizedBox(
                                height: imageHeight,
                                child: PageView.builder(
                                  controller: _promoPageController,
                                  // Without this, the default PageView
                                  // centers page 0 by leaving empty leading
                                  // space equal to the viewport's own
                                  // margin — that reads as a layout bug
                                  // (a blank gap before the first card)
                                  // rather than the peeking-neighbor effect
                                  // this is going for. false + the item's
                                  // own edge padding below is what actually
                                  // lines the first/last card up with the
                                  // rest of the page's 20px margin while
                                  // letting the ones in between peek.
                                  padEnds: false,
                                  itemCount: promotedVendors.length,
                                  onPageChanged: (i) =>
                                      setState(() => _promoPageIndex = i),
                                  itemBuilder: (context, i) => AnimatedBuilder(
                                    animation: _promoPageController,
                                    builder: (context, child) {
                                      var scale = 1.0;
                                      var opacity = 1.0;
                                      if (_promoPageController
                                          .position
                                          .haveDimensions) {
                                        final distance =
                                            (_promoPageController.page! - i)
                                                .abs()
                                                .clamp(0.0, 1.0);
                                        scale = 1 - (distance * 0.08);
                                        opacity = 1 - (distance * 0.4);
                                      }
                                      return Opacity(
                                        opacity: opacity,
                                        child: Transform.scale(
                                          scale: scale,
                                          child: child,
                                        ),
                                      );
                                    },
                                    child: Padding(
                                      padding: EdgeInsets.only(
                                        left: i == 0 ? 20 : 8,
                                        right: i == promotedVendors.length - 1
                                            ? 20
                                            : 8,
                                      ),
                                      child: _PromotedVendorCard(
                                        promotion: promotedVendors[i],
                                        imageHeight: imageHeight,
                                        onTap: promotedVendors[i].isAppPromotion
                                            ? null
                                            : () => context.push(
                                                '/user/vendor/${promotedVendors[i].vendorId}',
                                              ),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                          if (promotedVendors.length > 1) ...[
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                for (var i = 0; i < promotedVendors.length; i++)
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    margin: const EdgeInsets.symmetric(
                                      horizontal: 3,
                                    ),
                                    width: _promoPageIndex == i ? 18 : 6,
                                    height: 6,
                                    decoration: BoxDecoration(
                                      color: _promoPageIndex == i
                                          ? palette.primary
                                          : palette.border,
                                      borderRadius: BorderRadius.circular(3),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  if (activeOrders.isNotEmpty || activePhotoOrders.isNotEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            for (final request in activePhotoOrders) ...[
                              _ActivePhotoOrderCard(request: request),
                              const SizedBox(height: 12),
                            ],
                            for (final order in activeOrders) ...[
                              _ActiveOrderCard(order: order),
                              const SizedBox(height: 12),
                            ],
                          ],
                        ),
                      ),
                    ),
                  if (liveCoupons.isNotEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 0, 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(
                                right: 20,
                                bottom: 12,
                              ),
                              child: Text(
                                'Coupons',
                                style: Theme.of(
                                  context,
                                ).textTheme.headlineSmall,
                              ),
                            ),
                            SizedBox(
                              height: 92,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount: liveCoupons.length,
                                separatorBuilder: (_, _) =>
                                    const SizedBox(width: 12),
                                itemBuilder: (context, i) => Padding(
                                  padding: EdgeInsets.only(
                                    right: i == liveCoupons.length - 1 ? 20 : 0,
                                  ),
                                  child: _CouponCard(coupon: liveCoupons[i]),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (orderAgainVendors.isNotEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                              child: Text(
                                context.l10n.homeOrderAgainTitle,
                                style: Theme.of(context).textTheme.headlineSmall,
                              ),
                            ),
                            SizedBox(
                              height: 112,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                ),
                                itemCount: orderAgainVendors.length,
                                separatorBuilder: (_, _) =>
                                    const SizedBox(width: 14),
                                itemBuilder: (context, i) => _OrderAgainTile(
                                  vendor: orderAgainVendors[i],
                                  onTap: () =>
                                      _openVendor(orderAgainVendors[i]),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (categories.isNotEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Row(
                          children: [
                            for (final category in categories)
                              Expanded(
                                child: CategoryChip(
                                  label: category.name,
                                  icon: category.icon,
                                  imageAsset: categoryImageAsset(category.id),
                                  selected:
                                      _selectedCategory?.id == category.id,
                                  // Tapping the already-selected category clears
                                  // the filter back to "all" — the only way to
                                  // get back there now that there's no separate
                                  // "All" chip.
                                  onTap: () => setState(() {
                                    _selectedCategory =
                                        _selectedCategory?.id == category.id
                                        ? null
                                        : category;
                                    // Switching category (or clearing it)
                                    // drops the trending-dish filter — it
                                    // only ever applied to Food.
                                    _selectedTrendingItem = null;
                                  }),
                                  translate: true,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  const SliverToBoxAdapter(child: SizedBox(height: 12)),
                  if (_isFoodCategory && trendingTerms.isNotEmpty)
                    SliverToBoxAdapter(
                      child: SizedBox(
                        height: 38,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          children: [
                            _TrendingItemChip(
                              label: context.l10n.homeAllChipLabel,
                              icon: Icons.apps_rounded,
                              selected: _selectedTrendingItem == null,
                              onTap: () =>
                                  setState(() => _selectedTrendingItem = null),
                            ),
                            for (final term in trendingTerms) ...[
                              const SizedBox(width: 8),
                              _TrendingItemChip(
                                label: term,
                                icon: Icons.trending_up_rounded,
                                selected: _selectedTrendingItem == term,
                                onTap: () => setState(
                                  () => _selectedTrendingItem =
                                      _selectedTrendingItem == term
                                      ? null
                                      : term,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  if (_isFoodCategory && trendingTerms.isNotEmpty)
                    const SliverToBoxAdapter(child: SizedBox(height: 12)),
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: 36,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        children: [
                          if (position != null) ...[
                            _QuickFilterChip(
                              label: context.l10n.homeFilterNearest,
                              icon: Icons.near_me_rounded,
                              selected: _sortNearest,
                              onTap: () =>
                                  setState(() => _sortNearest = !_sortNearest),
                            ),
                            const SizedBox(width: 8),
                          ],
                          _QuickFilterChip(
                            label: context.l10n.homeFilterOpenNow,
                            icon: Icons.storefront_rounded,
                            selected: _filterOpenNow,
                            onTap: () =>
                                setState(() => _filterOpenNow = !_filterOpenNow),
                          ),
                          const SizedBox(width: 8),
                          _QuickFilterChip(
                            label: context.l10n.homeFilterRating4,
                            icon: Icons.star_rounded,
                            selected: _filterRating4,
                            onTap: () =>
                                setState(() => _filterRating4 = !_filterRating4),
                          ),
                          const SizedBox(width: 8),
                          _QuickFilterChip(
                            label: context.l10n.homeFilterPureVeg,
                            icon: Icons.eco_rounded,
                            selected: _filterPureVeg,
                            onTap: () =>
                                setState(() => _filterPureVeg = !_filterPureVeg),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 18)),
                  if (_selectedCategory?.hasOrderingWindow ?? false)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: palette.warning.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.schedule_rounded,
                                size: 16,
                                color: palette.warning,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                context.l10n.homeOrderingWindow(
                                  _selectedCategory!.windowLabel ??
                                      context.l10n.homeCheckVendorForHours,
                                ),
                                style: TextStyle(
                                  color: palette.warning,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  vendorsAsync.when(
                    loading: () => const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 60),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    ),
                    error: (e, st) => SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 60),
                        child: Center(
                          child: Text(
                            friendlyError(
                              e,
                              action: 'Loading vendors',
                              stackTrace: st,
                            ),
                          ),
                        ),
                      ),
                    ),
                    data: (allVendors) {
                      final unfilteredVendors = allVendors
                          .where((a) => a.status == AccountStatus.active)
                          .where(
                            (a) =>
                                selectedTerritory == null ||
                                a.territory == selectedTerritory.name,
                          )
                          .toList();
                      final territoryVendors = applyQuickFilters(
                        unfilteredVendors,
                      );
                      // The quick filters (not the territory/category)
                      // emptied the list — say so, with a one-tap way out,
                      // instead of the generic "no vendors here yet".
                      if (_anyQuickFilter &&
                          territoryVendors.isEmpty &&
                          unfilteredVendors.isNotEmpty) {
                        return SliverToBoxAdapter(
                          child: SizedBox(
                            width: double.infinity,
                            child: EmptyState(
                              icon: Icons.filter_alt_off_outlined,
                              title: context.l10n.homeNoVendorsMatchFilters,
                              ctaLabel: context.l10n.homeClearFilters,
                              onCta: _clearQuickFilters,
                            ),
                          ),
                        );
                      }

                      // A vendor's `category` field is meant to hold the Category
                      // doc's `id` (see manager_vendor_create_screen.dart), but
                      // older/edited records can end up holding the category's
                      // display name instead (e.g. "Food" vs "food") if the
                      // categories collection was ever renamed/reseeded. Matching
                      // on either avoids silently dropping those vendors from
                      // every category-aware view below.
                      bool matchesCategory(Account vendor, Category category) =>
                          vendor.category == category.id ||
                          (vendor.category?.toLowerCase() ==
                              category.name.toLowerCase());
                      // Always plain (untranslated) catalogue content — every
                      // call site below renders this through `TranslatedText`,
                      // which machine-translates it itself when the User's
                      // language is Telugu. Passing an already-localized string
                      // in here (e.g. `context.l10n.homeCategoryOther`) would get
                      // run back through that English→Telugu translator a second
                      // time, garbling it.
                      String categoryLabelFor(Account vendor) =>
                          categories
                              .where((c) => matchesCategory(vendor, c))
                              .firstOrNull
                              ?.name ??
                          vendor.category ??
                          'Other';

                      final sections = <Widget>[];

                      void addHeader(String title) => sections.add(
                        Padding(
                          padding: EdgeInsets.fromLTRB(
                            20,
                            sections.isEmpty ? 0 : 26,
                            20,
                            14,
                          ),
                          child: TranslatedText(
                            title,
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                        ),
                      );

                      void addVendors(List<Account> group) {
                        for (final vendor in group) {
                          sections.add(
                            Padding(
                              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                              child: VendorAccountCard(
                                account: vendor,
                                categoryName: categoryLabelFor(vendor),
                                onTap: () => _openVendor(vendor),
                              ),
                            ),
                          );
                        }
                      }

                      Widget emptyState({String? categoryLabel}) {
                        if (selectedTerritory == null) {
                          return EmptyState(
                            icon: Icons.map_outlined,
                            title: context.l10n.homeSelectTerritory,
                            subtitle: context.l10n.homeSelectTerritorySubtitle,
                            ctaLabel: territories.isEmpty
                                ? null
                                : context.l10n.homeSelectTerritory,
                            onCta: territories.isEmpty
                                ? null
                                : () => _openTerritoryPicker(territories),
                          );
                        }
                        return EmptyState(
                          icon: Icons.storefront_outlined,
                          title: categoryLabel != null
                              ? context.l10n.homeNoVendorsForCategory(
                                  categoryLabel,
                                )
                              : context.l10n.homeNoVendorsYet,
                          subtitle: context.l10n.homeNoVendorsSubtitle(
                            selectedTerritory.name,
                          ),
                          ctaLabel: context.l10n.homeChangeTerritory,
                          onCta: () => _openTerritoryPicker(territories),
                        );
                      }

                      if (_selectedCategory != null) {
                        // A single category is selected — one section, filtered to it.
                        var filtered = territoryVendors
                            .where(
                              (a) => matchesCategory(a, _selectedCategory!),
                            )
                            .toList();
                        // Food's trending-dish chip row narrows this
                        // further, down to vendors that actually sell the
                        // picked dish (trendingVendorIds — computed once,
                        // up in build(), from allProductsProvider).
                        if (trendingVendorIds != null) {
                          filtered = filtered
                              .where((a) => trendingVendorIds.contains(a.id))
                              .toList();
                        }
                        if (filtered.isEmpty) {
                          sections.add(
                            SizedBox(
                              width: double.infinity,
                              child: emptyState(
                                // The trending item itself when that's what
                                // narrowed the list to nothing — "No
                                // vendors found for Biryani" is more useful
                                // here than just "No Food vendors yet".
                                categoryLabel:
                                    _selectedTrendingItem ??
                                    _selectedCategory!.name,
                              ),
                            ),
                          );
                        } else {
                          addHeader(
                            _selectedTrendingItem ?? _selectedCategory!.name,
                          );
                          addVendors(filtered);
                        }
                      } else {
                        // "All" — one section per category, grouped by each vendor's
                        // own category label (never dropping a vendor just because
                        // its `category` field doesn't resolve to a currently
                        // active Category doc — see `matchesCategory`/`categoryLabelFor`
                        // above), instead of one flat list mixing every category.
                        final byCategoryLabel = <String, List<Account>>{};
                        for (final vendor in territoryVendors) {
                          byCategoryLabel
                              .putIfAbsent(categoryLabelFor(vendor), () => [])
                              .add(vendor);
                        }
                        final orderedLabels = [
                          for (final category in categories)
                            if (byCategoryLabel.containsKey(category.name))
                              category.name,
                          for (final label in byCategoryLabel.keys)
                            if (!categories.any((c) => c.name == label)) label,
                        ];
                        for (final label in orderedLabels) {
                          addHeader(label);
                          addVendors(byCategoryLabel[label]!);
                        }
                        if (sections.isEmpty) {
                          sections.add(
                            SizedBox(
                              width: double.infinity,
                              child: emptyState(),
                            ),
                          );
                        }
                      }

                      return SliverToBoxAdapter(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: sections,
                        ),
                      );
                    },
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 26, 20, 0),
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: palette.promoGradient,
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(22),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    context.l10n.homeBrandBannerTitle,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 16.5,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    context.l10n.homeBrandBannerSubtitle,
                                    style: TextStyle(
                                      color: Colors.white.withValues(
                                        alpha: 0.9,
                                      ),
                                      fontSize: 12.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.16),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.storefront_rounded,
                                color: Colors.white,
                                size: 26,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Room for the floating cart bar so it never covers the
                  // last card.
                  SliverToBoxAdapter(
                    child: SizedBox(height: cart.isEmpty ? 24 : 96),
                  ),
                ],
              ),
            ),
          ),
          if (!cart.isEmpty)
            Positioned(
              left: 16,
              right: 16,
              bottom: 12,
              child: _FloatingCartBar(
                itemCount: cart.totalQuantity,
                subtotal: cart.subtotal,
                vendorName: cart.items.first.vendorName,
                onTap: () => context.go('/user/cart'),
              ),
            ),
        ],
      ),
    );
  }
}

/// Swiggy's "N items | ₹X · View Cart" strip — floats over Home whenever
/// the cart has something in it, so the User can jump back to checkout
/// without hunting for the Cart tab.
class _FloatingCartBar extends StatelessWidget {
  const _FloatingCartBar({
    required this.itemCount,
    required this.subtotal,
    required this.vendorName,
    required this.onTap,
  });

  final int itemCount;
  final double subtotal;
  final String vendorName;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    return Material(
      color: palette.primary,
      elevation: 6,
      shadowColor: Colors.black38,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${context.l10n.storefrontCartItemsBadge(itemCount)} | ${AppFormat.currency(subtotal)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      context.l10n.homeCartBarFrom(vendorName),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                context.l10n.storefrontViewCart,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right_rounded, color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }
}

/// One past vendor in Home's "Order again" row — shop photo (or a
/// storefront icon) over the vendor's name.
class _OrderAgainTile extends StatelessWidget {
  const _OrderAgainTile({required this.vendor, required this.onTap});

  final Account vendor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    final photo = vendor.coverPhotoUrl;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        width: 76,
        child: Column(
          children: [
            Opacity(
              opacity: vendor.isOpen ? 1 : 0.5,
              child: photo != null
                  ? AppNetworkImage(
                      url: photo,
                      width: 72,
                      height: 72,
                      borderRadius: BorderRadius.circular(18),
                    )
                  : Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: palette.surfaceMuted,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Icon(
                        Icons.storefront_rounded,
                        color: palette.textMuted,
                      ),
                    ),
            ),
            const SizedBox(height: 6),
            Text(
              vendor.name,
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: palette.textPrimary,
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One of Home's quick filter pills ("Nearest", "Open now", "Rated 4.0+",
/// "Pure Veg") — outlined when off, brand-tinted with a close mark when on.
class _QuickFilterChip extends StatelessWidget {
  const _QuickFilterChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: selected
              ? palette.primary.withValues(alpha: 0.12)
              : palette.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? palette.primary : palette.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 15,
              color: selected ? palette.primary : palette.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: selected ? palette.primary : palette.textPrimary,
              ),
            ),
            if (selected) ...[
              const SizedBox(width: 4),
              Icon(Icons.close_rounded, size: 14, color: palette.primary),
            ],
          ],
        ),
      ),
    );
  }
}

/// A photo-order request still in progress (`list_order_status_screen.dart`)
/// — shown above real active orders so a User who submitted photos, or who
/// just got a quote, has somewhere to come back to and pick up the flow
/// (pay, or just check status) without needing to remember the vendor.
class _ActivePhotoOrderCard extends StatelessWidget {
  const _ActivePhotoOrderCard({required this.request});
  final ListOrderRequest request;

  StatusTone get _tone => switch (request.status) {
    ListOrderStatus.pending || ListOrderStatus.quoted => StatusTone.warning,
    ListOrderStatus.paid => StatusTone.info,
    ListOrderStatus.accepted => StatusTone.success,
    ListOrderStatus.rejected || ListOrderStatus.cancelled => StatusTone.error,
  };

  String get _subtitle => switch (request.status) {
    ListOrderStatus.pending => 'Waiting for a quote',
    ListOrderStatus.quoted =>
      'Tap to pay ${AppFormat.currency(request.quotedAmount ?? 0)}',
    ListOrderStatus.paid => 'Waiting for vendor to confirm',
    _ => '',
  };

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => context.push('/user/list-order/${request.id}'),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: palette.primary, width: 1.4),
        ),
        child: Row(
          children: [
            Icon(Icons.photo_camera_rounded, color: palette.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    request.vendorName,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: palette.textPrimary,
                    ),
                  ),
                  Text(
                    _subtitle,
                    style: TextStyle(
                      color: palette.textSecondary,
                      fontSize: 12.5,
                    ),
                  ),
                ],
              ),
            ),
            StatusChip(label: request.status.label, tone: _tone),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right_rounded, color: palette.textMuted),
          ],
        ),
      ),
    );
  }
}

/// Home's live order card, Swiggy/Zomato style. Before a delivery partner
/// is on the job (placed / vendor accepted) there's nothing moving to show
/// on a map, so the card shows an animated status panel instead — what's
/// happening right now, in words, over a 4-step progress bar. Once a
/// Driver is assigned the map takes over, since there's now a moving
/// partner to follow.
class _ActiveOrderCard extends StatelessWidget {
  const _ActiveOrderCard({required this.order});
  final Order order;

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    final itemCount = order.items.fold<int>(0, (sum, i) => sum + i.quantity);
    final (:icon, :title, :subtitle) = orderStageInfo(context, order);

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.primary.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: palette.primary.withValues(alpha: 0.12),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: InkWell(
        onTap: () => context.push('/user/order/${order.id}'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status hero — brand-tinted, with the pulsing stage icon.
            Container(
              padding: const EdgeInsets.fromLTRB(16, 16, 12, 14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    palette.primary.withValues(alpha: 0.14),
                    palette.primaryLight.withValues(alpha: 0.04),
                  ],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      PulsingStatusIcon(icon: icon),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 17,
                                color: palette.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              subtitle,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: palette.textSecondary,
                                fontSize: 12.5,
                                height: 1.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: palette.textMuted,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  OrderProgressBar(status: order.status),
                ],
              ),
            ),
            if (orderShowsLiveMap(order.status))
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                child: DriverLiveMap(
                  order: order,
                  height: 150,
                  borderRadius: const BorderRadius.all(Radius.circular(12)),
                  interactive: false,
                ),
              ),
            // Order summary footer: vendor, items · total, when it moved.
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
              child: Row(
                children: [
                  Icon(
                    Icons.storefront_rounded,
                    size: 18,
                    color: palette.textMuted,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          order.vendorName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: palette.textPrimary,
                            fontSize: 13.5,
                          ),
                        ),
                        Text(
                          context.l10n.homeTrackItemsSummary(
                            itemCount,
                            AppFormat.currency(order.total),
                          ),
                          style: TextStyle(
                            color: palette.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  OrderStatusTimestamp(order.statusReachedAt(order.status)),
                ],
              ),
            ),
            if (order.status == OrderStatus.pickedUp)
              _DeliveryOtpBanner(orderId: order.id),
          ],
        ),
      ),
    );
  }
}

/// The delivery OTP, folded into the bottom of [_ActiveOrderCard] instead
/// of [DeliveryOtpCard]'s own separate full-size gradient card — same
/// brand gradient as an accent banner, just compact enough to share the
/// card with the map/status above it. No copy button — the label itself
/// ("Share this with your delivery partner") tells the User what to do
/// with the code (read it out at the door), rather than a "Delivery OTP"
/// label that names the field without saying what it's for.
class _DeliveryOtpBanner extends ConsumerWidget {
  const _DeliveryOtpBanner({required this.orderId});

  final String orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Generated by the server just after placement; dots until it lands.
    final otp = ref.watch(orderDeliveryCodeProvider(orderId)).valueOrNull ?? '····';
    final palette = context.colors;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: palette.promoGradient,
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            const Icon(Icons.password_rounded, color: Colors.white, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Share this code with your delivery partner',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.95),
                  fontWeight: FontWeight.w600,
                  fontSize: 12.5,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              otp,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 22,
                letterSpacing: 4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One chip in the Food category's trending-dish filter row — the exact
/// same icon+label pill Search's own trending row uses
/// (`_SuggestionChip`, `search_screen.dart`), just with a selected state
/// that swaps it to the filled/primary look, since tapping one filters the
/// vendor list below rather than firing off a one-shot search.
class _TrendingItemChip extends StatelessWidget {
  const _TrendingItemChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? palette.primary : palette.surfaceMuted,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 15,
              color: selected ? Colors.white : palette.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: selected ? Colors.white : palette.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A Manager-approved, paid vendor promotion — shown above the category
/// list on Home for this territory (`Promotion.status == active`). Prefers
/// the vendor's own 3:2 banner ([Promotion.promoImageUrl], uploaded on
/// `vendor_promotions_screen.dart`'s request form); falls back to their
/// storefront photo ([Promotion.vendorPhotoUrl]) when they skipped it.
class _PromotedVendorCard extends StatelessWidget {
  const _PromotedVendorCard({
    required this.promotion,
    required this.imageHeight,
    required this.onTap,
  });
  final Promotion promotion;
  final double imageHeight;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: onTap,
      child: SizedBox(
        height: imageHeight,
        child: PromotionCardVisual(
          imageUrl: promotion.promoImageUrl ?? promotion.vendorPhotoUrl,
          // Null, not promotion.vendorName, for an Admin-created "General
          // App Promotion" — it's not on behalf of any vendor, so there's
          // no real name to show (QuickyAdmin writes a "Quicky" placeholder
          // into that field so a required-looking column isn't empty in
          // its own list views, but that placeholder shouldn't leak onto
          // this card).
          vendorName: promotion.isAppPromotion ? null : promotion.vendorName,
          tagline: promotion.tagline,
          discountLabel: promotion.discountLabel,
          showOrderCta: onTap != null,
        ),
      ),
    );
  }
}

/// A live, orderable-vendor coupon — shown below the Promotions carousel
/// (`Coupon.isLiveNow`, `home_screen.dart`'s `liveCoupons`). Tapping opens
/// the coupon's vendor storefront (same route `_openVendor` uses) so the
/// User can pick items and redeem it in the cart.
class _CouponCard extends StatelessWidget {
  const _CouponCard({required this.coupon});
  final Coupon coupon;

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => context.push('/user/vendor/${coupon.vendorId}'),
      child: Container(
        width: 190,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: palette.promoGradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              coupon.discountLabel,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 15,
              ),
            ),
            Text(
              coupon.vendorName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.9),
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
              ),
            ),
            Row(
              children: [
                Icon(
                  Icons.confirmation_number_outlined,
                  size: 13,
                  color: Colors.white.withValues(alpha: 0.9),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    coupon.code,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TerritoryPickerSheet extends StatelessWidget {
  const _TerritoryPickerSheet({required this.territories});
  final List<Territory> territories;

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: palette.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              context.l10n.homeSelectTerritory,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            for (final territory in territories)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Material(
                  color: palette.surfaceMuted,
                  borderRadius: BorderRadius.circular(14),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => Navigator.pop(context, territory),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 14,
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.place_outlined, color: palette.primary),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  territory.name,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: palette.textPrimary,
                                  ),
                                ),
                                if (territory.city != null)
                                  Text(
                                    territory.city!,
                                    style: TextStyle(
                                      color: palette.textSecondary,
                                      fontSize: 12.5,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
