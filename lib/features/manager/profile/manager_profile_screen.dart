import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/session/session_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/account.dart';
import '../../../data/providers/firestore_managers_provider.dart';
import '../../../data/providers/manager_avatar_storage_provider.dart';
import '../../../shared/auth/logout_confirmation_sheet.dart';
import '../../../shared/error_reporting.dart';
import '../../../shared/widgets/app_network_image.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/document_source_sheet.dart';
import '../../../shared/widgets/menu_tile.dart';
import '../../../shared/widgets/notification_count_badge.dart';

/// Profile & Bank/Payout Details (spec §7.17) + a menu into every other
/// non-tab Manager screen (Code Management, Settlement History, Territory
/// Earnings, Marketing Tracker, Promotion Approvals, Order Oversight,
/// Notifications, Help & Support) — mirrors user/profile_screen.dart's
/// pattern of a hero card + menu tiles + logout.
class ManagerProfileScreen extends ConsumerStatefulWidget {
  const ManagerProfileScreen({super.key});

  @override
  ConsumerState<ManagerProfileScreen> createState() =>
      _ManagerProfileScreenState();
}

class _ManagerProfileScreenState extends ConsumerState<ManagerProfileScreen> {
  late final _accountHolderController = TextEditingController(
    text: _account?.bankAccountHolder ?? '',
  );
  late final _accountNumberController = TextEditingController(
    text: _account?.bankAccountNumber ?? '',
  );
  late final _ifscController = TextEditingController(
    text: _account?.bankIfsc ?? '',
  );
  bool _uploadingAvatar = false;
  bool _savingBankDetails = false;

  Account? get _account => ref.read(sessionControllerProvider).account;

  @override
  void dispose() {
    _accountHolderController.dispose();
    _accountNumberController.dispose();
    _ifscController.dispose();
    super.dispose();
  }

  Future<void> _savePayoutDetails() async {
    final account = _account;
    if (account == null) return;
    final holder = _accountHolderController.text.trim();
    final number = _accountNumberController.text.trim();
    final ifsc = _ifscController.text.trim();
    if (holder.isEmpty || number.isEmpty || ifsc.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Fill in all bank details before saving.'),
        ),
      );
      return;
    }
    setState(() => _savingBankDetails = true);
    try {
      await updateManagerBankDetails(
        account.id,
        accountHolder: holder,
        accountNumber: number,
        ifsc: ifsc,
      );
      ref
          .read(sessionControllerProvider.notifier)
          .refreshAccount(
            account.copyWith(
              bankAccountHolder: holder,
              bankAccountNumber: number,
              bankIfsc: ifsc,
            ),
          );
    } catch (e, st) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            friendlyError(e, action: 'Saving bank details', stackTrace: st),
          ),
        ),
      );
      return;
    } finally {
      if (mounted) setState(() => _savingBankDetails = false);
    }
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Bank/payout details saved.')));
  }

  Future<void> _pickAvatar() async {
    final account = ref.read(sessionControllerProvider).account;
    if (account == null) return;

    final source = await DocumentSourceSheet.show(
      context,
      title: 'Update profile photo',
      subtitle: 'Take a new photo or choose one from your gallery.',
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
        AndroidUiSettings(toolbarTitle: 'Crop photo', lockAspectRatio: true),
        IOSUiSettings(title: 'Crop photo', aspectRatioLockEnabled: true),
      ],
    );
    if (cropped == null || !mounted) return;

    setState(() => _uploadingAvatar = true);
    try {
      final avatarUrl = await uploadManagerAvatar(
        account.id,
        File(cropped.path),
      );
      await updateManagerAvatar(account.id, avatarUrl);
      ref
          .read(sessionControllerProvider.notifier)
          .refreshAccount(account.copyWith(avatarUrl: avatarUrl));
    } catch (e, st) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            friendlyError(e, action: 'Uploading photo', stackTrace: st),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _uploadingAvatar = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    final account = ref.watch(
      sessionControllerProvider.select((s) => s.account),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        children: [
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: palette.promoGradient),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    if (_uploadingAvatar)
                      const SizedBox(
                        width: 60,
                        height: 60,
                        child: Center(
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.4,
                          ),
                        ),
                      )
                    else if (account?.avatarUrl != null)
                      AppNetworkImage(
                        url: account!.avatarUrl!,
                        width: 60,
                        height: 60,
                        borderRadius: BorderRadius.circular(16),
                      )
                    else
                      Container(
                        width: 60,
                        height: 60,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(
                          Icons.map_rounded,
                          size: 30,
                          color: palette.primary,
                        ),
                      ),
                    Positioned(
                      right: -4,
                      bottom: -4,
                      child: Material(
                        color: palette.primary,
                        shape: const CircleBorder(),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: _uploadingAvatar ? null : _pickAvatar,
                          child: const Padding(
                            padding: EdgeInsets.all(6),
                            child: Icon(
                              Icons.edit_rounded,
                              color: Colors.white,
                              size: 14,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        account?.name ?? 'Guest',
                        style: Theme.of(
                          context,
                        ).textTheme.titleLarge?.copyWith(color: Colors.white),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        account?.email ?? account?.phone ?? '',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Manager code: ${account?.managerCode ?? '—'}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Bank & payout details',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          AppTextField(
            label: 'Account holder name',
            controller: _accountHolderController,
            prefixIcon: Icons.person_outline_rounded,
            enabled: !_savingBankDetails,
          ),
          const SizedBox(height: 14),
          AppTextField(
            label: 'Account number',
            controller: _accountNumberController,
            prefixIcon: Icons.account_balance_outlined,
            enabled: !_savingBankDetails,
          ),
          const SizedBox(height: 14),
          AppTextField(
            label: 'IFSC code',
            controller: _ifscController,
            prefixIcon: Icons.numbers_rounded,
            enabled: !_savingBankDetails,
          ),
          const SizedBox(height: 14),
          OutlinedButton(
            onPressed: _savingBankDetails ? null : _savePayoutDetails,
            child: _savingBankDetails
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2.4),
                  )
                : const Text('Save payout details'),
          ),
          const SizedBox(height: 24),
          // Settlement History, Territory Earnings Report, Vendor Promotion
          // Approvals, Territory Categories, and Order Oversight moved to
          // the Drawer's quick-links section (`rail_drawer_shell.dart`) —
          // reachable from every screen's menu icon, not just Profile.
          MenuTile(
            icon: Icons.campaign_outlined,
            label: 'Local Marketing Tracker',
            onTap: () => context.push('/manager/marketing'),
          ),
          // Was missing entirely despite the route/screen existing — this
          // doc comment already claimed it was here (see above); the wall
          // was unreachable for Manager until this tile existed.
          MenuTile(
            icon: Icons.notifications_none_rounded,
            label: 'Notifications',
            trailing: const NotificationCountPill(),
            onTap: () => context.push('/manager/notifications'),
          ),
          MenuTile(
            icon: Icons.help_outline_rounded,
            label: 'Help & Support',
            onTap: () => context.push('/manager/support'),
          ),
          MenuTile(
            icon: Icons.logout_rounded,
            label: 'Log Out',
            color: palette.error,
            onTap: () => LogoutConfirmationSheet.show(context, ref),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
