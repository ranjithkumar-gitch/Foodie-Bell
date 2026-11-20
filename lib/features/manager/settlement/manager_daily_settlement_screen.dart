import 'dart:math';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/session/access_scope.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/account.dart';
import '../../../data/models/order.dart';
import '../../../data/providers/firestore_drivers_provider.dart';
import '../../../data/providers/firestore_orders_provider.dart';
import '../../../data/providers/firestore_vendors_provider.dart';
import '../../../data/providers/order_actions.dart';
import '../../../data/providers/settlement_provider.dart';
import '../../../shared/settlement/daily_money.dart';
import 'cancellation_settlement_section.dart';
import 'manager_today_money_card.dart';
import 'propose_adjustment_sheet.dart';
import 'settlement_payment_sheet.dart';
import '../../../shared/widgets/currency_text.dart';
import '../../../shared/widgets/busy_overlay.dart';
import '../../../shared/utils/date_text.dart';

String _rupees(int paise) => AppFormat.currency(paise / 100);

/// A statement discrepancy, in words. The types are the server's
/// (`functions/lib/statement.js`): a disputed payment says what it was for.
String settlementDiscrepancyText(Map<String, dynamic> d, String Function(PartyKey) partyName) {
  final amount = _rupees((d['amountPaise'] as num?)?.toInt() ?? 0);
  return switch (d['type']) {
    'codShortfall' => 'Driver collected $amount less cash (order ${d['orderId']})',
    'disputedPayment' => '${settlementPurposeLabel(d['purpose'] as String? ?? 'general')} payment of $amount was disputed (${partyName(d['from'] as String)} → ${partyName(d['to'] as String)})',
    'noManager' => 'This territory had no active manager on this day',
    _ => '${d['type']}',
  };
}

/// Daily settlement for the Manager's territory (Phase 2). Everything on
/// this screen comes from the server's statement (`generateDailySettlement`,
/// computed from the ledger): who collected what, who owes whom, which
/// payments have been made and acknowledged, and what's still open. A day
/// is "Completed" only when every balance is zero through acknowledged
/// payments — never just because the day is over.
///
/// The Manager is the hub: Vendors pay in commission + delivery on UPI
/// orders, Drivers hand in all COD cash; the Manager pays Vendors for COD
/// goods, Drivers their delivery fees, and Quicky its share of the
/// commission, keeping their own (each order's snapshotted split).
class ManagerDailySettlementScreen extends ConsumerStatefulWidget {
  const ManagerDailySettlementScreen({super.key});

  @override
  ConsumerState<ManagerDailySettlementScreen> createState() => _ManagerDailySettlementScreenState();
}

class _ManagerDailySettlementScreenState extends ConsumerState<ManagerDailySettlementScreen> {
  String? _day;
  SettlementStatement? _statement;
  bool _loading = false;
  String? _error;

  /// The full statement (totals, net balances, adjustments) under the
  /// simple Today's-money lines.
  bool _showDetails = false;

  String get _territoryId => ref.read(accessScopeProvider)?.territoryId ?? '';

