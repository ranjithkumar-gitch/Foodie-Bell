import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/account.dart';
import '../../../data/models/ticket.dart';
import '../../../data/providers/firestore_managers_provider.dart';
import '../../../data/providers/firestore_tickets_provider.dart';
import '../../../shared/error_reporting.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/status_chip.dart';
import '../driver_session.dart';

/// Help & Support / Report an Issue (spec §6 item 18) — a ticket form that
/// raises a real, Firestore-backed [SupportTicket]
/// (`firestore_tickets_provider.dart`) addressed to this Driver's Territory
/// Manager — resolved by matching this Driver's [Account.managerCode]
/// against a Manager's own, same "golden rule" linkage as Vendor. Once
/// raised, it opens straight into a live 1:1 chat with that Manager
/// (`driver_ticket_chat_screen.dart`).
class DriverSupportScreen extends ConsumerStatefulWidget {
  const DriverSupportScreen({super.key});

  @override
  ConsumerState<DriverSupportScreen> createState() => _DriverSupportScreenState();
}

class _DriverSupportScreenState extends ConsumerState<DriverSupportScreen> {
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
    if (_subjectController.text.trim().isEmpty || _descriptionController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Add a subject and description before submitting.')));
      return;
    }
    final driver = ref.read(currentDriverAccountProvider);
    final managers = ref.read(firestoreManagersProvider).valueOrNull ?? const [];
    final manager = managers.where((m) => m.managerCode == driver.managerCode).firstOrNull;
    if (manager == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No manager is available for your account yet. Please try again later.')));
      return;
    }

    setState(() => _submitting = true);
    try {
      final ticket = await raiseTicket(
        raisedByRole: AppRole.driver,
        raisedById: driver.id,
        raisedByName: driver.name,
        recipientRole: AppRole.manager,
        recipientId: manager.id,
        subject: _subjectController.text.trim(),
        description: _descriptionController.text.trim(),
      );
      _subjectController.clear();
      _descriptionController.clear();
      if (!mounted) return;
      setState(() => _submitting = false);
      context.push('/driver/ticket/${ticket.id}/chat');
    } catch (e, st) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyError(e, action: 'Raising ticket', stackTrace: st))),
      );
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
    final driver = ref.watch(currentDriverAccountProvider);
    final myTickets =
        (ref.watch(firestoreTicketsProvider).valueOrNull ?? const [])
            .where((t) => t.raisedById == driver.id)
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return Scaffold(
      appBar: AppBar(title: const Text('Help & Support')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: [
          Text('Raise a ticket', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 4),
          Text('Tell us what went wrong — your Territory Manager will get back to you.', style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 16),
          AppTextField(label: 'Subject', controller: _subjectController, hint: 'e.g. Payout mismatch', prefixIcon: Icons.subject_rounded, enabled: !_submitting),
          const SizedBox(height: 16),
          AppTextField(
            label: 'Description',
            controller: _descriptionController,
            hint: 'Describe the issue in detail',
            maxLines: 4,
            prefixIcon: Icons.description_outlined,
            enabled: !_submitting,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _submitting ? null : _submit,
            child: _submitting
                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.4))
                : const Text('Submit ticket'),
          ),
          const SizedBox(height: 28),
          if (myTickets.isNotEmpty) ...[
            Text('Your tickets', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 12),
            for (final ticket in myTickets)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: InkWell(
                  onTap: () => context.push('/driver/ticket/${ticket.id}/chat'),
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: palette.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: palette.border)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(child: Text(ticket.subject, style: TextStyle(fontWeight: FontWeight.w800, color: palette.textPrimary))),
                            StatusChip(label: ticket.status.label, tone: _tone(ticket.status)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(ticket.description, style: TextStyle(color: palette.textSecondary, fontSize: 12.5)),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
