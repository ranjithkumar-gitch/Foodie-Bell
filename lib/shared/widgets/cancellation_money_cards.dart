import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../data/providers/earnings_provider.dart';
import '../../l10n/app_localizations_context.dart';
import '../error_reporting.dart';
import 'currency_text.dart';

/// Vendor: cancellation charges, shown apart from earnings (Phase I.4).
/// Every figure is the server's (`earnings_totals/{vendor}`): charged when
/// the shop cancelled an accepted order, paid once the collector confirmed a
/// purpose-tagged payment, still owed, and reversed by the Super Admin.
class VendorCancellationChargesCard extends StatelessWidget {
  const VendorCancellationChargesCard({super.key, required this.totals});
  final AsyncValue<EarningsFigures> totals;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return _MoneyCard(
      title: l10n.vendorCancellationCharges,
      note: l10n.cancelChargesNote,
      totals: totals,
      isEmpty: (t) => t.cancellationCharges == 0 && t.cancellationChargesAssessed == 0,
      emptyText: l10n.cancelChargesNone,
      rows: (t) => [
        // Every figure is the server's sum over the shop's collectors
        // (Phase I.4.2): assessed, paid, waived, still owed, refund owed and
        // refunded — an unconfirmed refund is shown apart, never as refunded.
        (l10n.cancelChargesCharged, t.cancellationChargesAssessed, false),
        (l10n.cancelChargesPaid, t.cancellationChargesCollected, false),
        if (t.cancellationChargesReversed > 0) (l10n.cancelChargesReversed, t.cancellationChargesReversed, false),
        (l10n.cancelChargesWaived, t.cancellationChargesWaived, false),
        (l10n.cancelChargesOwed, t.cancellationChargesOutstanding, true),
        (l10n.cancelRefundDue, t.cancellationRefundDue, true),
        if (t.cancellationRefundPending > 0) (l10n.cancelRefundPending, t.cancellationRefundPending, false),
        (l10n.cancelRefunded, t.cancellationRefunded, false),
      ],
    );
  }
}

/// Driver: cancellation compensation, shown apart from delivery fees
/// (Phase I.4). Server figures (`earnings_totals/{driver}`): earned when a
/// shop cancelled an order assigned to them, paid once they confirmed the
/// payment, and still pending.
class DriverCancellationCompCard extends StatelessWidget {
  const DriverCancellationCompCard({super.key, required this.totals});
  final AsyncValue<EarningsFigures> totals;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return _MoneyCard(
      title: l10n.driverCancellationComp,
      note: l10n.driverCompNote,
      totals: totals,
      isEmpty: (t) => t.cancellationCompensations == 0 && t.cancellationCompEarned == 0,
      emptyText: l10n.driverCompNone,
      rows: (t) => [
        (l10n.driverCompEarned, t.cancellationCompEarned, false),
        (l10n.driverCompPaid, t.cancellationCompPaid, false),
        (l10n.driverCompPending, t.cancellationCompPending, true),
      ],
    );
  }
}

class _MoneyCard extends StatelessWidget {
  const _MoneyCard({required this.title, required this.note, required this.totals, required this.isEmpty, required this.emptyText, required this.rows});

  final String title;
  final String note;
  final AsyncValue<EarningsFigures> totals;
  final bool Function(EarningsFigures) isEmpty;
  final String emptyText;
  final List<(String, double, bool)> Function(EarningsFigures) rows;

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: palette.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: palette.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(note, style: TextStyle(color: palette.textSecondary, fontSize: 12.5)),
          const SizedBox(height: 10),
          totals.when(
            loading: () => const Padding(padding: EdgeInsets.all(8), child: Center(child: CircularProgressIndicator())),
            error: (e, st) => Text(friendlyError(e, action: 'Loading cancellation figures', stackTrace: st), style: TextStyle(color: palette.error)),
            data: (t) => isEmpty(t)
                ? Text(emptyText, style: TextStyle(color: palette.textMuted))
                : Column(
                    children: [
                      for (final (label, value, strong) in rows(t))
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(label, style: TextStyle(color: strong ? palette.textPrimary : palette.textSecondary, fontWeight: strong ? FontWeight.w700 : FontWeight.w500)),
                              CurrencyText(value, style: TextStyle(fontWeight: strong ? FontWeight.w800 : FontWeight.w600)),
                            ],
                          ),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
