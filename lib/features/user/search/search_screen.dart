import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/session/session_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/account.dart';
import '../../../data/providers/firestore_categories_provider.dart';
import '../../../data/providers/firestore_products_provider.dart';
import '../../../data/providers/trending_provider.dart';
import '../../../data/providers/firestore_recent_searches_provider.dart';
import '../../../data/providers/firestore_territories_provider.dart';
import '../../../data/providers/firestore_vendors_provider.dart';
import '../../../l10n/app_localizations_context.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/error_reporting.dart';
import '../translation/translated_text.dart';
import '../../../shared/widgets/app_network_image.dart';
import '../../../shared/widgets/currency_text.dart';
import '../../../shared/widgets/empty_state.dart';
import '../home/selected_territory_provider.dart';
import '../widgets/vendor_account_card.dart';

/// Search (spec §4.5): vendor search *and* product search within the
/// currently selected territory (`selectedTerritoryProvider`, shared with
/// `home_screen.dart`) — searching "idli" surfaces every vendor's idli
/// product with that vendor's name attached (the territory's product index,
/// `catalogIndexProvider` — each result loads its own image), not
/// just vendors whose own business name matches. Both run over real,
/// Manager-approved Vendor accounts (`firestoreVendorsProvider`) instead of
/// the mock `MockVendors` catalogue. Product results only include ones a
/// User could actually order right now (vendor active + open, product in
/// stock) — tapping one opens that vendor's storefront rather than adding
/// to cart inline, so the User still sees the same in-stock/open state and
/// multi-vendor-cart confirmation the storefront itself already handles.
/// "Recent searches" is real per-User data now (`firestore_recent_searches_provider.dart`,
/// same one-doc-per-user shape as the cart) — it survives logout/app
/// restart instead of resetting to a hardcoded starter list every time this
/// screen opens. "Trending" is the territory's most-ordered dishes this
/// week (`trendingDishesProvider`, computed by the server from delivered
/// orders — no customer reads anyone's orders), falling back to a small
/// static list until there are any.
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  List<String> _recent = [];

  List<String> _fallbackTrending(AppLocalizations l10n) => [
    l10n.searchFallbackBiryani,
    l10n.searchFallbackBurgers,
    l10n.searchFallbackVitaminC,
    l10n.searchFallbackFreshVegetables,
    l10n.searchFallbackMilkshake,
  ];

  List<String> _trendingTerms(List<String> dishes, AppLocalizations l10n) =>
      dishes.isEmpty ? _fallbackTrending(l10n) : dishes.take(6).toList();

  String get _query => _controller.text.trim().toLowerCase();

  String? get _userId => ref.read(sessionControllerProvider).account?.id;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadRecent());
  }

  Future<void> _loadRecent() async {
    final userId = _userId;
    if (userId == null) return;
    final terms = await loadRecentSearches(userId);
    if (!mounted) return;
    setState(() => _recent = terms);
  }

  void _runSearch(String term) {
    final trimmed = term.trim();
    setState(() {
      _controller.text = trimmed;
      _controller.selection = TextSelection.collapsed(offset: trimmed.length);
      if (trimmed.isNotEmpty && !_recent.contains(trimmed)) {
        _recent = [trimmed, ..._recent];
        if (_recent.length > 6) _recent = _recent.sublist(0, 6);
        final userId = _userId;
        if (userId != null) saveRecentSearches(userId, _recent);
      }
    });
    _focusNode.unfocus();
  }

  void _clearRecent() {
    setState(() => _recent = []);
    final userId = _userId;
    if (userId != null) clearRecentSearches(userId);
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    final hasQuery = _query.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          focusNode: _focusNode,
          autofocus: true,
          onChanged: (_) => setState(() {}),
          onSubmitted: _runSearch,
          decoration: InputDecoration(
            hintText: context.l10n.searchHint,
            prefixIcon: Icon(Icons.search_rounded, color: palette.textMuted),
            suffixIcon: hasQuery
                ? IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => setState(_controller.clear))
                : null,
          ),
        ),
      ),
      body: hasQuery ? _buildResults(context) : _buildSuggestions(context),
    );
  }

  Widget _buildSuggestions(BuildContext context) {
    final territoryId = ref.watch(browsingTerritoryIdProvider);
    final dishes = territoryId == null ? const <String>[] : ref.watch(trendingDishesProvider(territoryId)).valueOrNull ?? const <String>[];
    final trending = _trendingTerms(dishes, context.l10n);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      children: [
        if (_recent.isNotEmpty) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(context.l10n.searchRecentSearches, style: Theme.of(context).textTheme.titleMedium),
              TextButton(onPressed: _clearRecent, child: Text(context.l10n.cartClear)),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [for (final term in _recent) _SuggestionChip(label: term, icon: Icons.history_rounded, onTap: () => _runSearch(term))],
          ),
          const SizedBox(height: 24),
        ],
        Text(context.l10n.searchTrending, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [for (final term in trending) _SuggestionChip(label: term, icon: Icons.trending_up_rounded, onTap: () => _runSearch(term))],
        ),
      ],
    );
  }

  Widget _buildResults(BuildContext context) {
    final territoriesAsync = ref.watch(firestoreTerritoriesProvider);
    final territories = territoriesAsync.valueOrNull ?? const [];
    final selectedTerritory = ref.watch(selectedTerritoryProvider) ?? resolveDefaultTerritory(territories);
    final categoriesAsync = ref.watch(activeCategoriesProvider);
    final categories = categoriesAsync.valueOrNull ?? const [];
    final vendorsAsync = ref.watch(firestoreVendorsProvider);
    final productsAsync = selectedTerritory == null
        ? const AsyncValue<List<CatalogEntry>>.data([])
        : ref.watch(catalogIndexProvider(selectedTerritory.id));

    if (vendorsAsync.isLoading || productsAsync.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (vendorsAsync.hasError) {
      return Center(child: Text(friendlyError(vendorsAsync.error!, action: 'Searching vendors', stackTrace: vendorsAsync.stackTrace)));
    }
    if (productsAsync.hasError) {
      return Center(child: Text(friendlyError(productsAsync.error!, action: 'Searching products', stackTrace: productsAsync.stackTrace)));
    }

    final allVendors = vendorsAsync.value ?? const [];
    final vendorById = {for (final v in allVendors) v.id: v};

    final vendors = allVendors
        .where((a) => a.status == AccountStatus.active)
        .where((a) => selectedTerritory == null || a.territoryId == selectedTerritory.id)
        .where((a) => a.name.toLowerCase().contains(_query) || (a.ownerName?.toLowerCase().contains(_query) ?? false))
        .toList();

    // Only products a User could actually order right now — matching by
    // vendor name alone (like the search above) would surface a product
    // whose vendor is closed/inactive/outside the territory with no way to
    // act on it, and matching by product name alone would show it even
    // when the vendor themselves marked it out of stock.
    final productResults = (productsAsync.value ?? const <CatalogEntry>[])
        .where((e) => e.name.toLowerCase().contains(_query) && e.inStock)
        .map((e) => (product: e, vendor: vendorById[e.vendorId]))
        .where(
          (r) =>
              r.vendor != null &&
              r.vendor!.status == AccountStatus.active &&
              r.vendor!.isOpen &&
              (selectedTerritory == null || r.vendor!.territoryId == selectedTerritory.id),
        )
        .toList();

    if (vendors.isEmpty && productResults.isEmpty) {
      return EmptyState(icon: Icons.search_off_rounded, title: context.l10n.searchNoResultsTitle, subtitle: context.l10n.searchNoResultsSubtitle);
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      children: [
        if (productResults.isNotEmpty) ...[
          Text(context.l10n.searchProductsHeading, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          for (final result in productResults)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _ProductResultTile(
                product: result.product,
                vendorName: result.vendor!.name,
                onTap: () => context.push('/user/vendor/${result.vendor!.id}'),
              ),
            ),
          if (vendors.isNotEmpty) const SizedBox(height: 14),
        ],
        if (vendors.isNotEmpty) ...[
          Text(context.l10n.searchVendorsHeading, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          for (final vendor in vendors)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: VendorAccountCard(
                account: vendor,
                categoryName: categories
                        .where((c) => c.id == vendor.category || c.name.toLowerCase() == vendor.category?.toLowerCase())
                        .firstOrNull
                        ?.name ??
                    vendor.category,
                onTap: () => context.push('/user/vendor/${vendor.id}'),
              ),
            ),
        ],
      ],
    );
  }
}

