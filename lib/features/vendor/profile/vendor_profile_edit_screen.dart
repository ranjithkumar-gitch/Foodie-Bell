import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';

import '../../../core/session/session_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/account.dart';
import '../../../data/providers/firestore_vendors_provider.dart';
import '../../../data/providers/mock_accounts_provider.dart';
import '../../../shared/error_reporting.dart';
import '../../../shared/widgets/app_network_image.dart';
import '../../../shared/widgets/app_text_field.dart';

/// Edit the signed-in Vendor's own shop name, owner name, email, and shop
/// address/map location — reached via the pencil icon on
/// `vendor_profile_screen.dart`'s gradient card. Phone isn't editable (OTP-verified login identity, same reasoning
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
  late final _addressController = TextEditingController(
    text: _account?.address ?? '',
  );
  late double? _latitude = _account?.latitude;
  late double? _longitude = _account?.longitude;
  bool _saving = false;
  bool _locating = false;
  String? _error;

  Account? get _account => ref.read(sessionControllerProvider).account;

  @override
  void dispose() {
    _nameController.dispose();
    _ownerNameController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  /// Pins the shop to wherever the Vendor's phone is right now — meant to
  /// be tapped while standing at the shop. Only staged here; it's written
  /// along with the rest of the form on "Save changes".
  Future<void> _useCurrentLocation() async {
    setState(() {
      _locating = true;
      _error = null;
    });
    String? problem;
    Position? position;
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        problem = 'Turn on location (GPS) on your phone and try again.';
      } else {
        var permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }
        if (permission == LocationPermission.denied ||
            permission == LocationPermission.deniedForever) {
          problem =
              'Location permission is needed to set your shop location. Allow it in your phone settings.';
        } else {
          position = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
              timeLimit: Duration(seconds: 20),
            ),
          );
        }
      }
    } catch (e, st) {
      problem = friendlyError(e, action: 'Getting your location', stackTrace: st);
    }
    if (!mounted) return;
    setState(() {
      _locating = false;
      _error = problem;
      if (position != null) {
        _latitude = position.latitude;
        _longitude = position.longitude;
      }
    });
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
    final address = _addressController.text.trim();
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
          address: address.isEmpty ? null : address,
          latitude: _latitude,
          longitude: _longitude,
        );
      } else {
        ref
            .read(mockAccountsProvider.notifier)
            .updateProfile(
              account.id,
              name: name,
              ownerName: ownerName,
              email: email.isEmpty ? null : email,
              address: address.isEmpty ? null : address,
              latitude: _latitude,
              longitude: _longitude,
            );
      }

      final updated = account.copyWith(
        name: name,
        ownerName: ownerName,
        email: email.isEmpty ? null : email,
        address: address.isEmpty ? null : address,
        latitude: _latitude,
        longitude: _longitude,
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
    final shopFrontPhotoUrl = liveAccount?.coverPhotoUrl;

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
          const SizedBox(height: 16),
          AppTextField(
            label: 'Shop address',
            controller: _addressController,
            hint: 'Door no., street, area, city, pincode',
            keyboardType: TextInputType.streetAddress,
            maxLines: 3,
            enabled: !_saving,
          ),
          const SizedBox(height: 16),
          Text(
            'Shop location',
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
                Icon(Icons.location_on_outlined, color: palette.textMuted),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _latitude != null && _longitude != null
                        ? 'Lat ${_latitude!.toStringAsFixed(6)}, Long ${_longitude!.toStringAsFixed(6)}'
                        : 'Not set yet',
                    style: TextStyle(
                      color: palette.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _saving || _locating ? null : _useCurrentLocation,
              icon: _locating
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.my_location_rounded, size: 18),
              label: Text(
                _locating
                    ? 'Getting your location…'
                    : _latitude != null
                    ? 'Update to my current location'
                    : 'Use my current location',
              ),
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