  Future<void> _load(String day) async {
    setState(() {
      _day = day;
      _loading = true;
      _error = null;
    });
    try {
      final data = await generateDailySettlement(_territoryId, day);
      if (mounted) setState(() => _statement = SettlementStatement(data));
    } on OrderActionException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final cutoff = ref.read(settlementCutoffProvider).valueOrNull ?? 22 * 60;
      _load(currentSettlementDay(cutoffMinutes: cutoff));
    });
  }

  Future<void> _pickDay() async {
    final current = DateTime.tryParse(_day ?? '') ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2025),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked == null) return;
    await _load('${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}');
  }

  String _partyName(PartyKey key, String managerId) {
    if (key == 'quicky') return 'QuickMandi';
    final [kind, id] = key.split(':');
    if (kind == 'manager') return id == managerId ? 'You' : 'Manager';
    if (kind == 'user') return 'Customer';
    final accounts = kind == 'vendor'
        ? ref.read(firestoreVendorsProvider).valueOrNull ?? const <Account>[]
        : ref.read(firestoreDriversProvider).valueOrNull ?? const <Account>[];
    final name = accounts.where((a) => a.id == id).map((a) => a.name).firstOrNull;
    return '${kind == 'vendor' ? 'Shop' : 'Driver'}: ${name ?? id}';
  }

  /// A "Received" / "Paid" tap on a Today's-money line: the same general
  /// payment as "Who owes whom", for that one pair and direction.
  Future<void> _recordLine(ManagerMoneyLine line, int amountPaise, String managerKey) =>
      _recordPayment(line.party, line.collect ? amountPaise : -amountPaise, managerKey, cash: line.kind == MoneyLineKind.codCash);

  /// Confirms or rejects a payment the other side recorded.
  Future<void> _answer(SettlementTransfer t, bool confirm) async {
    String? note;
    if (!confirm) {
      final c = TextEditingController();
      note = await showDialog<String>(
        context: context,
        builder: (d) => AlertDialog(
          title: const Text('What is wrong with this payment?'),
          content: TextField(
            controller: c,
            autofocus: true,
            decoration: const InputDecoration(hintText: 'e.g. I did not get this money'),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(d), child: const Text('Back')),
            ElevatedButton(onPressed: () => c.text.trim().isEmpty ? null : Navigator.pop(d, c.text.trim()), child: const Text('Send')),
          ],
        ),
      );
      if (note == null) return;
    }
    try {
      await runBusy(() => acknowledgeSettlementTransfer(t.id, confirm: confirm, note: note));
      if (mounted && _day != null) await _load(_day!);
    } on OrderActionException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  /// Settles a disputed payment this Manager is part of: remove the dispute
  /// (recorded by mistake — no balance changes) or, when they received it,
  /// confirm the money arrived. A reason is required.
  Future<void> _resolveDispute(Map<String, dynamic> d, String managerKey) async {
    final decision = await showDialog<(String, String)>(
      context: context,
      builder: (_) => _ResolveDisputeDialog(canConfirm: d['to'] == managerKey),
    );
    if (decision == null) return;
    try {
      await runBusy(() => resolveDisputedTransfer(d['transferId'] as String, resolution: decision.$1, reason: decision.$2));
      if (mounted && _day != null) await _load(_day!);
    } on OrderActionException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _recordPayment(PartyKey party, int balance, String managerKey, {bool cash = false}) async {
    final fromParty = balance > 0 ? party : managerKey;
    final toParty = balance > 0 ? managerKey : party;
    final result = await showModalBottomSheet<SettlementPaymentInput>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SettlementPaymentSheet(
        title: balance > 0 ? 'Payment received from ${_partyName(party, managerKey.split(':').last)}' : 'Payment made to ${_partyName(party, managerKey.split(':').last)}',
        suggestedPaise: balance.abs(),
        initialUpi: !cash,
      ),
    );
    if (result == null || _day == null) return;
    try {
      await runBusy(() => recordSettlementTransfer(
        idempotencyKey: List.generate(20, (_) => Random.secure().nextInt(36).toRadixString(36)).join(),
        territoryId: _territoryId,
        day: _day!,
        fromParty: fromParty,
        toParty: toParty,
        amountPaise: result.amountPaise,
        upi: result.upi,
        reference: result.reference,
        // Order money only — cancellation charges are settled in their own
        // section with their own purpose.
        purpose: 'general',
      ));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Settled. They can report a problem within 24 hours.')));
      await _load(_day!);
    } on OrderActionException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  /// Opens [ProposeAdjustmentSheet] (optionally prefilled from a
  /// discrepancy); the server files it as pending for the Super Admin.
  Future<void> _proposeAdjustment(String managerKey, {AdjustmentDraft? draft}) async {
    final s = _statement;
    if (s == null) return;
    final message = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (context) => ProposeAdjustmentSheet(
        statement: s,
        territoryId: _territoryId,
        managerKey: managerKey,
        partyName: (p) => _partyName(p, managerKey.split(':').last),
        draft: draft,
      ),
    );
    if (message == null || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    final scope = ref.watch(accessScopeProvider);
    final managerId = scope?.accountId ?? '';
    final managerKey = 'manager:$managerId';
    // Keep the name lookups live.
    ref.watch(firestoreVendorsProvider);
    ref.watch(firestoreDriversProvider);
    final s = _statement;
    // Cancellation money keeps its own section, shown up front only when
    // the day has some.
    final hasCancellation = s != null && (s.obligations.any((o) => o.isCancellation) || !(s.cancellationFinance?.isEmpty ?? true));
    // A past day is closed (2026-11-20): what it left unpaid is carried into
    // today's statement, so settling it here too would record it twice.
    final cutoffNow = ref.watch(settlementCutoffProvider).valueOrNull ?? 22 * 60;
    final closed = _day != null && _day!.compareTo(currentSettlementDay(cutoffMinutes: cutoffNow)) < 0;
    final adjustments = _day == null ? const <SettlementAdjustment>[] : ref.watch(dayAdjustmentsProvider(_day!)).valueOrNull ?? const <SettlementAdjustment>[];
    final attention = (ref.watch(activeOrdersProvider).valueOrNull ?? const <Order>[])
        .where((o) => o.paymentStatus == OrderPaymentStatus.disputed || (o.deliveryIssue != null && !o.deliveryIssue!.resolved && o.status == OrderStatus.pickedUp))
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Daily Settlement'),
        actions: [
          IconButton(icon: const Icon(Icons.calendar_month_rounded), tooltip: 'Choose day', onPressed: _pickDay),
          IconButton(icon: const Icon(Icons.history_rounded), tooltip: 'Settlement history', onPressed: () => context.push('/manager/settlement/history')),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _day == null ? Future.value() : _load(_day!),
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (attention.isNotEmpty) ...[
              Text('Needs attention', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              for (final o in attention) _AttentionCard(order: o),
              const SizedBox(height: 20),
            ],
            Row(children: [
              Expanded(child: Text(_day == null ? 'Settlement' : 'Settlement day ${dmyKey(_day!)}', style: Theme.of(context).textTheme.titleLarge)),
              if (s != null) _StatusChip(status: s.status),
            ]),
            const SizedBox(height: 4),
            Text('Orders delivered after the cut-off count towards the next day.', style: TextStyle(color: palette.textSecondary, fontSize: 12.5)),
            if (closed) ...[
              const SizedBox(height: 10),
              Container(
                key: const Key('dayClosedNotice'),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: palette.warning.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                child: Text(
                  'This day is closed. Anything it left unpaid is already in today\'s settlement — settle it there, once.',
                  style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w600, fontSize: 13),
                ),
              ),
            ],
            const SizedBox(height: 14),
            if (_loading) const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator())),
            if (_error != null) Text(_error!, style: TextStyle(color: palette.error, fontWeight: FontWeight.w600)),
            if (s != null && !_loading) ...[
              ManagerTodayMoneyCard(
                statement: s,
                managerKey: managerKey,
                transfers: ref.watch(myTransfersProvider).valueOrNull ?? const <SettlementTransfer>[],
                partyName: (p) => _partyName(p, managerId),
                onRecord: (line, amount) => _recordLine(line, amount, managerKey),
                onAnswer: _answer,
                readOnly: closed,
              ),
              if (s.customerRefunds case final r? when r.values.any((v) => v != 0)) ...[
                const SizedBox(height: 18),
                Text('Customer refunds (owed by shops, not you)', key: const Key('statementCustomerRefunds'), style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 6),
                _Box(children: [
                  _Line('Owed (assessed)', _rupees(r['owedPaise'] ?? 0)),
                  _Line('Refund confirmed', _rupees(r['refundedPaise'] ?? 0)),
                  _Line('Refund initiated — awaiting confirmation', _rupees(r['awaitingConfirmationPaise'] ?? 0)),
                  _Line('Refund disputed', _rupees(r['disputedPaise'] ?? 0)),
                  _Line('Still owed', _rupees(r['outstandingPaise'] ?? 0), strong: true),
                ]),
              ],
              if (hasCancellation) ...[
              const SizedBox(height: 18),
              CancellationSettlementSection(
                statement: s,
                territoryId: _territoryId,
                managerKey: managerKey,
                partyName: (p) => _partyName(p, managerId),
                onRecorded: () => _load(_day!),
                readOnly: closed,
              ),
              ],
              if (s.discrepancies.isNotEmpty) ...[
                const SizedBox(height: 18),
                Text('Problems to sort out', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: palette.error)),
                for (final d in s.discrepancies)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.report_problem_rounded, color: palette.error),
                    title: Text(settlementDiscrepancyText(d, (p) => _partyName(p, managerId))),
                    subtitle: Text(
                      adjustmentDraftFor(d, s, managerKey) == null
                          ? 'Sort this out with the people involved.'
                          : adjustments.any((a) => a.orderId == d['orderId'] && a.status == 'pending')
                          ? 'An adjustment is waiting for the Super Admin.'
                          : 'Once you know what happened, propose an adjustment for the Super Admin to decide.',
                    ),
                    trailing: d['type'] == 'disputedPayment' && d['transferId'] != null && (d['from'] == managerKey || d['to'] == managerKey)
                        ? TextButton(
                            key: Key('resolveDispute_${d['transferId']}'),
                            onPressed: () => _resolveDispute(d, managerKey),
                            child: const Text('Resolve'),
                          )
                        : adjustmentDraftFor(d, s, managerKey) == null || adjustments.any((a) => a.orderId == d['orderId'] && a.status != 'rejected')
                        ? null
                        : TextButton(
                            onPressed: () => _proposeAdjustment(managerKey, draft: adjustmentDraftFor(d, s, managerKey)),
                            child: const Text('Propose adjustment'),
                          ),
                  ),
              ],
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  key: const Key('settlementDetailsToggle'),
                  onPressed: () => setState(() => _showDetails = !_showDetails),
                  icon: Icon(_showDetails ? Icons.expand_less_rounded : Icons.expand_more_rounded),
                  label: Text(_showDetails ? 'Hide details' : 'Details'),
                ),
              ),
              if (_showDetails) ...[
                const _PricingCard(),
                const SizedBox(height: 16),
              _Box(children: [
                _Line('Orders delivered', '${s.total('orders')}'),
                _Line('Customers paid', _rupees(s.total('customerTotalPaise'))),
                _Line('Paid to shops by UPI', _rupees(s.vendorUpiCollections.values.fold(0, (a, b) => a + b))),
                _Line('Cash collected by drivers', _rupees(s.riderCodCollections.values.fold(0, (a, b) => a + b))),
                const Divider(),
                // No rates in these labels: a day can mix orders priced before
                // and after a pricing change. The server split each order at
                // its own rate; the current rates are on the pricing card.
                _Line('Commission (on items)', _rupees(s.total('commissionPaise'))),
                _Line('Your earnings (your share)', _rupees(s.total('managerEarningsPaise')), strong: true),
                _Line('Quicky share', _rupees(s.total('quickyEarningsPaise'))),
                // Paid by customers on top of the order; all of it is Quicky's.
                if (s.total('platformFeePaise') > 0) _Line('Platform fees (100% Quicky)', _rupees(s.total('platformFeePaise'))),
                _Line('Total to pay Quicky', _rupees(s.total('quickyRevenuePaise')), strong: true),
                _Line('Driver earnings (delivery fees)', _rupees(s.total('driverEarningsPaise'))),
                _Line('Shops’ earnings (goods)', _rupees(s.total('vendorEntitlementPaise'))),
                // Driver day fees (2026-11-12): collected from Drivers with
                // their COD cash; your share stays with you, Quicky's is in
                // what you pay Quicky.
                if (s.total('driverDayFees') > 0) ...[
                  const Divider(),
                  _Line('Driver day fees (${s.total('driverDayFees')})', _rupees(s.total('driverDayFeePaise'))),
                  _Line('Your share of day fees', _rupees(s.total('driverDayFeeManagerPaise')), strong: true),
                  _Line('Quicky’s share of day fees', _rupees(s.total('driverDayFeeQuickyPaise'))),
                ],
              ]),
              const SizedBox(height: 18),
              Text('Who owes whom', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              Text('Order money, including anything left over from earlier days. Cancellation charges are settled above.', style: TextStyle(color: palette.textSecondary, fontSize: 12.5)),
              const SizedBox(height: 8),
              ...[
                for (final e in s.generalBalances.entries)
                  if (e.value != 0 && e.key != managerKey)
                    _BalanceTile(
                      name: _partyName(e.key, managerId),
                      // A Vendor/Driver/Customer with a positive balance owes
                      // the hub; Quicky (and anyone owed) is paid by you.
                      text: e.value > 0 ? 'owes you ${_rupees(e.value)}' : 'you owe ${_rupees(-e.value)}',
                      owesYou: e.value > 0,
                      // QuickMandi marks money with it settled itself (2026-11-20).
                      onRecord: closed || e.key.startsWith('user:') || e.key == 'quicky' ? null : () => _recordPayment(e.key, e.value, managerKey),
                    ),
              ],
              if (s.generalBalances.entries.every((e) => e.value == 0 || e.key == managerKey))
                Text('Everything is settled.', style: TextStyle(color: palette.success, fontWeight: FontWeight.w700)),
              if (s.paymentsAwaitingAcknowledgement.isNotEmpty) ...[
                const SizedBox(height: 18),
                Text('Waiting for the other side to confirm', style: Theme.of(context).textTheme.titleMedium),
                for (final p in s.paymentsAwaitingAcknowledgement)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.hourglass_top_rounded),
                    title: Text('${_partyName(p['from'] as String, managerId)} → ${_partyName(p['to'] as String, managerId)}'),
                    subtitle: Text(settlementPurposeLabel(p['purpose'] as String? ?? 'general')),
                    trailing: Text(_rupees((p['amountPaise'] as num).toInt()), style: const TextStyle(fontWeight: FontWeight.w700)),
                  ),
              ],
              const SizedBox(height: 18),
              Text('Adjustments for this day', style: Theme.of(context).textTheme.titleMedium),
              if (adjustments.isEmpty)
                Text('None proposed.', style: TextStyle(color: palette.textSecondary, fontSize: 12.5))
              else
                for (final a in adjustments)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(switch (a.status) {
                      'approved' => Icons.check_circle_rounded,
                      'rejected' => Icons.cancel_rounded,
                      _ => Icons.hourglass_top_rounded,
                    }),
                    title: Text('${_partyName(a.from, managerId)} → ${_partyName(a.to, managerId)} · ${_rupees(a.amountPaise)}'),
                    subtitle: Text('${switch (a.status) {
                      'approved' => 'Approved',
                      'rejected' => 'Rejected',
                      _ => 'Waiting for the Super Admin',
                    }} · ${a.reason}'),
                  ),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: () => _proposeAdjustment(managerKey),
                  icon: const Icon(Icons.edit_note_rounded),
                  label: const Text('Propose an adjustment'),
                ),
              ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

