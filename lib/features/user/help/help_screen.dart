import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:intl/intl.dart';

import '../../../core/session/session_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/account.dart';
import '../../../data/models/ticket.dart';
import '../../../data/providers/firestore_managers_provider.dart';
import '../../../data/providers/firestore_orders_provider.dart';
import '../../../data/providers/firestore_territories_provider.dart';
import '../../../data/providers/firestore_tickets_provider.dart';
import '../../../data/providers/firestore_vendors_provider.dart';
import '../../../l10n/app_localizations_context.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/error_reporting.dart';
import '../../../shared/widgets/status_chip.dart';
import '../home/selected_territory_provider.dart';

final _ticketOrderDateFmt = DateFormat('d MMM, h:mm a');

class _Faq {
  const _Faq(this.question, this.answer);
  final String question;
  final String answer;
}

/// Help & Support / Raise a Ticket (spec §4.20): a static FAQ list plus a
/// ticket form that raises a real, Firestore-backed [SupportTicket]
/// (`firestore_tickets_provider.dart`) addressed to a Territory Manager.
/// Which territory: when the ticket has a "Related order" picked, its own
/// Vendor's territory — a User can browse a different "Deliver to"
/// location on Home at any time after placing an order, so the order's own
/// territory (not whatever happens to be selected right now) is who
/// actually needs to see a ticket about it. Only when no order is picked
/// does this fall back to the currently-selected Home territory
/// (`selectedTerritoryProvider`, same resolution Home itself falls back to
/// via `resolveDefaultTerritory`). Once raised, it opens straight into a
/// live 1:1 chat with that Manager (`user_ticket_chat_screen.dart`).
class HelpScreen extends ConsumerStatefulWidget {
  const HelpScreen({super.key});

  @override
  ConsumerState<HelpScreen> createState() => _HelpScreenState();
}

class _HelpScreenState extends ConsumerState<HelpScreen> {
  List<_Faq> _faqs(AppLocalizations l10n) => [
    _Faq(l10n.helpFaq1Q, l10n.helpFaq1A),
    _Faq(l10n.helpFaq2Q, l10n.helpFaq2A),
    _Faq(l10n.helpFaq3Q, l10n.helpFaq3A),
    _Faq(l10n.helpFaq4Q, l10n.helpFaq4A),
    _Faq(l10n.helpFaq5Q, l10n.helpFaq5A),
  ];

  final _subjectController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _submitting = false;
  String? _error;

  /// Null means "not about a specific order" — the default, since not
  /// every ticket is (a general app question has nothing to attach).
  String? _selectedOrderId;

