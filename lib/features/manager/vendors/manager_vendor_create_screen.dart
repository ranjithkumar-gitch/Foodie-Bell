import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FilteringTextInputFormatter;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/session/session_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/account.dart';
import '../../../data/models/category.dart';
import '../../../data/providers/firestore_categories_provider.dart';
import '../../../data/providers/firestore_territories_provider.dart';
import '../../../data/providers/firestore_vendors_provider.dart';
import '../../../data/providers/mock_accounts_provider.dart';
import '../../../shared/error_reporting.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/empty_state.dart';

/// Manager's "Add Vendor" form — a Manager directly onboarding a Vendor
/// into their own territory. Unlike Admin's "Add Manager" screen, adding a
/// Vendor here is *not* the approval: the record is written as
/// `pendingReview`, exactly like a self-registered Vendor, since Vendor no
/// longer self-registers at all — Vendor signs in by phone/OTP through the
/// unified login screen like every other role (`auth_login_screen.dart`).
/// The Vendor can sign in immediately
/// with the phone number entered below, but sees "Account under review"
/// until they submit whatever documents Manager marks required
/// (`manager_vendor_detail_screen.dart`) and Manager approves them from
/// there — only then do they show up to Users in this territory. Territory
/// and Manager Code aren't picked — they're always the signed-in Manager's
/// own (spec's "golden rule": a Vendor belongs to exactly the territory of
/// the Manager who onboarded them), read from `sessionControllerProvider`.
/// Category comes from Admin's live, Firestore-backed list
/// (`firestore_categories_provider.dart`).
///
/// No Firebase Auth user is created here — see
/// `firestore_vendors_provider.dart`'s doc comment for why (Vendor
/// authenticates by phone+OTP, which can't be provisioned client-side the
/// way Manager's email+password can).
///
/// Subcategory options come from the selected [Category.subcategories] —
/// Admin-managed Firestore data, not a hardcoded list here, so this form
/// stays in sync with whatever Admin has configured per category.
/// Categories with an empty list simply skip the subcategory step.
class ManagerVendorCreateScreen extends ConsumerStatefulWidget {
  const ManagerVendorCreateScreen({super.key});

  @override
  ConsumerState<ManagerVendorCreateScreen> createState() =>
      _ManagerVendorCreateScreenState();
}