/// Global delivery pricing and commission — read-only for Managers; only
/// the Super Admin can change them.
class _PricingCard extends ConsumerWidget {
  const _PricingCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(globalPricingProvider).valueOrNull;
    final slabs = (data?['deliverySlabs'] as List?) ??
        const [
          {'upToMeters': 3000, 'feePaise': 2000},
          {'upToMeters': 5000, 'feePaise': 3000},
          {'upToMeters': 7000, 'feePaise': 4000},
          {'upToMeters': 9000, 'feePaise': 5000},
          {'upToMeters': 11000, 'feePaise': 6000},
        ];
    final commission = ((data?['commissionBps'] as num?) ?? 1000) / 100;
    // No saved pricing: the server's built-in 50/50 split.
    final share = ((data?['managerShareBps'] as num?) ?? kDefaultManagerShareBps) / 100;
    var from = 0.0;
    return Card(
      child: ExpansionTile(
        title: const Text('Pricing (set by Quicky)'),
        subtitle: Text('Commission ${formatPercent(commission)}% · your share ${formatPercent(share)}%'),
        children: [
          for (final s in slabs)
            () {
              final upTo = ((s as Map)['upToMeters'] as num) / 1000;
              final line = ListTile(
                dense: true,
                title: Text('${from == 0 ? '0' : 'Above ${from.toStringAsFixed(0)}'}–${upTo.toStringAsFixed(0)} km'),
                trailing: Text(_rupees((s['feePaise'] as num).toInt()), style: const TextStyle(fontWeight: FontWeight.w700)),
              );
              from = upTo.toDouble();
              return line;
            }(),
          const ListTile(dense: true, title: Text('Farther than that: not delivered')),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final SettlementStatus status;

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    final color = switch (status) {
      SettlementStatus.completed => palette.success,
      SettlementStatus.disputed => palette.error,
      SettlementStatus.partiallySettled => palette.warning,
      SettlementStatus.pending => palette.textSecondary,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
      child: Text(status.label, style: TextStyle(color: color, fontWeight: FontWeight.w700)),
    );
  }
}

class _Box extends StatelessWidget {
  const _Box({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: context.colors.surfaceMuted, borderRadius: BorderRadius.circular(16)),
    child: Column(children: children),
  );
}

class _Line extends StatelessWidget {
  const _Line(this.label, this.value, {this.strong = false});
  final String label;
  final String value;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(fontWeight: strong ? FontWeight.w800 : FontWeight.w600, color: strong ? context.colors.primary : context.colors.textPrimary);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [Expanded(child: Text(label, style: style)), Text(value, style: style)]),
    );
  }
}

