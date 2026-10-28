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
import '../../../shared/widgets/currency_text.dart';

String _rupees(int paise) => AppFormat.currency(paise / 100);

/// Daily settlement for the Manager's territory (Phase 2). Everything on
/// this screen comes from the server's statement (`generateDailySettlement`,
/// computed from the ledger): who collected what, who owes whom, which
/// payments have been made and acknowledged, and what's still open. A day
/// is "Completed" only when every balance is zero through acknowledged
/// payments — never just because the day is over.
///
/// The Manager is the hub: Vendors pay in commission + delivery on UPI
/// orders, Drivers hand in all COD cash; the Manager pays Vendors for COD
/// goods, Drivers their delivery fees, and Quicky its 40% share, keeping
/// their own 60%.
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
    if (key == 'quicky') return 'Quicky (Super Admin)';
    final [kind, id] = key.split(':');
    if (kind == 'manager') return id == managerId ? 'You' : 'Manager';
    if (kind == 'user') return 'Customer';
    final accounts = kind == 'vendor'
        ? ref.read(firestoreVendorsProvider).valueOrNull ?? const <Account>[]
        : ref.read(firestoreDriversProvider).valueOrNull ?? const <Account>[];
    final name = accounts.where((a) => a.id == id).map((a) => a.name).firstOrNull;
    return '${kind == 'vendor' ? 'Shop' : 'Driver'}: ${name ?? id}';
  }

  Future<void> _recordPayment(PartyKey party, int balance, String managerKey) async {
    final fromParty = balance > 0 ? party : managerKey;
    final toParty = balance > 0 ? managerKey : party;
    final result = await showModalBottomSheet<({int amountPaise, bool upi, String? reference})>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _PaymentSheet(
        title: balance > 0 ? 'Payment received from ${_partyName(party, managerKey.split(':').last)}' : 'Payment made to ${_partyName(party, managerKey.split(':').last)}',
        suggestedPaise: balance.abs(),
      ),
    );
    if (result == null || _day == null) return;
    try {
      await recordSettlementTransfer(
        idempotencyKey: List.generate(20, (_) => Random.secure().nextInt(36).toRadixString(36)).join(),
        territoryId: _territoryId,
        day: _day!,
        fromParty: fromParty,
        toParty: toParty,
        amountPaise: result.amountPaise,
        upi: result.upi,
        reference: result.reference,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Recorded. It counts once the other side confirms it.')));
      await _load(_day!);
    } on OrderActionException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
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
            const _PricingCard(),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(child: Text(_day == null ? 'Settlement' : 'Settlement day $_day', style: Theme.of(context).textTheme.titleLarge)),
              if (s != null) _StatusChip(status: s.status),
            ]),
            const SizedBox(height: 4),
            Text('Orders delivered after the cut-off count towards the next day.', style: TextStyle(color: palette.textSecondary, fontSize: 12.5)),
            const SizedBox(height: 14),
            if (_loading) const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator())),
            if (_error != null) Text(_error!, style: TextStyle(color: palette.error, fontWeight: FontWeight.w600)),
            if (s != null && !_loading) ...[
              _Box(children: [
                _Line('Orders delivered', '${s.total('orders')}'),
                _Line('Customers paid', _rupees(s.total('customerTotalPaise'))),
                _Line('Paid to shops by UPI', _rupees(s.vendorUpiCollections.values.fold(0, (a, b) => a + b))),
                _Line('Cash collected by drivers', _rupees(s.riderCodCollections.values.fold(0, (a, b) => a + b))),
                const Divider(),
                _Line('Commission (10% of items)', _rupees(s.total('commissionPaise'))),
                _Line('Your earnings (60%)', _rupees(s.total('managerEarningsPaise')), strong: true),
                _Line('Quicky share (40%)', _rupees(s.total('quickyEarningsPaise'))),
                // Paid by customers on top of the order; all of it is Quicky's.
                if (s.total('platformFeePaise') > 0) _Line('Platform fees (100% Quicky)', _rupees(s.total('platformFeePaise'))),
                _Line('Total to pay Quicky', _rupees(s.total('quickyEarningsPaise') + s.total('platformFeePaise')), strong: true),
                _Line('Driver earnings (delivery fees)', _rupees(s.total('driverEarningsPaise'))),
                _Line('Shops’ earnings (goods)', _rupees(s.total('vendorEntitlementPaise'))),
              ]),
              const SizedBox(height: 18),
              Text('Who owes whom', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              Text('Includes anything left over from earlier days.', style: TextStyle(color: palette.textSecondary, fontSize: 12.5)),
              const SizedBox(height: 8),
              ...[
                for (final e in s.remainingBalances.entries)
                  if (e.value != 0 && e.key != managerKey)
                    _BalanceTile(
                      name: _partyName(e.key, managerId),
                      // A Vendor/Driver/Customer with a positive balance owes
                      // the hub; Quicky (and anyone owed) is paid by you.
                      text: e.value > 0 ? 'owes you ${_rupees(e.value)}' : 'you owe ${_rupees(-e.value)}',
                      owesYou: e.value > 0,
                      onRecord: e.key.startsWith('user:') ? null : () => _recordPayment(e.key, e.value, managerKey),
                    ),
              ],
              if (s.remainingBalances.entries.every((e) => e.value == 0 || e.key == managerKey))
                Text('Everything is settled.', style: TextStyle(color: palette.success, fontWeight: FontWeight.w700)),
              if (s.paymentsAwaitingAcknowledgement.isNotEmpty) ...[
                const SizedBox(height: 18),
                Text('Waiting for the other side to confirm', style: Theme.of(context).textTheme.titleMedium),
                for (final p in s.paymentsAwaitingAcknowledgement)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.hourglass_top_rounded),
                    title: Text('${_partyName(p['from'] as String, managerId)} → ${_partyName(p['to'] as String, managerId)}'),
                    trailing: Text(_rupees((p['amountPaise'] as num).toInt()), style: const TextStyle(fontWeight: FontWeight.w700)),
                  ),
              ],
              if (s.discrepancies.isNotEmpty) ...[
                const SizedBox(height: 18),
                Text('Problems to sort out', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: palette.error)),
                for (final d in s.discrepancies)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.report_problem_rounded, color: palette.error),
                    title: Text(switch (d['type']) {
                      'codShortfall' => 'Driver collected ${_rupees((d['amountPaise'] as num).toInt())} less cash (order ${d['orderId']})',
                      'disputedTransfer' => 'A payment of ${_rupees((d['amountPaise'] as num).toInt())} was disputed',
                      'noManager' => 'Order ${d['orderId']} has no territory manager',
                      _ => '${d['type']}',
                    }),
                    subtitle: const Text('Ask the Super Admin for an adjustment once you know what happened.'),
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
    final share = ((data?['managerShareBps'] as num?) ?? 6000) / 100;
    var from = 0.0;
    return Card(
      child: ExpansionTile(
        title: const Text('Pricing (set by Quicky)'),
        subtitle: Text('Commission ${commission.toStringAsFixed(0)}% · your share ${share.toStringAsFixed(0)}%'),
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

/// Amount, method and UPI reference for a settlement payment.
class _PaymentSheet extends StatefulWidget {
  const _PaymentSheet({required this.title, required this.suggestedPaise});
  final String title;
  final int suggestedPaise;

  @override
  State<_PaymentSheet> createState() => _PaymentSheetState();
}

class _PaymentSheetState extends State<_PaymentSheet> {
  late final _amount = TextEditingController(text: (widget.suggestedPaise / 100).toStringAsFixed(2));
  final _reference = TextEditingController();
  bool _upi = true;
  String? _error;

  void _save() {
    final rupees = double.tryParse(_amount.text.trim());
    if (rupees == null || rupees <= 0) {
      setState(() => _error = 'Enter the amount.');
      return;
    }
    final reference = _reference.text.trim();
    if (_upi && reference.isEmpty) {
      setState(() => _error = 'Enter the UPI reference (UTR).');
      return;
    }
    Navigator.pop(context, (amountPaise: (rupees * 100).round(), upi: _upi, reference: reference.isEmpty ? null : reference));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          TextField(controller: _amount, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Amount', prefixText: '₹ ')),
          const SizedBox(height: 12),
          SegmentedButton<bool>(
            segments: const [ButtonSegment(value: true, label: Text('UPI')), ButtonSegment(value: false, label: Text('Cash'))],
            selected: {_upi},
            onSelectionChanged: (s) => setState(() => _upi = s.first),
          ),
          const SizedBox(height: 12),
          TextField(controller: _reference, decoration: InputDecoration(labelText: _upi ? 'UPI reference (UTR)' : 'Note (optional)')),
          if (_error != null) ...[const SizedBox(height: 8), Text(_error!, style: TextStyle(color: context.colors.error))],
          const SizedBox(height: 16),
          SizedBox(width: double.infinity, child: ElevatedButton(onPressed: _save, child: const Text('Save'))),
        ],
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
      await action();
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