class _ManagerVendorCreateScreenState
    extends ConsumerState<ManagerVendorCreateScreen> {
  final _nameController = TextEditingController();
  final _ownerNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  Category? _selectedCategory;
  String? _selectedSubCategory;
  double _rebatePercent = 15;
  String? _error;
  bool _creating = false;

  @override
  void dispose() {
    _nameController.dispose();
    _ownerNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _create(Account manager) async {
    final name = _nameController.text.trim();
    final ownerName = _ownerNameController.text.trim();
    final phone = _phoneController.text.trim();
    final email = _emailController.text.trim();
    final category = _selectedCategory;
    final subcategoryOptions =
        category != null && category.subcategories.isNotEmpty
        ? category.subcategories
        : null;
    final subCategory = _selectedSubCategory;

    if (name.isEmpty ||
        ownerName.isEmpty ||
        phone.length != 10 ||
        category == null ||
        (subcategoryOptions != null && subCategory == null)) {
      setState(
        () => _error =
            'Please fill in a business name, owner name, 10-digit mobile number, and pick a category${subcategoryOptions != null ? ' and subcategory' : ''}.',
      );
      return;
    }
    setState(() {
      _error = null;
      _creating = true;
    });

    final draft = Account(
      id: '',
      role: AppRole.vendor,
      name: name,
      ownerName: ownerName,
      phone: phone,
      email: email.isEmpty ? null : email,
      managerCode: manager.managerCode,
      territory: manager.territory,
      category: category.id,
      subCategory: subCategory,
      rebatePercent: _rebatePercent,
      status: AccountStatus.pendingReview,
    );

    final String docId;
    try {
      final docRef = await vendorsCollection.add({
        ...accountToVendorDoc(draft),
        'createdAt': FieldValue.serverTimestamp(),
      });
      docId = docRef.id;
    } catch (e, st) {
      if (!mounted) return;
      setState(() {
        _creating = false;
        _error = friendlyError(e, action: 'Saving the vendor', stackTrace: st);
      });
      return;
    }

    // Mirrored for immediate same-session lookup (e.g. this Manager's own
    // Vendor Management list) — see manager_create_screen.dart for the same
    // real-Firestore/session-mirror split.
    final account = Account(
      id: docId,
      role: AppRole.vendor,
      name: name,
      ownerName: ownerName,
      phone: phone,
      email: email.isEmpty ? null : email,
      managerCode: manager.managerCode,
      territory: manager.territory,
      category: category.id,
      subCategory: subCategory,
      rebatePercent: _rebatePercent,
      status: AccountStatus.pendingReview,
    );
    ref.read(mockAccountsProvider.notifier).addAccount(account);

    if (!mounted) return;
    setState(() => _creating = false);
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Vendor added — pending review'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$name can sign in now, but stays pending in ${manager.territory ?? 'your territory'} until documents are submitted and reviewed.',
            ),
            const SizedBox(height: 12),
            Text(
              'Owner: $ownerName',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            Text(
              'Category: ${category.name}${subCategory != null ? ' · $subCategory' : ''}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            Text(
              'Manager Code: ${manager.managerCode ?? '—'}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            Text(
              'Rebate: ${_rebatePercent.toStringAsFixed(0)}% (fixed, cannot be changed later)',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            const Text(
              'They can sign in at the Vendor role selector using this mobile number via OTP. Find them under Pending once they submit documents.',
              style: TextStyle(fontSize: 12.5),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              context.pop();
            },
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    final manager = ref.watch(
      sessionControllerProvider.select((s) => s.account),
    );
    final territories = ref.watch(firestoreTerritoriesProvider).valueOrNull ?? const [];
    final managerTerritory = territories.where((t) => t.name == manager?.territory).firstOrNull;
    final categoriesAsync = ref.watch(activeCategoriesProvider).whenData(
      (categories) => categoriesForTerritory(categories, managerTerritory),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Add Vendor')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        children: [
          Icon(Icons.storefront_rounded, size: 40, color: palette.primary),
          const SizedBox(height: 14),
          Text(
            'Onboard a new vendor',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 6),
          Text(
            'They can sign in right away with this mobile number, but stay pending until they submit required documents and you approve them.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: palette.surfaceMuted,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Icon(Icons.map_rounded, color: palette.primary, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '${manager?.territory ?? 'Your territory'} · ${manager?.managerCode ?? '—'}',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: palette.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          AppTextField(
            label: 'Shop/ business Name',
            controller: _nameController,
            hint: "e.g. Ravi's Kirana Store",
            prefixIcon: Icons.storefront_outlined,
            enabled: !_creating,
          ),
          const SizedBox(height: 16),
          AppTextField(
            label: 'Owner Name',
            controller: _ownerNameController,
            hint: "e.g. Ravi Kumar",
            prefixIcon: Icons.person_outline_rounded,
            enabled: !_creating,
          ),
          const SizedBox(height: 16),
          AppTextField(
            label: 'Mobile number',
            controller: _phoneController,
            hint: '10-digit mobile number',
            keyboardType: TextInputType.phone,
            prefixIcon: Icons.call_outlined,
            enabled: !_creating,
            maxLength: 10,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          ),
          const SizedBox(height: 16),
          AppTextField(
            label: 'Email (optional)',
            controller: _emailController,
            hint: 'vendor@example.com',
            keyboardType: TextInputType.emailAddress,
            prefixIcon: Icons.mail_outline_rounded,
            enabled: !_creating,
          ),
          const SizedBox(height: 16),
          Text(
            'Category',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13,
              color: palette.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          categoriesAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: LinearProgressIndicator(),
            ),
            error: (error, st) => Text(
              friendlyError(
                error,
                action: 'Loading categories',
                stackTrace: st,
              ),
              style: TextStyle(color: palette.error, fontSize: 12.5),
            ),
            data: (categories) {
              if (categories.isEmpty) {
                return const EmptyState(
                  icon: Icons.category_outlined,
                  title: 'No active categories',
                  subtitle: "Ask Admin to add or activate a category, or check you haven't turned them all off for your territory (Profile > Territory Categories).",
                );
              }
              return DropdownButtonFormField<Category>(
                initialValue:
                    _selectedCategory != null &&
                        categories.any((c) => c.id == _selectedCategory!.id)
                    ? _selectedCategory
                    : null,
                isExpanded: true,
                items: [
                  for (final c in categories)
                    DropdownMenuItem(
                      value: c,
                      child: Text(c.name, overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: _creating
                    ? null
                    : (c) => setState(() {
                        _selectedCategory = c;
                        _selectedSubCategory = null;
                      }),
                decoration: const InputDecoration(
                  hintText: 'Select a category',
                  prefixIcon: Icon(Icons.category_outlined),
                ),
              );
            },
          ),
          if (_selectedCategory?.subcategories case final subcategoryOptions?
              when subcategoryOptions.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              'Subcategory',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: palette.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: subcategoryOptions.contains(_selectedSubCategory)
                  ? _selectedSubCategory
                  : null,
              isExpanded: true,
              items: [
                for (final s in subcategoryOptions)
                  DropdownMenuItem(value: s, child: Text(s)),
              ],
              onChanged: _creating
                  ? null
                  : (s) => setState(() => _selectedSubCategory = s),
              decoration: const InputDecoration(
                hintText: 'Select a subcategory',
                prefixIcon: Icon(Icons.restaurant_menu_outlined),
              ),
            ),
          ],
          const SizedBox(height: 20),
          Text(
            'Rebate % (10-20 band)',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13,
              color: palette.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Negotiated split routed to you as this vendor\'s onboarding Manager — fixed once the vendor is added, cannot be changed afterward.',
            style: TextStyle(color: palette.textMuted, fontSize: 12),
          ),
          Row(
            children: [
              Expanded(
                child: Slider(
                  value: _rebatePercent,
                  min: 10,
                  max: 20,
                  divisions: 10,
                  label: '${_rebatePercent.round()}%',
                  onChanged: _creating
                      ? null
                      : (v) => setState(() => _rebatePercent = v),
                ),
              ),
              SizedBox(
                width: 44,
                child: Text(
                  '${_rebatePercent.round()}%',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: palette.textPrimary,
                  ),
                ),
              ),
            ],
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
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
          child: ElevatedButton(
            onPressed: _creating || manager == null
                ? null
                : () => _create(manager),
            child: _creating
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.4,
                    ),
                  )
                : const Text('Add vendor'),
          ),
        ),
      ),
    );
  }
}
