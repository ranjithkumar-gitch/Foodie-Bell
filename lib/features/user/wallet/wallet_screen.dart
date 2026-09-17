import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations_context.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/currency_text.dart';

enum _TxnType { credit, debit }

class _WalletTxn {
  const _WalletTxn({required this.title, required this.subtitle, required this.amount, required this.type, required this.date});
  final String title;
  final String subtitle;
  final double amount;
  final _TxnType type;
  final DateTime date;
}

/// Wallet / Refunds (spec §4.17): balance card + mock transaction history
/// (credits from refunds/cashback, debits from wallet-paid orders).
class WalletScreen extends StatelessWidget {
  const WalletScreen({super.key});

  List<_WalletTxn> _transactions(AppLocalizations l10n) => [
    _WalletTxn(title: l10n.walletTxnRefund('ORD-0994'), subtitle: l10n.walletTxnOrderCancelled, amount: 245, type: _TxnType.credit, date: DateTime.now().subtract(const Duration(days: 4))),
    _WalletTxn(title: l10n.walletTxnCashback, subtitle: l10n.walletTxnWeekendPromoBonus, amount: 50, type: _TxnType.credit, date: DateTime.now().subtract(const Duration(days: 6))),
    _WalletTxn(title: l10n.walletTxnOrderPayment('ORD-0987'), subtitle: l10n.walletTxnPaidViaWallet, amount: 189, type: _TxnType.debit, date: DateTime.now().subtract(const Duration(days: 9))),
    _WalletTxn(title: l10n.walletTxnReferralBonus, subtitle: l10n.walletTxnFriendJoined, amount: 100, type: _TxnType.credit, date: DateTime.now().subtract(const Duration(days: 15))),
    _WalletTxn(title: l10n.walletTxnOrderPayment('ORD-0961'), subtitle: l10n.walletTxnPaidViaWallet, amount: 312, type: _TxnType.debit, date: DateTime.now().subtract(const Duration(days: 20))),
  ];

  double _balance(List<_WalletTxn> transactions) => transactions.fold(0, (sum, t) => sum + (t.type == _TxnType.credit ? t.amount : -t.amount));

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    final l10n = context.l10n;
    final transactions = _transactions(l10n);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.walletScreenTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(gradient: LinearGradient(colors: palette.promoGradient), borderRadius: BorderRadius.circular(20)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.account_balance_wallet_rounded, color: Colors.white, size: 22),
                    const SizedBox(width: 8),
                    Text(l10n.walletBalanceLabel, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white.withValues(alpha: 0.9))),
                  ],
                ),
                const SizedBox(height: 10),
                CurrencyText(_balance(transactions), style: Theme.of(context).textTheme.displaySmall?.copyWith(color: Colors.white)),
                const SizedBox(height: 4),
                Text(l10n.walletAutoCreditNote, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white.withValues(alpha: 0.85))),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(l10n.walletTransactionHistory, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          for (final txn in transactions) _TxnTile(txn: txn),
        ],
      ),
    );
  }
}

class _TxnTile extends StatelessWidget {
  const _TxnTile({required this.txn});
  final _WalletTxn txn;

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    final isCredit = txn.type == _TxnType.credit;
    final color = isCredit ? palette.success : palette.error;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: palette.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: palette.border)),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: color.withValues(alpha: 0.12), shape: BoxShape.circle),
              child: Icon(isCredit ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(txn.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text('${txn.subtitle} · ${DateFormat('d MMM').format(txn.date)}', style: TextStyle(color: palette.textSecondary, fontSize: 12)),
                ],
              ),
            ),
            CurrencyText(isCredit ? txn.amount : -txn.amount, style: TextStyle(fontWeight: FontWeight.w800, color: color)),
          ],
        ),
      ),
    );
  }
}