  @override
  void dispose() {
    _subjectController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submitTicket() async {
    if (!_formKey.currentState!.validate()) return;
    final session = ref.read(sessionControllerProvider);
    final account = session.account;
    if (account == null) return;

    setState(() {
      _submitting = true;
      _error = null;
    });

    // The order's own territory when this ticket is about one — resolved
    // via its vendor, since Order itself doesn't carry a territory field —
    // takes priority over the device's currently-selected Home territory.
    // Home's pick can genuinely differ from where the order was actually
    // placed (a User can browse a different "Deliver to" location any time
    // after ordering, and that's the whole reason this bug existed:
    // raising a ticket *about* an order routed by whatever territory
    // happened to be selected *right now*, not the one that order's
    // Vendor — and so its real Manager — actually belongs to.
    String? orderTerritoryName;
    if (_selectedOrderId != null) {
      final order = (ref.read(firestoreOrdersProvider).valueOrNull ?? const [])
          .where((o) => o.id == _selectedOrderId)
          .firstOrNull;
      if (order != null) {
        orderTerritoryName = ref
            .read(liveVendorAccountProvider(order.vendorId))
            ?.territory;
      }
    }

    final territories =
        ref.read(firestoreTerritoriesProvider).valueOrNull ?? const [];
    final territory =
        ref.read(selectedTerritoryProvider) ??
        resolveDefaultTerritory(territories);
    final managers =
        ref.read(firestoreManagersProvider).valueOrNull ?? const [];
    // Trimmed + case-insensitive, not a raw `==` — a Manager's territory
    // string (set once, at creation, in QuickyAdmin) and a Territory's own
    // name should always match exactly since both trace back to the same
    // `territories` collection, but comparing loosely costs nothing and
    // means a stray space or casing difference someone typed by hand
    // doesn't turn into a dead-end "no manager" error for what's otherwise
    // a real, working match.
    final territoryName = (orderTerritoryName ?? territory?.name)
        ?.trim()
        .toLowerCase();
    final manager = managers
        .where((m) => m.territory?.trim().toLowerCase() == territoryName)
        .firstOrNull;
    if (manager == null) {
      setState(() {
        _submitting = false;
        _error = context.l10n.helpNoManagerForTerritory;
      });
      return;
    }

    try {
      final ticket = await raiseTicket(
        raisedByRole: AppRole.user,
        raisedById: account.id,
        raisedByName: account.name,
        recipientRole: AppRole.manager,
        recipientId: manager.id,
        subject: _subjectController.text.trim(),
        description: _descriptionController.text.trim(),
        orderId: _selectedOrderId,
      );
      _subjectController.clear();
      _descriptionController.clear();
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _selectedOrderId = null;
      });
      context.push('/user/ticket/${ticket.id}/chat');
    } catch (e, st) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = friendlyError(e, action: 'Raising ticket', stackTrace: st);
      });
    }
  }

  StatusTone _tone(TicketStatus status) => switch (status) {
    TicketStatus.open => StatusTone.warning,
    TicketStatus.inProgress => StatusTone.info,
    TicketStatus.closed => StatusTone.neutral,
  };

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    final l10n = context.l10n;
    final account = ref.watch(
      sessionControllerProvider.select((s) => s.account),
    );
    final myTickets =
        (ref.watch(firestoreTicketsProvider).valueOrNull ?? const [])
            .where((t) => t.raisedById == account?.id)
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final myOrders =
        (ref.watch(firestoreOrdersProvider).valueOrNull ?? const [])
            .where((o) => o.userId == account?.id)
            .toList()
          ..sort((a, b) => b.placedAt.compareTo(a.placedAt));
    final faqs = _faqs(l10n);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.helpScreenTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: [
          Text(
            l10n.helpFaqHeading,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: palette.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: palette.border),
            ),
            child: Column(
              children: [
                for (var i = 0; i < faqs.length; i++) ...[
                  Theme(
                    data: Theme.of(
                      context,
                    ).copyWith(dividerColor: Colors.transparent),
                    // ExpansionTile wraps a ListTile internally, which paints
                    // its background/ink splashes on the nearest Material
                    // ancestor — but the enclosing Container above has its
                    // own opaque background color sitting in between, which
                    // silently hides those effects (Flutter's own
                    // "ListTile background color or ink splashes may be
                    // invisible" warning). A transparent Material right here
                    // gives the ListTile a paint surface of its own, visually
                    // sitting on top of the Container's background rather
                    // than hidden behind it.
                    child: Material(
                      color: Colors.transparent,
                      child: ExpansionTile(
                        title: Text(
                          faqs[i].question,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13.5,
                          ),
                        ),
                        childrenPadding: const EdgeInsets.fromLTRB(
                          16,
                          0,
                          16,
                          14,
                        ),
                        expandedCrossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            faqs[i].answer,
                            style: TextStyle(
                              color: palette.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (i != faqs.length - 1)
                    Divider(height: 1, color: palette.divider),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            l10n.helpRaiseTicketHeading,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: palette.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: palette.border),
            ),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    controller: _subjectController,
                    enabled: !_submitting,
                    decoration: InputDecoration(
                      labelText: l10n.helpSubjectLabel,
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? l10n.fieldRequired
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _descriptionController,
                    minLines: 3,
                    maxLines: 5,
                    enabled: !_submitting,
                    decoration: InputDecoration(
                      labelText: l10n.helpDescribeIssueLabel,
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? l10n.fieldRequired
                        : null,
                  ),
                  const SizedBox(height: 12),
                  // Picked from this User's own real orders, not free-typed
                  // — the FAQ used to say "put your order ID in the
                  // description" (still true as a fallback), but a picker
                  // can't be misspelled and always points at an order the
                  // Manager can actually open.
                  DropdownButtonFormField<String?>(
                    initialValue: _selectedOrderId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Related order (optional)',
                    ),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('No specific order'),
                      ),
                      for (final o in myOrders.take(20))
                        DropdownMenuItem<String?>(
                          value: o.id,
                          child: Text(
                            // Leads with the order id itself — same id
                            // shown as the AppBar title on
                            // order_detail_screen.dart, so it's always the
                            // one thing on this row a User could actually
                            // go cross-check against — vendor/date are just
                            // there to tell two rows apart at a glance.
                            '#${o.id} · ${o.vendorName} · ${_ticketOrderDateFmt.format(o.placedAt)}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: _submitting
                        ? null
                        : (v) => setState(() => _selectedOrderId = v),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _error!,
                      style: TextStyle(
                        color: palette.error,
                        fontWeight: FontWeight.w600,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _submitting ? null : _submitTicket,
                      child: _submitting
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2.4,
                              ),
                            )
                          : Text(l10n.helpSubmitTicketButton),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (myTickets.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text(
              l10n.helpYourTicketsHeading,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 10),
            for (final ticket in myTickets)
              _TicketTile(
                ticket: ticket,
                tone: _tone(ticket.status),
                onTap: () => context.push('/user/ticket/${ticket.id}/chat'),
              ),
          ],
        ],
      ),
    );
  }
}

class _TicketTile extends StatelessWidget {
  const _TicketTile({
    required this.ticket,
    required this.tone,
    required this.onTap,
  });
  final SupportTicket ticket;
  final StatusTone tone;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: palette.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: palette.border),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ticket.subject,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      ticket.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: palette.textSecondary,
                        fontSize: 12.5,
                      ),
                    ),
                    if (ticket.orderId != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Order #${ticket.orderId}',
                        style: TextStyle(
                          color: palette.primary,
                          fontWeight: FontWeight.w700,
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              StatusChip(label: ticket.status.label, tone: tone),
              const SizedBox(width: 4),
              Icon(Icons.chevron_right_rounded, color: palette.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