class _BalanceTile extends StatelessWidget {
  const _BalanceTile({required this.name, required this.text, required this.owesYou, required this.onRecord});
  final String name;
  final String text;
  final bool owesYou;
  final VoidCallback? onRecord;

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.w700)),
                Text(text, style: TextStyle(color: owesYou ? palette.success : palette.warning, fontWeight: FontWeight.w600)),
              ]),
            ),
            if (onRecord != null) TextButton(onPressed: onRecord, child: Text(owesYou ? 'Got paid' : 'Paid')),
          ],
        ),
      ),
    );
  }
}

/// A payment dispute or failed delivery in the territory, with the
/// Manager's ways to resolve it.
class _AttentionCard extends StatelessWidget {
  const _AttentionCard({required this.order});
  final Order order;

  Future<void> _run(BuildContext context, Future<void> Function() action) async {
    try {
      await runBusy(action);
    } on OrderActionException catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<String?> _ask(BuildContext context, String title) {
    final c = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(title),
        content: TextField(controller: c, autofocus: true, decoration: const InputDecoration(hintText: 'What did you find out?')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d), child: const Text('Back')),
          ElevatedButton(onPressed: () => c.text.trim().isEmpty ? null : Navigator.pop(d, c.text.trim()), child: const Text('Save')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    final dispute = order.paymentStatus == OrderPaymentStatus.disputed;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(dispute ? 'UPI payment dispute · ${order.id}' : 'Delivery failed · ${order.id}', style: TextStyle(fontWeight: FontWeight.w800, color: palette.error)),
            const SizedBox(height: 4),
            Text(dispute ? (order.payment?.issueReason ?? '') : (order.deliveryIssue?.reason ?? '')),
            Text('${order.userName} · ${order.vendorName} · ${AppFormat.currency(order.total)}', style: TextStyle(color: palette.textSecondary)),
            Wrap(spacing: 4, children: dispute
                ? [
                    TextButton(
                      onPressed: () async {
                        final note = await _ask(context, 'Shop received the money?');
                        if (note != null && context.mounted) await _run(context, () => resolvePaymentDispute(order.id, received: true, note: note));
                      },
                      child: const Text('Money was received'),
                    ),
                    TextButton(
                      onPressed: () async {
                        final note = await _ask(context, 'Money not received — cancel the order?');
                        if (note != null && context.mounted) await _run(context, () => resolvePaymentDispute(order.id, received: false, note: note));
                      },
                      child: Text('Not received', style: TextStyle(color: palette.error)),
                    ),
                  ]
                : [
                    TextButton(
                      onPressed: () async {
                        final note = await _ask(context, 'Order returned to the shop?');
                        if (note != null && context.mounted) await _run(context, () => resolveDeliveryIssue(order.id, delivered: false, reason: note));
                      },
                      child: const Text('Mark returned'),
                    ),
                    // The authorised exception to the delivery code: only
                    // with the Driver's photo (the server checks it exists).
                    FutureBuilder<ListResult>(
                      future: FirebaseStorage.instance.ref('delivery_proofs/${order.id}').listAll(),
                      builder: (context, snap) {
                        final photos = snap.data?.items ?? const <Reference>[];
                        if (photos.isEmpty) return const SizedBox.shrink();
                        return TextButton(
                          onPressed: () async {
                            final note = await _ask(context, 'Count as delivered? (driver sent a photo)');
                            if (note != null && context.mounted) {
                              await _run(context, () => resolveDeliveryIssue(order.id, delivered: true, reason: note, proofPath: photos.last.fullPath));
                            }
                          },
                          child: const Text('Delivered (photo)'),
                        );
                      },
                    ),
                  ]),
          ],
        ),
      ),
    );
  }
}

