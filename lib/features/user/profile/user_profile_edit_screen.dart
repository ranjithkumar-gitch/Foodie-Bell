import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/session/session_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/account.dart';
import '../../../data/providers/firestore_users_provider.dart';
import '../../../data/providers/user_avatar_storage_provider.dart';
import '../../../l10n/app_localizations_context.dart';
import '../../../shared/error_reporting.dart';
import '../../../shared/widgets/app_network_image.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/document_source_sheet.dart';

/// Edit/add the signed-in User's own name, email, and avatar — reached via
/// the pencil icon on `profile_screen.dart`. Phone isn't editable here: it's
/// the OTP-verified login identity, changing it is a re-verification flow,
/// not a profile edit.
///
/// A signed-in User's account always lives in the real `users` Firestore
/// collection (`auth_terms_screen.dart`) — login only ever resolves a real,
/// Firestore-backed account (`auth_navigation.dart`'s
/// `resolveAccountAcrossRoles`) — so updates always go there
/// (`updateUserProfile`).
class UserProfileEditScreen extends ConsumerStatefulWidget {
  const UserProfileEditScreen({super.key});

  @override
  ConsumerState<UserProfileEditScreen> createState() =>
      _UserProfileEditScreenState();
}

class _UserProfileEditScreenState extends ConsumerState<UserProfileEditScreen> {
  late final _nameController = TextEditingController(
    text: _account?.name ?? '',
  );
  late final _emailController = TextEditingController(
    text: _account?.email ?? '',
  );
  File? _pickedAvatar;
  bool _saving = false;
  String? _error;

  Account? get _account => ref.read(sessionControllerProvider).account;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    final source = await DocumentSourceSheet.show(
      context,
      title: context.l10n.editProfilePhotoTitle,
    );
    if (source == null || !mounted) return;

    XFile? picked;
    try {
      picked = await ImagePicker().pickImage(source: source, imageQuality: 90);
    } catch (_) {
      // No camera/gallery available in this environment — fall through.
    }
    if (picked == null || !mounted) return;

    final cropped = await ImageCropper().cropImage(
      sourcePath: picked.path,
      compressQuality: 80,
      aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: context.l10n.editProfileCropPhotoTitle,
          lockAspectRatio: true,
        ),
        IOSUiSettings(
          title: context.l10n.editProfileCropPhotoTitle,
          aspectRatioLockEnabled: true,
        ),
      ],
    );
    if (cropped == null || !mounted) return;

    setState(() => _pickedAvatar = File(cropped.path));
  }

  Future<void> _save() async {
    final account = _account;
    if (account == null) return;
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _error = context.l10n.editProfileNameRequired);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });

    final email = _emailController.text.trim();

    try {
      String? avatarUrl;
      if (_pickedAvatar != null) {
        avatarUrl = await uploadUserAvatar(account.id, _pickedAvatar!);
      }

      await updateUserProfile(
        account.id,
        name: name,
        email: email.isEmpty ? null : email,
        avatarUrl: avatarUrl,
      );

      final updated = account.copyWith(
        name: name,
        email: email.isEmpty ? null : email,
        avatarUrl: avatarUrl ?? account.avatarUrl,
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
    // `/user/profile/edit` is a top-level route, not nested inside the
    // shell's Profile branch (see user_routes.dart), so context.pop() —
    // wrong tool for coming back to a shell tab regardless — is skipped
    // here in favor of going straight to the Profile page explicitly.
    context.go('/user/profile');
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    final account = _account;

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.editProfileTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
        children: [
          Center(
            child: Stack(
              children: [
                _AvatarPreview(
                  pickedFile: _pickedAvatar,
                  avatarUrl: account?.avatarUrl,
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Material(
                    color: palette.primary,
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: _saving ? null : _pickAvatar,
                      child: const Padding(
                        padding: EdgeInsets.all(8),
                        child: Icon(
                          Icons.edit_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          AppTextField(
            label: context.l10n.editProfileFullName,
            controller: _nameController,
            hint: context.l10n.editProfileYourNameHint,
            prefixIcon: Icons.person_outline_rounded,
            enabled: !_saving,
          ),
          const SizedBox(height: 16),
          AppTextField(
            label: context.l10n.editProfileEmailOptional,
            controller: _emailController,
            hint: 'you@example.com',
            keyboardType: TextInputType.emailAddress,
            prefixIcon: Icons.mail_outline_rounded,
            enabled: !_saving,
          ),
          const SizedBox(height: 16),
          Text(
            context.l10n.editProfileMobileNumber,
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
                : Text(context.l10n.editProfileSaveChanges),
          ),
        ),
      ),
    );
  }
}

class _AvatarPreview extends StatelessWidget {
  const _AvatarPreview({required this.pickedFile, required this.avatarUrl});
  final File? pickedFile;
  final String? avatarUrl;

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    if (pickedFile != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Image.file(
          pickedFile!,
          width: 104,
          height: 104,
          fit: BoxFit.cover,
        ),
      );
    }
    if (avatarUrl != null) {
      return AppNetworkImage(
        url: avatarUrl!,
        width: 104,
        height: 104,
        borderRadius: BorderRadius.circular(24),
      );
    }
    return Container(
      width: 104,
      height: 104,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: palette.primaryLight.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Icon(Icons.person_rounded, size: 48, color: palette.primary),
    );
  }
}
