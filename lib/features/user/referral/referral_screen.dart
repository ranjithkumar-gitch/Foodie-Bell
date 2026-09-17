import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/session/session_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations_context.dart';
import '../../../shared/widgets/currency_text.dart';

/// Referral / Invite Friends (spec §4.19): a mock referral code derived
/// from the signed-in user's name, a "copy code" action (no real share
/// sheet needed), and mock "friends invited" stats.
class ReferralScreen extends ConsumerWidget {
  const ReferralScreen({super.key});

  String _codeFor(String? name) {
    final base = (name ?? 'QUICKY').toUpperCase().replaceAll(RegExp(r'[^A-Z]'), '');
    final prefix = base.isEmpty ? 'QM' : base.substring(0, base.length.clamp(0, 4));
    return '$prefix${100 + prefix.length * 37 % 900}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.colors;
    final account = ref.watch(sessionControllerProvider.select((s) => s.account));
    final code = _codeFor(account?.name);

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.referralScreenTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(gradient: LinearGradient(colors: palette.promoGradient), borderRadius: BorderRadius.circular(20)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.card_giftcard_rounded, color: Colors.white, size: 30),
                const SizedBox(height: 12),
                Text(context.l10n.referralGiveGetTitle, style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.white)),
                const SizedBox(height: 6),
                Text(
                  context.l10n.referralGiveGetSubtitle,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white.withValues(alpha: 0.9)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(color: palette.surface, borderRadius: BorderRadius.circular(18), border: Border.all(color: palette.border)),
            child: Column(
              children: [
                Text(context.l10n.referralYourCodeLabel, style: TextStyle(color: palette.textSecondary, fontSize: 12.5, fontWeight: FontWeight.w600)),
                const SizedBox(height: 10),
                _CodeBox(code: code),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: code));
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.l10n.referralCodeCopiedSnack)));
                    },
                    icon: const Icon(Icons.copy_rounded, size: 18),
                    label: Text(context.l10n.referralCopyCodeButton),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.l10n.referralSharedDemoSnack)));
                    },
                    icon: const Icon(Icons.ios_share_rounded, size: 18),
                    label: Text(context.l10n.referralInviteFriendsButton),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(child: _StatCard(icon: Icons.group_rounded, label: context.l10n.referralFriendsInvitedLabel, value: '6')),
              const SizedBox(width: 12),
              Expanded(child: _StatCard(icon: Icons.savings_rounded, label: context.l10n.referralTotalEarnedLabel, value: null, amount: 300)),
            ],
          ),
        ],
      ),
    );
  }
}

class _CodeBox extends StatelessWidget {
  const _CodeBox({required this.code});
  final String code;

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: palette.surfaceMuted,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: palette.primary.withValues(alpha: 0.4), style: BorderStyle.solid),
      ),
      alignment: Alignment.center,
      child: Text(code, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: 4, color: palette.primary)),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.icon, required this.label, this.value, this.amount});
  final IconData icon;
  final String label;
  final String? value;
  final double? amount;

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: palette.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: palette.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: palette.primary, size: 22),
          const SizedBox(height: 10),
          if (amount != null)
            CurrencyText(amount!, style: Theme.of(context).textTheme.titleLarge)
          else
            Text(value!, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(color: palette.textSecondary, fontSize: 12)),
        ],
      ),
    );
  }
}
