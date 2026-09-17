import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/product.dart';
import '../../../data/models/vendor.dart';
import '../../../data/providers/firestore_products_provider.dart';
import '../../../shared/widgets/currency_text.dart';
import '../../../shared/widgets/empty_state.dart';
import '../vendor_session.dart';

/// Catalogue Management (spec §5.11): product list grouped by sub-category,
/// with a stock toggle, edit/delete, and entry points to Bulk Upload
/// (§5.12) and the Category & Sub-category Manager (§5.13). Reads live from
/// this vendor's own Firestore catalogue (`vendorProductsProvider` —
/// `firestore_products_provider.dart`), scoped to the signed-in vendor's id
/// and [VendorCategory] (`vendor_session.dart`), so a Pharmacy vendor's
/// catalogue looks and behaves differently from a Food vendor's, and two
/// different vendors logged in on two devices never see each other's data.
class VendorCatalogueScreen extends ConsumerWidget {
  const VendorCatalogueScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.colors;
    final vendorId = ref.watch(currentVendorIdProvider);
    final category = ref.watch(currentVendorCategoryProvider);
    final productsAsync = ref.watch(vendorProductsProvider(vendorId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Catalogue'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(28),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(category.icon, size: 15, color: palette.textMuted),
                const SizedBox(width: 5),
                Text(
                  category.label,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: palette.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Copy from Global Catalogue',
            icon: const Icon(Icons.library_add_outlined),
            onPressed: () => context.push('/vendor/catalogue/global'),
          ),
          IconButton(
            tooltip: 'Category Manager',
            icon: const Icon(Icons.category_outlined),
            onPressed: () => context.push('/vendor/catalogue/categories'),
          ),
          IconButton(
            tooltip: 'Bulk Upload',
            icon: const Icon(Icons.upload_file_rounded),
            onPressed: () => context.push('/vendor/catalogue/bulk-upload'),
          ),
        ],
      ),
      body: productsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(
          child: Text(
            'Couldn\'t load your catalogue.',
            style: TextStyle(color: palette.error),
          ),
        ),
        data: (products) {
          if (products.isEmpty) {
            return Column(
              children: [
                Expanded(
                  child: EmptyState(
                    icon: category.icon,
                    title: 'No products yet',
                    subtitle:
                        'Add your first ${category.label} product to start selling.',
                    ctaLabel: 'Add Product',
                    onCta: () => context.push('/vendor/catalogue/product/add'),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: TextButton.icon(
                    onPressed: () => context.push('/vendor/catalogue/global'),
                    icon: const Icon(Icons.library_add_outlined),
                    label: const Text('Copy from Global Catalogue'),
                  ),
                ),
              ],
            );
          }

          final grouped = <String, List<Product>>{};
          for (final p in products) {
            grouped.putIfAbsent(p.subCategory, () => []).add(p);
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 90),
            children: [
              for (final entry in grouped.entries) ...[
                Text(entry.key, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 10),
                for (final product in entry.value)
                  _ProductTile(product: product, vendorId: vendorId),
                const SizedBox(height: 12),
              ],
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/vendor/catalogue/product/add'),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Product'),
      ),
    );
  }
}

class _ProductTile extends ConsumerWidget {
  const _ProductTile({required this.product, required this.vendorId});

  final Product product;
  final String vendorId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () =>
            context.push('/vendor/catalogue/product/${product.id}/edit'),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: palette.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: palette.border),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: CachedNetworkImage(
                  imageUrl: product.imageUrl,
                  width: 54,
                  height: 54,
                  fit: BoxFit.cover,
                  errorWidget: (context, url, error) => Container(
                    width: 54,
                    height: 54,
                    color: palette.surfaceMuted,
                    child: Icon(
                      Icons.image_not_supported_outlined,
                      color: palette.textMuted,
                    ),
                  ),
                ),
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
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Switch(
                    value: product.inStock,
                    onChanged: (v) => setProductStock(product.id, v),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.edit_outlined, size: 19),
                        onPressed: () => context.push(
                          '/vendor/catalogue/product/${product.id}/edit',
                        ),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        icon: Icon(
                          Icons.delete_outline_rounded,
                          size: 19,
                          color: palette.error,
                        ),
                        onPressed: () => _confirmDelete(context, ref),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete product?'),
        content: Text('Remove "${product.name}" from your catalogue?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await removeProduct(vendorId, product.id);
    }
  }
}
