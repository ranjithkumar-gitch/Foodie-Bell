import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/global_product.dart';
import '../../../data/models/product.dart';
import '../../../data/models/vendor.dart';
import '../../../data/providers/firestore_global_products_provider.dart';
import '../../../data/providers/firestore_products_provider.dart';
import '../../../shared/widgets/app_network_image.dart';
import '../../../shared/widgets/currency_text.dart';
import '../../../shared/widgets/empty_state.dart';
import '../vendor_session.dart';

/// "Copy from Global Catalogue" — the common products Admin has set up for
/// this vendor's own [VendorCategory] (`firestore_global_products_provider.dart`),
/// so a vendor can bulk-add the regular stuff instead of typing every one
/// in through Add Product. A template already in this vendor's catalogue
/// (tracked via [Product.globalProductId]) shows "Added" instead of a
/// checkbox — copying is a one-time seed, not a live sync, so editing price/
/// details afterward (from the normal Catalogue screen) never touches the
/// template and re-copying isn't offered once one's already there.
class VendorGlobalCatalogueScreen extends ConsumerStatefulWidget {
  const VendorGlobalCatalogueScreen({super.key});

  @override
  ConsumerState<VendorGlobalCatalogueScreen> createState() =>
      _VendorGlobalCatalogueScreenState();
}

class _VendorGlobalCatalogueScreenState
    extends ConsumerState<VendorGlobalCatalogueScreen> {
  final _selected = <String>{};
  bool _copying = false;

  Future<void> _copySelected(
    String vendorId,
    List<GlobalProduct> available,
  ) async {
    final toCopy = available.where((p) => _selected.contains(p.id)).toList();
    if (toCopy.isEmpty) return;
    setState(() => _copying = true);
    try {
      await copyGlobalProducts(vendorId, toCopy);
      if (mounted) {
        setState(() {
          _selected.clear();
          _copying = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${toCopy.length} product${toCopy.length == 1 ? '' : 's'} added to your catalogue.',
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => _copying = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not copy products. Please try again.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    final vendorId = ref.watch(currentVendorIdProvider);
    final category = ref.watch(currentVendorCategoryProvider);
    final globalAsync = ref.watch(globalProductsProvider);
    final myProductsAsync = ref.watch(vendorProductsProvider(vendorId));
    final alreadyAdded = (myProductsAsync.valueOrNull ?? const <Product>[])
        .map((p) => p.globalProductId)
        .whereType<String>()
        .toSet();

    return Scaffold(
      appBar: AppBar(title: const Text('Copy from Global Catalogue')),
      body: globalAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) {
          debugPrint('Global catalogue load failed: $error\n$stackTrace');
          return Center(
            child: Text(
              "Couldn't load the global catalogue.",
              style: TextStyle(color: palette.error),
            ),
          );
        },
        data: (all) {
          final products = all.where((p) => p.category == category).toList();
          final available = products
              .where((p) => !alreadyAdded.contains(p.id))
              .toList();

          if (products.isEmpty) {
            return EmptyState(
              icon: category.icon,
              title: 'Nothing here yet',
              subtitle:
                  'Admin hasn\'t added any ${category.label} template products to the Global Catalogue yet.',
            );
          }

          final grouped = <String, List<GlobalProduct>>{};
          for (final p in products) {
            grouped.putIfAbsent(p.subCategory, () => []).add(p);
          }

          return Column(
            children: [
              if (available.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${_selected.length} of ${available.length} selected',
                          style: TextStyle(
                            color: palette.textSecondary,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () => setState(() {
                          if (_selected.length == available.length) {
                            _selected.clear();
                          } else {
                            _selected
                              ..clear()
                              ..addAll(available.map((p) => p.id));
                          }
                        }),
                        child: Text(
                          _selected.length == available.length
                              ? 'Deselect all'
                              : 'Select all',
                        ),
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
                  children: [
                    for (final entry in grouped.entries) ...[
                      Text(
                        entry.key,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 10),
                      for (final product in entry.value)
                        _GlobalProductRow(
                          product: product,
                          added: alreadyAdded.contains(product.id),
                          selected: _selected.contains(product.id),
                          onToggle: () => setState(() {
                            if (_selected.contains(product.id)) {
                              _selected.remove(product.id);
                            } else {
                              _selected.add(product.id);
                            }
                          }),
                        ),
                      const SizedBox(height: 12),
                    ],
                  ],
                ),
              ),
            ],
          );
        },
      ),
      bottomNavigationBar: _selected.isEmpty
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: ElevatedButton(
                  onPressed: _copying
                      ? null
                      : () => _copySelected(
                          vendorId,
                          globalAsync.valueOrNull ?? const [],
                        ),
                  child: _copying
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text('Copy ${_selected.length} to my catalogue'),
                ),
              ),
            ),
    );
  }
}

class _GlobalProductRow extends StatelessWidget {
  const _GlobalProductRow({
    required this.product,
    required this.added,
    required this.selected,
    required this.onToggle,
  });

  final GlobalProduct product;
  final bool added;
  final bool selected;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: added ? null : onToggle,
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: added ? palette.surfaceMuted : palette.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? palette.primary : palette.border,
              width: selected ? 1.4 : 1,
            ),
          ),
          child: Row(
            children: [
              if (!added)
                Checkbox(value: selected, onChanged: (_) => onToggle())
              else
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Icon(
                    Icons.check_circle_rounded,
                    color: palette.success,
                    size: 22,
                  ),
                ),
              AppNetworkImage(
                url: product.imageUrl,
                width: 50,
                height: 50,
                borderRadius: BorderRadius.circular(10),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (product.isVeg != null)
                          Icon(
                            Icons.circle,
                            size: 10,
                            color: product.isVeg!
                                ? palette.success
                                : palette.error,
                          ),
                        if (product.isVeg != null) const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            product.name,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: palette.textPrimary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        CurrencyText(
                          product.price,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: palette.primary,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '· ${product.unit}',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: palette.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (added)
                Text(
                  'Added',
                  style: TextStyle(
                    color: palette.success,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
