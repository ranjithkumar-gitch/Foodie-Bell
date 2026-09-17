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
import '../../../data/models/territory.dart';
import '../../../data/providers/firestore_categories_provider.dart';
import '../../../data/models/promotion.dart';
import '../../../data/providers/firestore_coupons_provider.dart';
import '../../../data/providers/firestore_list_order_requests_provider.dart';
import '../../../data/providers/firestore_orders_provider.dart';
import '../../../data/providers/firestore_promotions_provider.dart';
import '../../../data/providers/firestore_territories_provider.dart';
import '../../../data/providers/firestore_vendors_provider.dart';
import '../../../shared/error_reporting.dart';
import '../../../shared/widgets/currency_text.dart';
import '../../../shared/widgets/delivery_otp_card.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/mock_map_view.dart';
import '../../../shared/widgets/notification_count_badge.dart';
import '../../../shared/widgets/order_status_timestamp.dart';
import '../../../shared/widgets/promotion_card_visual.dart';
import '../../../shared/widgets/status_chip.dart';
import '../../../l10n/app_localizations_context.dart';
import '../translation/translated_text.dart';
import '../widgets/category_chip.dart';
import '../widgets/vendor_account_card.dart';
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
  final _promoPageController = PageController();
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
      setState(() => _selectedCategory = null);
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
    final activeOrders =
        (ref.watch(firestoreOrdersProvider).valueOrNull ?? const [])
            .where((o) => o.userId == account?.id && !o.status.isTerminal)
            .toList()
          ..sort((a, b) => b.placedAt.compareTo(a.placedAt));
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
                              Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  InkWell(
                                    onTap: () =>
                                        context.push('/user/notifications'),
                                    borderRadius: BorderRadius.circular(14),
                                    child: Container(
                                      width: 44,
                                      height: 44,
                                      decoration: BoxDecoration(
                                        color: palette.primary.withValues(
                                          alpha: 0.1,
                                        ),
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      child: Icon(
                                        Icons.notifications_none_rounded,
                                        color: palette.primary,
                                      ),
                                    ),
                                  ),
                                  // User is the only role with a live
                                  // broadcast subscription, so this is the
                                  // only bell that counts Admin broadcasts
                                  // alongside personal notifications.
                                  const NotificationBellDot(
                                    includeBroadcasts: true,
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Text(
                            context.l10n.homeGreeting(firstName),
                            style: Theme.of(context).textTheme.displaySmall,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            context.l10n.homeSubtitle,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 16),
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
                  if (promotedVendors.isNotEmpty)
                    SliverToBoxAdapter(
                      child: Column(
                        children: [
                          Builder(
                            builder: (context) {
                              // True 3:2 frame sized off the card's actual on-screen
                              // width, not a guessed fixed pixel height — otherwise
                              // AppNetworkImage's BoxFit.cover would crop the image
                              // to whatever mismatched ratio the SizedBox happened
                              // to force.
                              final cardWidth =
                                  MediaQuery.sizeOf(context).width - 40;
                              final imageHeight = cardWidth * 2 / 3;
                              _promoCount = promotedVendors.length;
                              return SizedBox(
                                height: imageHeight,
                                child: PageView.builder(
                                  controller: _promoPageController,
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
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 20,
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
                                  onTap: () => setState(
                                    () => _selectedCategory =
                                        _selectedCategory?.id == category.id
                                        ? null
                                        : category,
                                  ),
                                  translate: true,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  const SliverToBoxAdapter(child: SizedBox(height: 12)),
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
                      final territoryVendors = allVendors
                          .where((a) => a.status == AccountStatus.active)
                          .where(
                            (a) =>
                                selectedTerritory == null ||
                                a.territory == selectedTerritory.name,
                          )
                          .toList();

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
                        final filtered = territoryVendors
                            .where(
                              (a) => matchesCategory(a, _selectedCategory!),
                            )
                            .toList();
                        if (filtered.isEmpty) {
                          sections.add(
                            SizedBox(
                              width: double.infinity,
                              child: emptyState(
                                categoryLabel: _selectedCategory!.name,
                              ),
                            ),
                          );
                        } else {
                          addHeader(_selectedCategory!.name);
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
                  const SliverToBoxAdapter(child: SizedBox(height: 24)),
                ],
              ),
            ),
          ),
        ],
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

class _ActiveOrderCard extends StatelessWidget {
  const _ActiveOrderCard({required this.order});
  final Order order;

  StatusTone get _tone => switch (order.status) {
    OrderStatus.placed => StatusTone.info,
    OrderStatus.vendorAccepted => StatusTone.info,
    _ => StatusTone.warning,
  };

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => context.push('/user/order/${order.id}'),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: palette.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: palette.primary, width: 1.4),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.local_shipping_rounded, color: palette.primary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            order.vendorName,
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: palette.textPrimary,
                            ),
                          ),
                          Text(
                            context.l10n.homeOrderIdLabel(order.id),
                            style: TextStyle(
                              color: palette.textSecondary,
                              fontSize: 12.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        StatusChip(label: order.status.label, tone: _tone),
                        const SizedBox(height: 3),
                        OrderStatusTimestamp(
                          order.statusReachedAt(order.status),
                        ),
                      ],
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.chevron_right_rounded, color: palette.textMuted),
                  ],
                ),
                const SizedBox(height: 12),
                const MockMapView(
                  height: 140,
                  showRoute: true,
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                ),
              ],
            ),
          ),
        ),
        if (order.status == OrderStatus.pickedUp) ...[
          const SizedBox(height: 12),
          DeliveryOtpCard(otp: order.deliveryOtp),
        ],
      ],
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
