import 'dart:math';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/account.dart';
import '../../../data/providers/firestore_vendors_provider.dart';
import '../../../data/providers/order_actions.dart';
import '../../../data/providers/vendor_incidents_provider.dart';
import '../../../l10n/app_localizations_context.dart';
import '../../../shared/cancellation_reasons.dart';
import '../../../shared/error_reporting.dart';
import '../../../shared/widgets/currency_text.dart';
import 'reversal_proposal_sheet.dart';

/// `reviewVendorIncident`'s shape — injectable for widget tests.
typedef ReviewIncident = Future<({String reviewId, bool duplicate})> Function(String incidentId, {required String outcome, String? note, String? requestId});

/// Manager: shop cancellations in the territory (Phase I.4), newest first —
/// what the shop said, what the server charged, and the Manager's review.
/// Reviewing is a record only: excusing never reverses a charge (a reversal
/// is a separate adjustment the Super Admin approves), and nothing here
/// computes or changes an amount.
class ManagerIncidentsScreen extends ConsumerWidget {
  const ManagerIncidentsScreen({super.key, this.review = reviewVendorIncident});
  final ReviewIncident review;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.colors;
    final incidents = ref.watch(territoryIncidentsProvider);
    final vendors = ref.watch(firestoreVendorsProvider).valueOrNull ?? const <Account>[];
    String vendorName(String id) => vendors.where((v) => v.id == id).map((v) => v.name).firstOrNull ?? id;
    return Scaffold(
      appBar: AppBar(title: const Text('Shop cancellations')),
      body: incidents.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              e is FirebaseException && e.code == 'permission-denied'
                  ? 'You can only see cancellations in your own territory.'
                  : friendlyError(e, action: 'Loading shop cancellations', stackTrace: st),
              textAlign: TextAlign.center,
              style: TextStyle(color: palette.error),
            ),
          ),
        ),
        data: (list) => list.isEmpty
            ? Center(child: Text('No shop has cancelled an accepted order.', style: TextStyle(color: palette.textMuted)))
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(
                    'Reviewing records what you found. Excusing a cancellation doesn’t refund its charge — that needs an adjustment approved by Quicky.',
                    style: TextStyle(color: palette.textSecondary, fontSize: 12.5),
                  ),
                  const SizedBox(height: 12),
                  for (final i in list) IncidentCard(incident: i, vendorName: vendorName(i.vendorId), review: review),
                ],
              ),
      ),
    );
  }
}

class IncidentCard extends ConsumerWidget {
  const IncidentCard({super.key, required this.incident, required this.vendorName, required this.review});
  final VendorIncident incident;
  final String vendorName;
  final ReviewIncident review;

