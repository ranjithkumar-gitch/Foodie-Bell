import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/account.dart';
import '../../../data/models/ticket.dart';
import '../../../data/providers/firestore_tickets_provider.dart';
import '../../../shared/error_reporting.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/status_chip.dart';
import '../manager_session.dart';

StatusTone ticketTone(TicketStatus status) => switch (status) {
  TicketStatus.open => StatusTone.warning,
  TicketStatus.inProgress => StatusTone.info,
  TicketStatus.closed => StatusTone.neutral,
};

/// Help & Support (spec §7.18) — two tabs: escalating a real,
/// Firestore-backed [SupportTicket] (`firestore_tickets_provider.dart`) to
/// Admin, and this Manager's inbox of tickets raised *to* them by
/// Users/Vendors/Drivers in their territory. Either tab's tickets open into
/// a live 1:1 chat (`manager_ticket_chat_screen.dart`).
class ManagerSupportScreen extends ConsumerWidget {
  const ManagerSupportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.colors;
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Help & Support'),
          bottom: TabBar(
            labelColor: palette.primary,
            unselectedLabelColor: palette.textSecondary,
            indicatorColor: palette.primary,
            labelStyle: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 14,
            ),
            tabs: const [
              Tab(text: 'Escalate to Admin'),
              Tab(text: 'Inbox'),
            ],
          ),
        ),
        body: const TabBarView(children: [_EscalateToAdminTab(), _InboxTab()]),
      ),
    );
  }
}

class _EscalateToAdminTab extends ConsumerStatefulWidget {
  const _EscalateToAdminTab();

  @override
  ConsumerState<_EscalateToAdminTab> createState() =>
      _EscalateToAdminTabState();
}

class _EscalateToAdminTabState extends ConsumerState<_EscalateToAdminTab> {
  final _subjectController = TextEditingController();
  final _descriptionController = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _subjectController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_subjectController.text.trim().isEmpty ||
        _descriptionController.text.trim().isEmpty) {
      return;
    }
    final manager = ref.read(currentManagerAccountProvider);
    setState(() => _submitting = true);
    try {
      final ticket = await raiseTicket(
        raisedByRole: AppRole.manager,
        raisedById: manager.id,
        raisedByName: manager.name,
        recipientRole: AppRole.admin,
        subject: _subjectController.text.trim(),
        description: _descriptionController.text.trim(),
      );
      _subjectController.clear();
      _descriptionController.clear();
      if (!mounted) return;
      setState(() => _submitting = false);
      context.push('/manager/ticket/${ticket.id}/chat');
    } catch (e, st) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            friendlyError(e, action: 'Raising ticket', stackTrace: st),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    final manager = ref.watch(currentManagerAccountProvider);
    final myTickets =
        (ref.watch(firestoreTicketsProvider).valueOrNull ?? const [])
            .where(
              (t) =>
                  t.raisedById == manager.id &&
                  t.recipientRole == AppRole.admin,
            )
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          'Escalate to Admin',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 6),
        Text(
          'Raise a ticket for anything your territory needs help with.',
          style: TextStyle(color: palette.textSecondary, fontSize: 12.5),
        ),
        const SizedBox(height: 16),
        AppTextField(
          label: 'Subject',
          controller: _subjectController,
          hint: 'What do you need help with?',
          prefixIcon: Icons.subject_rounded,
          enabled: !_submitting,
        ),
        const SizedBox(height: 14),
        AppTextField(
          label: 'Description',
          controller: _descriptionController,
          hint: 'Add details for the Admin team',
          maxLines: 4,
          prefixIcon: Icons.description_outlined,
          enabled: !_submitting,
        ),
        const SizedBox(height: 14),
        ElevatedButton.icon(
          onPressed: _submitting ? null : _submit,
          icon: _submitting
              ? const SizedBox.shrink()
              : const Icon(Icons.send_rounded),
          label: _submitting
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2.4,
                  ),
                )
              : const Text('Raise ticket'),
        ),
        const SizedBox(height: 28),
        Text('Your tickets', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        if (myTickets.isEmpty)
          const EmptyState(
            icon: Icons.support_agent_outlined,
            title: 'No tickets yet',
            subtitle: 'Tickets you raise will show up here.',
          )
        else
          for (final t in myTickets)
            InkWell(
              onTap: () => context.push('/manager/ticket/${t.id}/chat'),
              borderRadius: BorderRadius.circular(14),
              child: Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: palette.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: palette.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            t.subject,
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: palette.textPrimary,
                            ),
                          ),
                        ),
                        StatusChip(
                          label: t.status.label.toUpperCase(),
                          tone: ticketTone(t.status),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      t.description,
                      style: TextStyle(
                        color: palette.textSecondary,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
      ],
    );
  }
}

/// Tickets raised *to* this Manager by Users/Vendors/Drivers in their
/// territory — the "Assign to me" affordance mirrors Admin's own queue
/// (`support_ticket_queue_screen.dart`).
class _InboxTab extends ConsumerWidget {
  const _InboxTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.colors;
    final manager = ref.watch(currentManagerAccountProvider);
    final inbox =
        (ref.watch(firestoreTicketsProvider).valueOrNull ?? const [])
            .where(
              (t) =>
                  t.recipientRole == AppRole.manager &&
                  t.recipientId == manager.id,
            )
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    if (inbox.isEmpty) {
      return const EmptyState(
        icon: Icons.inbox_outlined,
        title: 'No tickets yet',
        subtitle:
            'Tickets raised by Users, Vendors and Drivers in your territory show up here.',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: inbox.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, i) {
        final ticket = inbox[i];
        return InkWell(
          onTap: () => context.push('/manager/ticket/${ticket.id}/chat'),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: palette.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: palette.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        ticket.subject,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    StatusChip(
                      label: ticket.status.label,
                      tone: ticketTone(ticket.status),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '${ticket.raisedByRole.label} · ${ticket.raisedByName}',
                  style: TextStyle(color: palette.textSecondary, fontSize: 12),
                ),
                if (ticket.orderId != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Order #${ticket.orderId}',
                    style: TextStyle(
                      color: palette.primary,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Text(
                  ticket.description,
                  style: TextStyle(color: palette.textPrimary, fontSize: 13),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (ticket.status == TicketStatus.open) ...[
                  const SizedBox(height: 10),
                  FilledButton.tonal(
                    onPressed: () =>
                        updateTicketStatus(ticket.id, TicketStatus.inProgress),
                    child: const Text('Assign to me'),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
