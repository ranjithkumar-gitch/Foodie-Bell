import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/session/access_scope.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/account.dart';
import '../../data/providers/earnings_provider.dart';
import '../../data/providers/firestore_orders_provider.dart';
import '../../data/providers/order_actions.dart';
import '../../data/providers/settlement_provider.dart';
import '../widgets/busy_overlay.dart';
import '../widgets/currency_text.dart';
import 'daily_money.dart';

/// Settlements, simplified (2026-11-20): a Manager (or, for money with
/// QuickMandi, the Super Admin) marks a payment settled and it counts at
/// once. The other side has 24 hours to report a problem; the Super Admin
/// checks it and either keeps it or undoes it. After 24 hours it is final.

String _rupees(int paise) => AppFormat.currency(paise / 100);

/// "until 6:30 PM today" / "until 6:30 PM, 21 Nov".
String reportDeadlineText(DateTime until, {DateTime? now}) {
  final n = now ?? DateTime.now();
  final local = until.toLocal();
  final time = DateFormat('h:mm a').format(local);
  final sameDay = local.year == n.year && local.month == n.month && local.day == n.day;
  return sameDay ? 'until $time today' : 'until $time, ${DateFormat('dd/MM/yyyy').format(local)}';
}

/// Where a settled payment stands, in words; null when there is nothing to
/// add (a payment from before 2026-11-20 still waiting or disputed).
String? settledStatusText(SettlementTransfer t, PartyKey me, {DateTime? now}) {
  if (t.status == 'voided') return 'Undone by QuickMandi — the amount is owed again.';
  if (t.status != 'confirmed') return null;
  if (t.isReportOpen) return 'Problem reported — QuickMandi is checking it.';
  if (t.reportDecision == 'keep') return 'Checked by QuickMandi — stays settled.';
  if (t.canReport(me, now: now)) return 'Settled. Wrong? Report it ${reportDeadlineText(t.reportUntil!, now: now)}.';
  if (t.reportUntil != null && t.recordedBy == me && (now ?? DateTime.now()).isBefore(t.reportUntil!)) {
    return 'Settled. The other side can report a problem ${reportDeadlineText(t.reportUntil!, now: now)}.';
  }
  return 'Settled ✓';
}

/// Asks what is wrong and reports [t]. Returns true when reported.
Future<bool> reportSettlement(BuildContext context, SettlementTransfer t) async {
  final controller = TextEditingController();
  final note = await showDialog<String>(
    context: context,
    builder: (d) => AlertDialog(
      title: const Text('Report a problem'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${_rupees(t.amountPaise)} was marked settled. Tell QuickMandi what is wrong. It stays settled while they check it.'),
          const SizedBox(height: 12),
          TextField(
            controller: controller,
            autofocus: true,
            maxLength: 300,
            decoration: const InputDecoration(hintText: 'e.g. I did not get this money'),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(d), child: const Text('Back')),
        ElevatedButton(
          onPressed: () {
            final text = controller.text.trim();
            if (text.isNotEmpty) Navigator.pop(d, text);
          },
          child: const Text('Report'),
        ),
      ],
    ),
  );
  if (note == null) return false;
  try {
    await runBusy(() => reportSettlementTransfer(t.id, note: note));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Reported. QuickMandi will check it and let you know.')));
    }
    return true;
  } on OrderActionException catch (e) {
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    return false;
  }
}

/// One settled payment: amount, who paid whom, its status and — while the
/// 24 hours last — a "Report a problem" button for the side that didn't
/// mark it.
class SettledPaymentNote extends StatelessWidget {
  const SettledPaymentNote({super.key, required this.transfer, required this.me, required this.text});

  final SettlementTransfer transfer;
  final PartyKey me;

  /// "Your Manager marked ₹500 settled (cash)".
  final String text;

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    final t = transfer;
    final status = settledStatusText(t, me);
    final color = switch (t) {
      _ when t.status == 'voided' => palette.error,
      _ when t.isReportOpen => palette.warning,
      _ => palette.success,
    };
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (text.isNotEmpty) Text(text, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
          if (status != null)
            Text(
              status,
              style: TextStyle(color: color, fontSize: 12.5, fontWeight: FontWeight.w600),
            ),
          if (t.canReport(me))
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                key: ValueKey('report:${t.id}'),
                style: TextButton.styleFrom(foregroundColor: palette.error, padding: EdgeInsets.zero, visualDensity: VisualDensity.compact),
                onPressed: () => reportSettlement(context, t),
                icon: const Icon(Icons.flag_outlined, size: 18),
                label: const Text('Report a problem'),
              ),
            ),
        ],
      ),
    );
  }
}

/// The signed-in Driver's or Vendor's "who owes whom" lines with their
/// Manager — the same figures as their Earnings card (`daily_money.dart`).
final myPartyMoneyLinesProvider = Provider.autoDispose<List<PartyMoneyLine>>((ref) {
  final scope = ref.watch(accessScopeProvider);
  if (scope == null) return const [];
  final me = partyKeyFor(scope.role, scope.accountId);
  final cutoff = ref.watch(settlementCutoffProvider).valueOrNull ?? 22 * 60;
  final today = currentSettlementDay(cutoffMinutes: cutoff);
  final transfers = ref.watch(myTransfersProvider).valueOrNull ?? const <SettlementTransfer>[];
  final days = ref.watch(myEarningsDaysProvider(14)).valueOrNull ?? const <EarningsDay>[];
  return switch (scope.role) {
    AppRole.driver => driverMoneyLines(days, today, me, transfers),
    AppRole.vendor => vendorMoneyLines(
      days,
      today,
      me,
      transfers,
      deliveredOrders: [
        for (final o in ref.watch(orderHistoryProvider(OrderHistoryFilter.delivered)).orders)
          if (o.vendorId == scope.accountId) o,
      ],
      cutoffMinutes: cutoff,
    ),
    _ => const [],
  };
});