  String _when(DateTime? at) {
    if (at == null) return incident.settlementDay;
    final l = at.toLocal();
    return '${l.day.toString().padLeft(2, '0')}/${l.month.toString().padLeft(2, '0')} ${l.hour.toString().padLeft(2, '0')}:${l.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.colors;
    final l10n = context.l10n;
    final reviews = ref.watch(incidentReviewsProvider(incident.id));
    final latest = reviews.valueOrNull?.firstOrNull;
    final charge = incident.chargePaise > 0
        ? 'Charge ${AppFormat.currency(incident.chargePaise / 100)}${incident.driverSharePaise > 0 ? ' · driver gets ${AppFormat.currency(incident.driverSharePaise / 100)}' : ''}'
        : incident.noChargeReason == 'legacyOrderNoMoneySnapshot'
        ? 'No charge (order placed before charges applied)'
        : 'No charge';
    return Card(
      key: ValueKey('incident:${incident.id}'),
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(child: Text(vendorName, style: const TextStyle(fontWeight: FontWeight.w800))),
              Text(_when(incident.at), style: TextStyle(color: palette.textMuted, fontSize: 12)),
            ]),
            Text('Order ${incident.orderId} · ${incident.driverAssigned ? 'driver assigned' : 'no driver yet'}', style: TextStyle(color: palette.textSecondary, fontSize: 12.5)),
            const SizedBox(height: 6),
            Text(reasonLabel(l10n, incident.reasonCode), style: const TextStyle(fontWeight: FontWeight.w600)),
            if ((incident.remark ?? '').isNotEmpty) Text('“${incident.remark}”', style: TextStyle(color: palette.textSecondary)),
            const SizedBox(height: 4),
            Text(charge, style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w600)),
            if (incident.reviewFlags.isNotEmpty) ...[
              const SizedBox(height: 6),
              Wrap(spacing: 6, children: [
                for (final f in incident.reviewFlags)
                  Chip(
                    visualDensity: VisualDensity.compact,
                    label: Text(incidentFlagLabel(f)),
                    backgroundColor: palette.warning.withValues(alpha: 0.15),
                  ),
              ]),
            ],
            const SizedBox(height: 6),
            Row(children: [
              Expanded(
                child: reviews.when(
                  loading: () => Text('Loading review…', style: TextStyle(color: palette.textMuted, fontSize: 12.5)),
                  error: (e, st) => Text('Couldn’t load the review.', style: TextStyle(color: palette.error, fontSize: 12.5)),
                  data: (_) => latest == null
                      ? Text('Not reviewed yet', style: TextStyle(color: palette.warning, fontWeight: FontWeight.w600))
                      : Text(
                          'Reviewed: ${incidentOutcomeLabel(latest.outcome)}${(latest.note ?? '').isEmpty ? '' : ' — ${latest.note}'}',
                          style: TextStyle(color: palette.success, fontWeight: FontWeight.w600),
                        ),
                ),
              ),
              TextButton(
                onPressed: () async {
                  final message = await showModalBottomSheet<String>(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) => IncidentReviewSheet(incident: incident, review: review),
                  );
                  if (message != null && context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
                },
                child: Text(latest == null ? 'Review' : 'Review again'),
              ),
            ]),
            // Excusing never refunds; reversing the charge is a separate
            // request the Super Admin decides (Phase I.4.1).
            if (incident.chargePaise > 0)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  key: ValueKey('proposeReversal:${incident.id}'),
                  onPressed: () async {
                    final message = await showModalBottomSheet<String>(
                      context: context,
                      isScrollControlled: true,
                      builder: (_) => ReversalProposalSheet(incident: incident),
                    );
                    if (message != null && context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
                  },
                  child: const Text('Propose reversing the charge'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// The Manager's review of one incident. One request id per sheet, so a
/// retry after a timeout returns the first review instead of filing a
/// second; a note is required to excuse or escalate.
class IncidentReviewSheet extends StatefulWidget {
  const IncidentReviewSheet({super.key, required this.incident, required this.review});
  final VendorIncident incident;
  final ReviewIncident review;

  @override
  State<IncidentReviewSheet> createState() => _IncidentReviewSheetState();
}

class _IncidentReviewSheetState extends State<IncidentReviewSheet> {
  final _requestId = List.generate(20, (_) => Random.secure().nextInt(36).toRadixString(36)).join();
  final _note = TextEditingController();
  String? _outcome;
  bool _busy = false;
  String? _error;

  bool get _noteRequired => _outcome == 'excused' || _outcome == 'escalated';
  bool get _canSave => !_busy && _outcome != null && (!_noteRequired || _note.text.trim().isNotEmpty);

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_canSave) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final note = _note.text.trim();
    try {
      final r = await widget.review(widget.incident.id, outcome: _outcome!, note: note.isEmpty ? null : note, requestId: _requestId);
      if (mounted) Navigator.pop(context, r.duplicate ? 'This review was already saved.' : 'Review saved.');
    } on OrderActionException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Review cancellation', style: Theme.of(context).textTheme.titleLarge),
            Text('Order ${widget.incident.orderId}', style: TextStyle(color: palette.textSecondary)),
            const SizedBox(height: 8),
            RadioGroup<String>(
              groupValue: _outcome,
              onChanged: (v) => _busy ? null : setState(() => _outcome = v),
              child: Column(children: [
                for (final o in incidentReviewOutcomes) RadioListTile<String>(value: o, contentPadding: EdgeInsets.zero, title: Text(incidentOutcomeLabel(o))),
              ]),
            ),
            if (_outcome == 'excused')
              Text('Excusing doesn’t refund the charge. Ask Quicky for an adjustment if it should be reversed.', style: TextStyle(color: palette.warning, fontSize: 12.5)),
            const SizedBox(height: 6),
            TextField(
              controller: _note,
              maxLength: 500,
              minLines: 2,
              maxLines: 4,
              enabled: !_busy,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(labelText: _noteRequired ? 'Note (required)' : 'Note (optional)'),
            ),
            if (_error != null) ...[const SizedBox(height: 6), Text(_error!, style: TextStyle(color: palette.error))],
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _canSave ? _save : null,
                child: _busy ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Save review'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
