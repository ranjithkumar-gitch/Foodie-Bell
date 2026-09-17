import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/product.dart';
import '../../../data/models/tax_category.dart';
import '../../../data/models/vendor.dart';
import '../../../data/providers/firestore_categories_provider.dart';
import '../../../data/providers/firestore_products_provider.dart';
import '../../../data/providers/vendor_product_storage_provider.dart';
import '../../../shared/widgets/app_network_image.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/document_source_sheet.dart';
import '../../../shared/widgets/tax_category_field.dart';
import '../vendor_session.dart';

/// Add/Edit Product (spec §5.11): name, photo, price, unit, veg/non-veg,
/// in-stock toggle. `productId == null` means "add". Reads/writes this
/// vendor's real Firestore catalogue (`firestore_products_provider.dart`) —
/// nothing here is in-memory mock state, so a saved product is still there
/// next launch.
///
/// The photo picker uploads for real to Firebase Storage
/// (`vendor_product_storage_provider.dart`, same pick → crop → upload
/// pattern as `vendor_document_checklist.dart`) as soon as one is picked —
/// not deferred to Save — so the preview shown here is always the actual
/// image the product will render with, with Change/Remove affordances once
/// one is set.
///
/// The sub-category suggestions, the unit hint, and whether veg/non-veg is
/// even asked all key off the signed-in vendor's own [VendorCategory] —
/// Admin's dynamic per-category sub-category list
/// (`firestore_categories_provider.dart`) plus whatever sub-categories this
/// vendor already uses, so a Pharmacy vendor never sees "Pizza" and a
/// Vegetables vendor is never asked veg/non-veg.
String _unitHint(VendorCategory category) => switch (category) {
  VendorCategory.food => 'e.g. 1 pc, 1 plate',
  VendorCategory.pharmacy => 'e.g. 1 strip, 1 bottle',
  VendorCategory.kirana => 'e.g. 1 kg, 500 g, 1 pack',
  VendorCategory.vegetables => 'e.g. 1 kg, 500 g, 1 bunch',
};

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

class VendorAddEditProductScreen extends ConsumerStatefulWidget {
  const VendorAddEditProductScreen({super.key, this.productId});

  final String? productId;

  @override
  ConsumerState<VendorAddEditProductScreen> createState() =>
      _VendorAddEditProductScreenState();
}

