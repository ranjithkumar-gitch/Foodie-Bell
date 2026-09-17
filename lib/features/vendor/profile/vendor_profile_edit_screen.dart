import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/session/session_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/account.dart';
import '../../../data/models/vendor_document.dart';
import '../../../data/providers/firestore_vendors_provider.dart';
import '../../../data/providers/mock_accounts_provider.dart';
import '../../../shared/error_reporting.dart';
import '../../../shared/widgets/app_network_image.dart';
import '../../../shared/widgets/app_text_field.dart';

/// Edit the signed-in Vendor's own shop name, owner name, and email —
/// reached via the pencil icon on `vendor_profile_screen.dart`'s gradient
/// card. Phone isn't editable (OTP-verified login identity, same reasoning
/// as `user_profile_edit_screen.dart`). Territory/Manager Code/category
/// aren't editable either — those are Manager-assigned at creation, not a
/// Vendor self-edit.
///
/// The "profile photo" here is the Vendor's own submitted shop-front photo
/// (`VendorDocumentType.shopFrontPhoto`) — this screen only displays it and
/// links to "My Documents" to change it, reusing the existing
/// upload/crop/replace pipeline there (`vendor_document_checklist.dart`)
/// rather than building a second one.
class VendorProfileEditScreen extends ConsumerStatefulWidget {
  const VendorProfileEditScreen({super.key});

  @override
  ConsumerState<VendorProfileEditScreen> createState() =>
      _VendorProfileEditScreenState();
}

class _VendorProfileEditScreenState
    extends ConsumerState<VendorProfileEditScreen> {
  late final _nameController = TextEditingController(
    text: _account?.name ?? '',
  );
  late final _ownerNameController = TextEditingController(
    text: _account?.ownerName ?? '',
  );
  late final _emailController = TextEditingController(
    text: _account?.email ?? '',
  );
  bool _saving = false;
  String? _error;

  Account? get _account => ref.read(sessionControllerProvider).account;

  @override
  void dispose() {
    _nameController.dispose();
    _ownerNameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final account = _account;
    if (account == null) return;
    final name = _nameController.text.trim();
    final ownerName = _ownerNameController.text.trim();
    if (name.isEmpty || ownerName.isEmpty) {
      setState(() => _error = 'Enter a shop name and owner name.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });

    final email = _emailController.text.trim();
    final isFirestoreBacked =
        ref
            .read(firestoreVendorsProvider)
            .valueOrNull
            ?.any((v) => v.id == account.id) ??
        false;

    try {
      if (isFirestoreBacked) {
        await updateVendorProfile(
          account.id,
          name: name,
          ownerName: ownerName,
          email: email.isEmpty ? null : email,
        );
      } else {
        ref
            .read(mockAccountsProvider.notifier)
            .updateProfile(
              account.id,
              name: name,
              ownerName: ownerName,
              email: email.isEmpty ? null : email,
            );
      }

      final updated = account.copyWith(
        name: name,
        ownerName: ownerName,
        email: email.isEmpty ? null : email,
      );
      ref.read(sessionControllerProvider.notifier).refreshAccount(updated);
    } catch (e, st) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = friendlyError(e, action: 'Saving profile', stackTrace: st);
      });
      return;
    }

    if (!mounted) return;
    // `/vendor/profile/edit` is a top-level route, not nested inside the
    // shell's Profile branch (see vendor_routes.dart), so context.pop() —
    // wrong tool for coming back to a shell tab regardless — is skipped
    // here in favor of going straight to the Profile page explicitly.
    context.go('/vendor/profile');
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    final account = _account;
    // The session snapshot doesn't reflect a document uploaded while still
    // `pendingReview` (see `vendor_profile_screen.dart`'s doc comment) — the
    // photo preview needs the live record, not the snapshot `_account` uses
    // for name/email/phone (those only ever change via this screen).
    final liveAccount = account == null
        ? null
        : ref.watch(liveVendorAccountProvider(account.id)) ?? account;
    final shopFrontPhotoUrl = liveAccount?.documentUrl(
      VendorDocumentType.shopFrontPhoto,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Edit Store Profile')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
        children: [
          Center(
            child: Column(
              children: [
                shopFrontPhotoUrl != null
                    ? AppNetworkImage(
                        url: shopFrontPhotoUrl,
                        width: 104,
                        height: 104,
                        borderRadius: BorderRadius.circular(24),
                      )
                    : Container(
                        width: 104,
                        height: 104,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: palette.primaryLight.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Icon(
                          Icons.storefront_rounded,
                          size: 48,
                          color: palette.primary,
                        ),
                      ),
                const SizedBox(height: 10),
                TextButton.icon(
                  onPressed: () => context.push('/vendor/profile/documents'),
                  icon: const Icon(Icons.camera_alt_outlined, size: 18),
                  label: Text(
                    shopFrontPhotoUrl != null
                        ? 'Change photo in My Documents'
                        : 'Add a shop front photo in My Documents',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          AppTextField(
            label: 'Shop/business name',
            controller: _nameController,
            hint: "e.g. Ravi's Kirana Store",
            prefixIcon: Icons.storefront_outlined,
            enabled: !_saving,
          ),
          const SizedBox(height: 16),
          AppTextField(
            label: 'Owner name',
            controller: _ownerNameController,
            hint: 'e.g. Ravi Kumar',
            prefixIcon: Icons.person_outline_rounded,
            enabled: !_saving,
          ),
          const SizedBox(height: 16),
          AppTextField(
            label: 'Email (optional)',
            controller: _emailController,
            hint: 'you@example.com',
            keyboardType: TextInputType.emailAddress,
            prefixIcon: Icons.mail_outline_rounded,
            enabled: !_saving,
          ),
          const SizedBox(height: 16),
          Text(
            'Mobile number',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13,
              color: palette.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: palette.surfaceMuted,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.call_outlined, color: palette.textMuted),
                const SizedBox(width: 12),
                Text(
                  '+91 ${account?.phone ?? ''}',
                  style: TextStyle(
                    color: palette.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
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
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
          child: ElevatedButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.4,
                    ),
                  )
                : const Text('Save changes'),
          ),
        ),
      ),
    );
  }
}
