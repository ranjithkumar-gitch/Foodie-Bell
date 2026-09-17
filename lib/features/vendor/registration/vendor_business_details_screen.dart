import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FilteringTextInputFormatter;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/vendor.dart';
import '../../../shared/widgets/app_text_field.dart';
import 'vendor_registration_scaffold.dart';
import 'vendor_registration_state.dart';

/// Registration step 1 — Business Details (spec §5.1): shop name, category,
/// sub-category tags, owner name, and a phone number collected here purely
/// for display (the actual OTP verification happens at the very end of the
/// wizard, via the shared `/auth/phone` screen — see vendor_routes.dart).
class VendorBusinessDetailsScreen extends ConsumerStatefulWidget {
  const VendorBusinessDetailsScreen({super.key});

  @override
  ConsumerState<VendorBusinessDetailsScreen> createState() =>
      _VendorBusinessDetailsScreenState();
}

class _VendorBusinessDetailsScreenState
    extends ConsumerState<VendorBusinessDetailsScreen> {
  late final _shopNameController = TextEditingController(
    text: ref.read(vendorRegistrationProvider).shopName,
  );
  late final _ownerNameController = TextEditingController(
    text: ref.read(vendorRegistrationProvider).ownerName,
  );
  late final _phoneController = TextEditingController(
    text: ref.read(vendorRegistrationProvider).phone,
  );
  final _subCategoryController = TextEditingController();

  late VendorCategory _category = ref.read(vendorRegistrationProvider).category;
  final List<String> _subCategories = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _subCategories.addAll(ref.read(vendorRegistrationProvider).subCategories);
  }

  @override
  void dispose() {
    _shopNameController.dispose();
    _ownerNameController.dispose();
    _phoneController.dispose();
    _subCategoryController.dispose();
    super.dispose();
  }

  void _addSubCategory() {
    final tag = _subCategoryController.text.trim();
    if (tag.isEmpty || _subCategories.contains(tag)) return;
    setState(() {
      _subCategories.add(tag);
      _subCategoryController.clear();
    });
  }

  void _continue() {
    if (_shopNameController.text.trim().isEmpty ||
        _ownerNameController.text.trim().isEmpty ||
        _phoneController.text.trim().length != 10) {
      setState(
        () => _error =
            'Please fill in shop name, owner name, and a valid 10-digit phone number.',
      );
      return;
    }
    setState(() => _error = null);
    ref
        .read(vendorRegistrationProvider.notifier)
        .update(
          (d) => d.copyWith(
            shopName: _shopNameController.text.trim(),
            category: _category,
            subCategories: _subCategories,
            ownerName: _ownerNameController.text.trim(),
            phone: _phoneController.text.trim(),
          ),
        );
    context.push('/vendor/register/manager-code');
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    return VendorRegistrationScaffold(
      step: 1,
      totalSteps: 5,
      title: 'Tell us about your business',
      subtitle: 'This shows up on your storefront exactly as customers see it.',
      onContinue: _continue,
      children: [
        AppTextField(
          label: 'Shop name',
          controller: _shopNameController,
          hint: 'e.g. Bella Napoli',
        ),
        const SizedBox(height: 18),
        Text(
          'Category',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 13,
            color: palette.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final category in VendorCategory.values)
              ChoiceChip(
                label: Text(category.label),
                avatar: Icon(
                  category.icon,
                  size: 18,
                  color: _category == category
                      ? Colors.white
                      : palette.textSecondary,
                ),
                selected: _category == category,
                onSelected: (_) => setState(() => _category = category),
              ),
          ],
        ),
        const SizedBox(height: 18),
        Text(
          'Sub-categories',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 13,
            color: palette.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _subCategoryController,
                decoration: const InputDecoration(
                  hintText: 'e.g. Pizza, Desserts',
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
        if (_subCategories.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final tag in _subCategories)
                Chip(
                  label: Text(tag),
                  onDeleted: () => setState(() => _subCategories.remove(tag)),
                ),
            ],
          ),
        ],
        const SizedBox(height: 18),
        AppTextField(
          label: 'Owner name',
          controller: _ownerNameController,
          hint: 'Full name',
        ),
        const SizedBox(height: 18),
        AppTextField(
          label: 'Phone number',
          controller: _phoneController,
          hint: '10-digit mobile number',
          keyboardType: TextInputType.phone,
          maxLength: 10,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        ),
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            "We'll verify this number by OTP at the end of registration.",
            style: TextStyle(fontSize: 12, color: palette.textMuted),
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 14),
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
    );
  }
}
