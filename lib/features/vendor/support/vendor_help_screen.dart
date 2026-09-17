import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/session/session_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/account.dart';
import '../../../data/models/ticket.dart';
import '../../../data/providers/firestore_managers_provider.dart';
import '../../../data/providers/firestore_tickets_provider.dart';
import '../../../shared/error_reporting.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/status_chip.dart';

/// Help & Support (spec §5.20) — a ticket form that raises a real,
/// Firestore-backed [SupportTicket] (`firestore_tickets_provider.dart`)
/// addressed to this Vendor's Territory Manager — resolved by matching this
/// Vendor's [Account.managerCode] against a Manager's own (the app's
/// existing "golden rule" linkage). Once raised, it opens straight into a
/// live 1:1 chat with that Manager (`vendor_ticket_chat_screen.dart`).
class VendorHelpScreen extends ConsumerStatefulWidget {
  const VendorHelpScreen({super.key});

  @override
  ConsumerState<VendorHelpScreen> createState() => _VendorHelpScreenState();
}

class _VendorHelpScreenState extends ConsumerState<VendorHelpScreen> {
  final _subjectController = TextEditingController();
  final _descriptionController = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _subjectController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final subject = _subjectController.text.trim();
    final description = _descriptionController.text.trim();
    if (subject.isEmpty || description.isEmpty) {
      setState(() => _error = 'Please fill in both a subject and description.');
      return;
    }
    final account = ref.read(sessionControllerProvider).account;
    if (account == null) return;

    final managers = ref.read(firestoreManagersProvider).valueOrNull ?? const [];
    final manager = managers.where((m) => m.managerCode == account.managerCode).firstOrNull;
    if (manager == null) {
      setState(() => _error = "No manager is available for your account yet. Please try again later.");
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final ticket = await raiseTicket(
        raisedByRole: AppRole.vendor,
        raisedById: account.id,
        raisedByName: account.name,
        recipientRole: AppRole.manager,
        recipientId: manager.id,
        subject: subject,
        description: description,
      );
      _subjectController.clear();
      _descriptionController.clear();
      if (!mounted) return;
      setState(() => _submitting = false);
      context.push('/vendor/ticket/${ticket.id}/chat');
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
    final account = ref.watch(sessionControllerProvider.select((s) => s.account));
    final myTickets =
        (ref.watch(firestoreTicketsProvider).valueOrNull ?? const [])
            .where((t) => t.raisedById == account?.id)
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return Scaffold(
      appBar: AppBar(title: const Text('Help & Support')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('Raise a ticket', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 14),
          AppTextField(label: 'Subject', controller: _subjectController, hint: 'e.g. Payment not settled', enabled: !_submitting),
          const SizedBox(height: 16),
          AppTextField(label: 'Description', controller: _descriptionController, hint: 'Describe the issue in detail', maxLines: 4, enabled: !_submitting),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: TextStyle(color: palette.error, fontWeight: FontWeight.w600, fontSize: 12.5)),
          ],
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _submitting ? null : _submit,
            child: _submitting
                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.4))
                : const Text('Submit ticket'),
          ),
          const SizedBox(height: 28),
          Text('Your tickets', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          if (myTickets.isEmpty)
            Text('No tickets raised yet.', style: TextStyle(color: palette.textMuted))
          else
            for (final ticket in myTickets)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: InkWell(
                  onTap: () => context.push('/vendor/ticket/${ticket.id}/chat'),
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: palette.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: palette.border)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(child: Text(ticket.subject, style: TextStyle(fontWeight: FontWeight.w700, color: palette.textPrimary))),
                            StatusChip(label: ticket.status.label, tone: _tone(ticket.status)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(ticket.description, style: TextStyle(fontSize: 12.5, color: palette.textSecondary)),
                      ],
                    ),
                  ),
                ),
              ),
        ],
      ),
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