class _VendorAddEditProductScreenState
    extends ConsumerState<VendorAddEditProductScreen> {
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _unitController = TextEditingController(text: '1 pc');
  final _subCategoryController = TextEditingController();

  /// Fixed for this screen's lifetime (rather than generated fresh at Save)
  /// so a photo can be uploaded to its final Storage path — `product_images/
  /// {vendorId}/{productId}.jpg` — the moment it's picked, before the product
  /// doc itself even exists yet in "Add" mode.
  late final String _productId =
      widget.productId ?? 'p_${DateTime.now().millisecondsSinceEpoch}';

  bool? _isVeg = true;
  bool _inStock = true;
  String? _imageUrl;
  bool _uploadingPhoto = false;
  String? _error;
  bool _initialized = false;
  bool _saving = false;
  String? _taxCategoryId;
  GstOverride? _gstOverride;

  bool get _isEditing => widget.productId != null;

  @override
  void initState() {
    super.initState();
    // A live suggestion needs to react as the sub-category text changes,
    // not just when a ChoiceChip tap already triggers a rebuild.
    _subCategoryController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _unitController.dispose();
    _subCategoryController.dispose();
    super.dispose();
  }

  void _initFromExisting(Product product) {
    if (_initialized) return;
    _initialized = true;
    _nameController.text = product.name;
    _descriptionController.text = product.description;
    _priceController.text = product.price.toStringAsFixed(0);
    _unitController.text = product.unit;
    _subCategoryController.text = product.subCategory;
    _isVeg = product.isVeg;
    _inStock = product.inStock;
    _imageUrl = product.imageUrl;
    _taxCategoryId = product.taxCategoryId;
    _gstOverride = product.gstOverride;
  }

  Future<void> _pickPhoto() async {
    final source = await DocumentSourceSheet.show(
      context,
      title: 'Add product photo',
      subtitle: 'Take a new photo or choose one from your gallery.',
    );
    if (source == null || !mounted) return;

    XFile? picked;
    try {
      picked = await ImagePicker().pickImage(source: source, imageQuality: 85);
    } catch (_) {
      // No camera/gallery available in this environment (e.g. simulator
      // without photos) — fall through, nothing picked.
    }
    if (picked == null || !mounted) return;

    final cropped = await ImageCropper().cropImage(
      sourcePath: picked.path,
      compressQuality: 85,
      uiSettings: [
        AndroidUiSettings(toolbarTitle: 'Crop photo', lockAspectRatio: false),
        IOSUiSettings(title: 'Crop photo'),
      ],
    );
    if (cropped == null || !mounted) return;

    setState(() => _uploadingPhoto = true);
    try {
      final vendorId = ref.read(currentVendorIdProvider);
      final url = await uploadProductImage(
        vendorId,
        _productId,
        File(cropped.path),
      );
      if (mounted) {
        setState(() {
          _imageUrl = url;
          _uploadingPhoto = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _uploadingPhoto = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Photo upload failed. Please try again.'),
          ),
        );
      }
    }
  }

  Future<void> _removePhoto() async {
    setState(() => _uploadingPhoto = true);
    try {
      final vendorId = ref.read(currentVendorIdProvider);
      await deleteProductImage(vendorId, _productId);
    } catch (_) {
      // Best-effort — still clear the preview even if the Storage delete failed.
    }
    if (mounted) {
      setState(() {
        _imageUrl = null;
        _uploadingPhoto = false;
      });
    }
  }

  Future<void> _save(String vendorId, VendorCategory category) async {
    final name = _nameController.text.trim();
    final price = double.tryParse(_priceController.text.trim());
    final subCategory = _subCategoryController.text.trim();
    if (name.isEmpty || price == null || price <= 0 || subCategory.isEmpty) {
      setState(
        () => _error = 'Please fill in a valid name, price, and sub-category.',
      );
      return;
    }
    setState(() {
      _error = null;
      _saving = true;
    });

    final product = Product(
      id: _productId,
      name: name,
      description: _descriptionController.text.trim(),
      price: price,
      imageUrl:
          _imageUrl ??
          'https://images.unsplash.com/photo-1546069901-ba9599a7e63c?w=800&q=80',
      subCategory: subCategory,
      unit: _unitController.text.trim().isEmpty
          ? '1 pc'
          : _unitController.text.trim(),
      // Veg/non-veg only applies to the Food category (spec §5.11) — every
      // other category's products carry no veg/non-veg distinction.
      isVeg: category == VendorCategory.food ? _isVeg : null,
      inStock: _inStock,
      taxCategoryId: _taxCategoryId,
      gstOverride: _gstOverride,
    );

    try {
      if (_isEditing) {
        await updateProduct(vendorId, product);
      } else {
        await addProduct(vendorId, product);
      }
      if (mounted) context.pop();
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error =
              'Could not save this product — check your connection and try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;

    final vendorId = ref.watch(currentVendorIdProvider);
    final category = ref.watch(currentVendorCategoryProvider);
    final isFood = category == VendorCategory.food;
    final productsAsync = ref.watch(vendorProductsProvider(vendorId));
    final products = productsAsync.valueOrNull ?? const <Product>[];

    if (_isEditing) {
      final match = products.where((p) => p.id == widget.productId).firstOrNull;
      if (match != null) _initFromExisting(match);
    }
    if (!isFood) _isVeg = null;

    if (_isEditing && !_initialized && productsAsync.isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Edit Product')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final adminSubCategories =
        ref
            .watch(firestoreCategoriesProvider)
            .valueOrNull
            ?.where((c) => c.id == category.name)
            .firstOrNull
            ?.subcategories ??
        const [];
    final vendorSubCategories = products.map((p) => p.subCategory).toSet();
    final subCategorySuggestions = <String>{
      ...adminSubCategories,
      ...vendorSubCategories,
    }.toList()..sort();

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Product' : 'Add Product'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(category.icon, size: 16, color: palette.textMuted),
                  const SizedBox(width: 4),
                  Text(
                    category.label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: palette.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            height: 160,
            width: double.infinity,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: palette.surfaceMuted,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: palette.border),
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (_imageUrl != null)
                  AppNetworkImage(url: _imageUrl!, fit: BoxFit.cover)
                else
                  InkWell(
                    onTap: _uploadingPhoto ? null : _pickPhoto,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.add_a_photo_outlined,
                          color: palette.textMuted,
                          size: 28,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Add product photo',
                          style: TextStyle(
                            color: palette.textMuted,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                if (_uploadingPhoto)
                  Container(
                    color: Colors.black.withValues(alpha: 0.4),
                    alignment: Alignment.center,
                    child: const CircularProgressIndicator(color: Colors.white),
                  ),
                if (_imageUrl != null && !_uploadingPhoto)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Row(
                      children: [
                        _PhotoIconButton(
                          icon: Icons.edit_rounded,
                          tooltip: 'Change photo',
                          onTap: _pickPhoto,
                        ),
                        const SizedBox(width: 8),
                        _PhotoIconButton(
                          icon: Icons.delete_outline_rounded,
                          tooltip: 'Remove photo',
                          onTap: _removePhoto,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          AppTextField(
            label: 'Product name',
            controller: _nameController,
            hint: 'e.g. Margherita Pizza',
          ),
          const SizedBox(height: 16),
          AppTextField(
            label: 'Description',
            controller: _descriptionController,
            hint: 'Short description',
            maxLines: 2,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: AppTextField(
                  label: 'Price (₹)',
                  controller: _priceController,
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AppTextField(
                  label: 'Unit',
                  controller: _unitController,
                  hint: _unitHint(category),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          AppTextField(
            label: 'Sub-category',
            controller: _subCategoryController,
            hint: category == VendorCategory.food
                ? 'e.g. Pizza, Desserts'
                : 'Type a sub-category',
          ),
          if (subCategorySuggestions.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final sub in subCategorySuggestions)
                  ChoiceChip(
                    label: Text(sub),
                    selected: _subCategoryController.text.trim() == sub,
                    onSelected: (_) =>
                        setState(() => _subCategoryController.text = sub),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          TaxCategoryField(
            category: category,
            productSubCategory: _subCategoryController.text,
            taxCategoryId: _taxCategoryId,
            onTaxCategoryIdChanged: (id) => setState(() => _taxCategoryId = id),
            gstOverride: _gstOverride,
            onGstOverrideChanged: (override) => _gstOverride = override,
          ),
          const SizedBox(height: 16),
          if (isFood) ...[
            Text(
              'Veg / Non-veg',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: palette.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              children: [
                ChoiceChip(
                  label: const Text('Veg'),
                  selected: _isVeg == true,
                  onSelected: (_) => setState(() => _isVeg = true),
                ),
                ChoiceChip(
                  label: const Text('Non-veg'),
                  selected: _isVeg == false,
                  onSelected: (_) => setState(() => _isVeg = false),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('In stock'),
            value: _inStock,
            onChanged: (v) => setState(() => _inStock = v),
          ),
          if (_error != null) ...[
            const SizedBox(height: 6),
            Text(
              _error!,
              style: TextStyle(
                color: palette.error,
                fontWeight: FontWeight.w600,
                fontSize: 12.5,
              ),
            ),
          ],
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: ElevatedButton(
            onPressed: _saving ? null : () => _save(vendorId, category),
            child: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(_isEditing ? 'Save changes' : 'Add product'),
          ),
        ),
      ),
    );
  }
}

class _PhotoIconButton extends StatelessWidget {
  const _PhotoIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.55),
      shape: const CircleBorder(),
      child: IconButton(
        tooltip: tooltip,
        visualDensity: VisualDensity.compact,
        icon: Icon(icon, size: 18, color: Colors.white),
        onPressed: onTap,
      ),
    );
  }
}