/// Remove a disputed payment's dispute (recorded by mistake) or, for the
/// Manager who received it, confirm it arrived. Pops `(resolution, reason)`.
class _ResolveDisputeDialog extends StatefulWidget {
  const _ResolveDisputeDialog({required this.canConfirm});
  final bool canConfirm;

  @override
  State<_ResolveDisputeDialog> createState() => _ResolveDisputeDialogState();
}

class _ResolveDisputeDialogState extends State<_ResolveDisputeDialog> {
  final _reason = TextEditingController();
  String _resolution = 'void';

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Resolve disputed payment'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RadioGroup<String>(
            groupValue: _resolution,
            onChanged: (v) => setState(() => _resolution = v ?? _resolution),
            child: Column(
              children: [
                const RadioListTile(
                  key: Key('disputeVoid'),
                  value: 'void',
                  title: Text('Remove the dispute'),
                  subtitle: Text('It was recorded by mistake (e.g. twice). Nobody\'s balance changes.'),
                ),
                if (widget.canConfirm)
                  const RadioListTile(
                    key: Key('disputeConfirm'),
                    value: 'confirm',
                    title: Text('I received this money'),
                    subtitle: Text('Counts as paid.'),
                  ),
              ],
            ),
          ),
          TextField(
            key: const Key('disputeReason'),
            controller: _reason,
            decoration: const InputDecoration(labelText: 'Reason (required)'),
            maxLength: 300,
            onChanged: (_) => setState(() {}),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Back')),
      TextButton(
        key: const Key('disputeSubmit'),
        onPressed: _reason.text.trim().isEmpty ? null : () => Navigator.of(context).pop((_resolution, _reason.text.trim())),
        child: const Text('Resolve'),
      ),
    ],
  );
}
