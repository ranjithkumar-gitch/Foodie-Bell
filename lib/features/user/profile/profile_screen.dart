import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/session/session_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations_context.dart';
import '../../../shared/auth/logout_confirmation_sheet.dart';
import '../../../shared/widgets/app_network_image.dart';
import '../../../shared/widgets/coming_soon_sheet.dart';
import '../user_locale.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  Future<void> _showLanguagePicker(BuildContext context, WidgetRef ref) async {
    final currentCode = ref.read(userLocaleProvider).languageCode;
    final chosen = await showDialog<String>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: Text(context.l10n.profileLanguageDialogTitle),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(dialogContext, 'en'),
            child: Row(
              children: [
                const Expanded(child: Text('English')),
                if (currentCode == 'en') Icon(Icons.check_rounded, color: context.colors.primary),
              ],
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(dialogContext, 'te'),
            child: Row(
              children: [
                const Expanded(child: Text('తెలుగు')),
                if (currentCode == 'te') Icon(Icons.check_rounded, color: context.colors.primary),
              ],
            ),
          ),
        ],
      ),
    );
    if (chosen != null && chosen != currentCode) await setUserAppLanguage(ref, chosen);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.colors;
    final account = ref.watch(sessionControllerProvider.select((s) => s.account));
    final currentLanguageLabel = ref.watch(userLocaleProvider).languageCode == 'te' ? 'తెలుగు' : 'English';

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.profileTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          children: [
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(gradient: LinearGradient(colors: palette.promoGradient), borderRadius: BorderRadius.circular(20)),
              child: Stack(
                children: [
                  Row(
                    children: [
                      account?.avatarUrl != null
                          ? AppNetworkImage(url: account!.avatarUrl!, width: 60, height: 60, borderRadius: BorderRadius.circular(16))
                          : Container(
                              width: 60,
                              height: 60,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                              child: Icon(Icons.person_rounded, size: 34, color: palette.primary),
                            ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(account?.name ?? context.l10n.profileGuestFallback, style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.white)),
                            const SizedBox(height: 3),
                            Text(account?.email ?? account?.phone ?? '', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white.withValues(alpha: 0.9))),
                          ],
                        ),
                      ),
                    ],
                  ),
                  Positioned(
                    top: -2,
                    right: -2,
                    child: Material(
                      color: Colors.white.withValues(alpha: 0.25),
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: () => context.push('/user/profile/edit'),
                        child: const Padding(padding: EdgeInsets.all(8), child: Icon(Icons.edit_rounded, color: Colors.white, size: 18)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _MenuTile(icon: Icons.location_on_outlined, label: context.l10n.profileSavedAddresses, onTap: () => context.push('/user/addresses')),
            _MenuTile(
              icon: Icons.language_rounded,
              label: context.l10n.profileLanguage,
              trailingLabel: currentLanguageLabel,
              onTap: () => _showLanguagePicker(context, ref),
            ),
            _MenuTile(
              icon: Icons.account_balance_wallet_outlined,
              label: context.l10n.profileWalletRefunds,
              comingSoon: true,
              onTap: () => ComingSoonSheet.show(
                context,
                icon: Icons.account_balance_wallet_rounded,
                title: context.l10n.profileWalletRefunds,
                message: context.l10n.profileWalletComingSoonMessage,
              ),
            ),
            _MenuTile(icon: Icons.help_outline_rounded, label: context.l10n.profileHelpSupport, onTap: () => context.push('/user/help')),
            _MenuTile(
              icon: Icons.logout_rounded,
              label: context.l10n.profileLogOut,
              color: palette.error,
              onTap: () => LogoutConfirmationSheet.show(context, ref),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({required this.icon, required this.label, required this.onTap, this.color, this.comingSoon = false, this.trailingLabel});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;
  final bool comingSoon;
  final String? trailingLabel;

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: palette.surface,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: palette.border)),
            child: Row(
              children: [
                Icon(icon, color: color ?? palette.textSecondary, size: 22),
                const SizedBox(width: 14),
                Expanded(child: Text(label, style: TextStyle(fontWeight: FontWeight.w700, color: color ?? palette.textPrimary))),
                if (trailingLabel != null) ...[
                  Text(trailingLabel!, style: TextStyle(color: palette.textSecondary, fontSize: 12.5, fontWeight: FontWeight.w600)),
                  const SizedBox(width: 8),
                ],
                if (comingSoon) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: palette.warning.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
                    child: Text(context.l10n.profileComingSoonBadge, style: TextStyle(color: palette.warning, fontSize: 9.5, fontWeight: FontWeight.w800, letterSpacing: 0.3)),
                  ),
                  const SizedBox(width: 8),
                ],
                Icon(Icons.chevron_right_rounded, color: palette.textMuted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
