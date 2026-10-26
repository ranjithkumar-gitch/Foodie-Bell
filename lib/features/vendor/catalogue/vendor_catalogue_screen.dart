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
///
/// Kept deliberately plain for small-town shop owners: a search box, then
/// one simple row per product with its in-stock switch.
class VendorCatalogueScreen extends ConsumerStatefulWidget {
  const VendorCatalogueScreen({super.key});

  @override
  ConsumerState<VendorCatalogueScreen> createState() =>
      _VendorCatalogueScreenState();
}

enum _Tool { global, categories, bulkUpload }

class _VendorCatalogueScreenState extends ConsumerState<VendorCatalogueScreen> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    final vendorId = ref.watch(currentVendorIdProvider);
    final category = ref.watch(currentVendorCategoryProvider);
    final productsAsync = ref.watch(vendorProductsProvider(vendorId));

    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        title: const Text('Products'),
        actions: [
          PopupMenuButton<_Tool>(
            tooltip: 'More options',
            icon: const Icon(Icons.more_vert_rounded),
            onSelected: (tool) => context.push(switch (tool) {
              _Tool.global => '/vendor/catalogue/global',
              _Tool.categories => '/vendor/catalogue/categories',
              _Tool.bulkUpload => '/vendor/catalogue/bulk-upload',
            }),
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: _Tool.global,
                child: _MenuText(
                  icon: Icons.library_add_outlined,
                  text: 'Add from ready list',
                ),
              ),
              PopupMenuItem(
                value: _Tool.categories,
                child: _MenuText(
                  icon: Icons.category_outlined,
                  text: 'Manage categories',
                ),
              ),
              PopupMenuItem(
                value: _Tool.bulkUpload,
                child: _MenuText(
                  icon: Icons.upload_file_outlined,
                  text: 'Upload many products',
                ),
              ),
            ],
          ),
        ],
      ),
      body: productsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(
          child: Text(
            'Couldn\'t load your products.',
            style: TextStyle(color: palette.error, fontSize: 15),
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
                    label: const Text('Add from ready list'),
                  ),
                ),
              ],
            );
          }

          final q = _query.trim().toLowerCase();
          final shown = q.isEmpty
              ? products
              : products.where((p) => p.name.toLowerCase().contains(q));
          final grouped = <String, List<Product>>{};
          for (final p in shown) {
            grouped.putIfAbsent(p.subCategory, () => []).add(p);
          }
          final outOfStock = products.where((p) => !p.inStock).length;

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
            children: [
              TextField(
                controller: _searchController,
                onChanged: (v) => setState(() => _query = v),
                textInputAction: TextInputAction.search,
                style: const TextStyle(fontSize: 16),
                decoration: InputDecoration(
                  hintText: 'Search products',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Clear',
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _query = '');
                          },
                        ),
                ),
              ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  outOfStock == 0
                      ? '${products.length} products · all in stock'
                      : '${products.length} products · $outOfStock out of stock',
                  style: TextStyle(fontSize: 14, color: palette.textSecondary),
                ),
              ),
              if (grouped.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 48),
                  child: Center(
                    child: Text(
                      'No products match "${_query.trim()}"',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15,
                        color: palette.textSecondary,
                      ),
                    ),
                  ),
                ),
              for (final entry in grouped.entries) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
                  child: Text(
                    entry.key,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: palette.textPrimary,
                    ),
                  ),
                ),
                Container(
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: palette.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: palette.border),
                  ),
                  child: Column(
                    children: [
                      for (var i = 0; i < entry.value.length; i++) ...[
                        if (i > 0)
                          Divider(
                            height: 1,
                            indent: 84,
                            color: palette.divider,
                          ),
                        _ProductRow(
                          product: entry.value[i],
                          vendorId: vendorId,
                        ),
                      ],
                    ],
                  ),
                ),
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

class _MenuText extends StatelessWidget {
  const _MenuText({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 22),
        const SizedBox(width: 12),
        Text(text, style: const TextStyle(fontSize: 15.5)),
      ],
    );
  }
}

enum _ProductAction { edit, delete }

/// Photo · name and price · in-stock switch · edit/delete menu. Tapping the
/// row opens the edit screen.
class _ProductRow extends ConsumerWidget {
  const _ProductRow({required this.product, required this.vendorId});

  final Product product;
  final String vendorId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.colors;
    final inStock = product.inStock;
    return InkWell(
      onTap: () => context.push('/vendor/catalogue/product/${product.id}/edit'),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 0, 12),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Opacity(
                opacity: inStock ? 1 : 0.4,
                child: CachedNetworkImage(
                  imageUrl: product.imageUrl,
                  width: 60,
                  height: 60,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    width: 60,
                    height: 60,
                    color: palette.surfaceMuted,
                  ),
                  errorWidget: (context, url, error) => Container(
                    width: 60,
                    height: 60,
                    color: palette.surfaceMuted,
                    child: Icon(
                      Icons.image_not_supported_outlined,
                      color: palette.textMuted,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: palette.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${AppFormat.currency(product.price)} / ${product.unit}',
                    style: TextStyle(
                      fontSize: 15,
                      color: palette.textSecondary,
                    ),
                  ),
                  if (!inStock) ...[
                    const SizedBox(height: 3),
                    Text(
                      'Out of stock',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: palette.error,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Switch(
              value: inStock,
              onChanged: (v) => setProductStock(product.id, v),
            ),
            PopupMenuButton<_ProductAction>(
              tooltip: 'Edit or delete',
              icon: Icon(Icons.more_vert_rounded, color: palette.textMuted),
              onSelected: (action) => switch (action) {
                _ProductAction.edit => context.push(
                  '/vendor/catalogue/product/${product.id}/edit',
                ),
                _ProductAction.delete => _confirmDelete(context, ref),
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: _ProductAction.edit,
                  child: _MenuText(icon: Icons.edit_outlined, text: 'Edit'),
                ),
                PopupMenuItem(
                  value: _ProductAction.delete,
                  child: Row(
                    children: [
                      Icon(
                        Icons.delete_outline_rounded,
                        size: 22,
                        color: palette.error,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Delete',
                        style: TextStyle(fontSize: 15.5, color: palette.error),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete product?'),
        content: Text('Remove "${product.name}" from your products?'),
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