/// One product search hit — [vendorName] makes it clear which vendor's
/// menu this came from, since a global search can turn up the same dish
/// from several vendors at once. Tapping opens that vendor's storefront
/// (rather than adding to cart inline) so the User goes through the same
/// in-stock/open state and multi-vendor-cart confirmation the storefront
/// itself already handles. The image is loaded per result, only for the
/// results actually built on screen.
class _ProductResultTile extends ConsumerWidget {
  const _ProductResultTile({required this.product, required this.vendorName, required this.onTap});
  final CatalogEntry product;
  final String vendorName;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.colors;
    final imageUrl = ref.watch(productByIdProvider(product.productId)).valueOrNull?.imageUrl ?? '';
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: palette.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: palette.border)),
        child: Row(
          children: [
            AppNetworkImage(url: imageUrl, width: 60, height: 60, borderRadius: BorderRadius.circular(12)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TranslatedText(product.name, style: Theme.of(context).textTheme.titleMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Icon(Icons.storefront_rounded, size: 12, color: palette.textMuted),
                      const SizedBox(width: 4),
                      Expanded(child: Text(vendorName, style: TextStyle(color: palette.textSecondary, fontSize: 12.5, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  CurrencyText(product.price, style: Theme.of(context).textTheme.titleMedium),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: palette.textMuted),
          ],
        ),
      ),
    );
  }
}

class _SuggestionChip extends StatelessWidget {
  const _SuggestionChip({required this.label, required this.icon, required this.onTap});
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(color: palette.surfaceMuted, borderRadius: BorderRadius.circular(20)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: palette.textSecondary),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(fontWeight: FontWeight.w600, color: palette.textPrimary, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
