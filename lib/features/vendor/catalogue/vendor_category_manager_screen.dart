import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/vendor.dart';
import '../../../data/providers/firestore_categories_provider.dart';
import '../../../data/providers/firestore_products_provider.dart';
import '../vendor_session.dart';

/// Category & Sub-category Manager (spec §5.13) — a vendor-scoped read of
/// Admin's platform-wide dynamic category list (Firestore's `categories`
/// collection, `firestore_categories_provider.dart`), plus the
/// sub-categories this vendor's own products are actually grouped under.
/// Adding a sub-category here only affects this vendor's local grouping
/// (there's no vendor-scoped sub-category provider to persist to).
class VendorCategoryManagerScreen extends ConsumerStatefulWidget {
  const VendorCategoryManagerScreen({super.key});

  @override
  ConsumerState<VendorCategoryManagerScreen> createState() =>
      _VendorCategoryManagerScreenState();
}

class _VendorCategoryManagerScreenState
    extends ConsumerState<VendorCategoryManagerScreen> {
  final _newSubCategoryController = TextEditingController();
  final List<String> _localExtraSubCategories = [];

  @override
  void dispose() {
    _newSubCategoryController.dispose();
    super.dispose();
  }

  void _addSubCategory() {
    final tag = _newSubCategoryController.text.trim();
    if (tag.isEmpty || _localExtraSubCategories.contains(tag)) return;
    setState(() {
      _localExtraSubCategories.add(tag);
      _newSubCategoryController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    final vendorId = ref.watch(currentVendorIdProvider);
    final category = ref.watch(currentVendorCategoryProvider);
    final categories =
        ref.watch(firestoreCategoriesProvider).valueOrNull ?? const [];
    final myCategory = categories
        .where((c) => c.id == category.name)
        .firstOrNull;
    final products =
        ref.watch(vendorProductsProvider(vendorId)).valueOrNull ?? const [];
    final productSubCategories = products.map((p) => p.subCategory).toSet();
    final subCategories = [
      ...productSubCategories,
      ..._localExtraSubCategories,
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Categories')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Your storefront category',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: palette.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: palette.primary, width: 1.4),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: palette.primaryLight.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(category.icon, color: palette.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        category.label,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: palette.textPrimary,
                        ),
                      ),
                      if (myCategory != null && !myCategory.isActive)
                        Text(
                          'Currently inactive platform-wide',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: palette.error,
                            fontWeight: FontWeight.w600,
                          ),
                        )
                      else
                        Text(
                          'Active on the platform',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: palette.success,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Your sub-categories',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(
            'Derived from the products in your catalogue.',
            style: TextStyle(fontSize: 12.5, color: palette.textSecondary),
          ),
          const SizedBox(height: 12),
          if (subCategories.isEmpty)
            Text(
              'No sub-categories yet — add a product to your catalogue.',
              style: TextStyle(color: palette.textMuted),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final sub in subCategories)
                  Chip(
                    label: Text(sub),
                    backgroundColor: palette.surfaceMuted,
                    avatar: Icon(
                      Icons.local_offer_outlined,
                      size: 16,
                      color: palette.textSecondary,
                    ),
                  ),
              ],
            ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _newSubCategoryController,
                  decoration: const InputDecoration(
                    hintText: 'Add a new sub-category',
                  ),
                  onSubmitted: (_) => _addSubCategory(),
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton(
                onPressed: _addSubCategory,
                child: const Text('Add'),
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
