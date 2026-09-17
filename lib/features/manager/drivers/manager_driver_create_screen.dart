import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FilteringTextInputFormatter;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/session/session_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/account.dart';
import '../../../data/providers/firestore_drivers_provider.dart';
import '../../../data/providers/mock_accounts_provider.dart';
import '../../../shared/error_reporting.dart';
import '../../../shared/widgets/app_text_field.dart';

/// Manager's "Add Driver" form — mirrors `manager_vendor_create_screen.dart`
/// exactly, minus the vendor-only fields (category/subcategory/owner/rebate).
/// The record is written as `pendingReview`, since Driver no longer
/// self-registers at all — Driver signs in by phone/OTP through the
/// unified login screen like every other role (`auth_login_screen.dart`).
/// Territory and Manager Code aren't picked —
/// they're always the signed-in Manager's own, same "golden rule" as
/// Vendor: a Driver belongs to exactly the territory of the Manager who
/// onboarded them.
///
/// No Firebase Auth user is created here — see
/// `firestore_vendors_provider.dart`'s doc comment for why (Driver
/// authenticates by phone+OTP, which can't be provisioned client-side).
class ManagerDriverCreateScreen extends ConsumerStatefulWidget {
  const ManagerDriverCreateScreen({super.key});

  @override
  ConsumerState<ManagerDriverCreateScreen> createState() =>
      _ManagerDriverCreateScreenState();
}

class _ManagerDriverCreateScreenState
    extends ConsumerState<ManagerDriverCreateScreen> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  String? _error;
  bool _creating = false;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _create(Account manager) async {
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();
    final email = _emailController.text.trim();

    if (name.isEmpty || phone.length != 10) {
      setState(
        () =>
            _error = 'Please fill in a full name and a 10-digit mobile number.',
      );
      return;
    }
    setState(() {
      _error = null;
      _creating = true;
    });

    final draft = Account(
      id: '',
      role: AppRole.driver,
      name: name,
      phone: phone,
      email: email.isEmpty ? null : email,
      managerCode: manager.managerCode,
      territory: manager.territory,
      status: AccountStatus.pendingReview,
    );

    final String docId;
    try {
      final docRef = await driversCollection.add({
        ...accountToDriverDoc(draft),
        'createdAt': FieldValue.serverTimestamp(),
      });
      docId = docRef.id;
    } catch (e, st) {
      if (!mounted) return;
      setState(() {
        _creating = false;
        _error = friendlyError(e, action: 'Saving the driver', stackTrace: st);
      });
      return;
    }

    // Mirrored for immediate same-session lookup (e.g. this Manager's own
    // Driver Management list) — see manager_vendor_create_screen.dart for
    // the same real-Firestore/session-mirror split.
    final account = Account(
      id: docId,
      role: AppRole.driver,
      name: name,
      phone: phone,
      email: email.isEmpty ? null : email,
      managerCode: manager.managerCode,
      territory: manager.territory,
      status: AccountStatus.pendingReview,
    );
    ref.read(mockAccountsProvider.notifier).addAccount(account);

    if (!mounted) return;
    setState(() => _creating = false);
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Driver added — pending review'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$name can sign in now, but stays pending in ${manager.territory ?? 'your territory'} until documents and consent are submitted and reviewed.',
            ),
            const SizedBox(height: 12),
            Text(
              'Manager Code: ${manager.managerCode ?? '—'}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            const Text(
              'They can sign in at the Driver role selector using this mobile number via OTP. Find them under Pending once they submit documents.',
              style: TextStyle(fontSize: 12.5),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              context.pop();
            },
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    final manager = ref.watch(
      sessionControllerProvider.select((s) => s.account),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Add Driver')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        children: [
          Icon(Icons.two_wheeler_rounded, size: 40, color: palette.primary),
          const SizedBox(height: 14),
          Text(
            'Onboard a new driver',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 6),
          Text(
            'They can sign in right away with this mobile number, but stay pending until they submit required documents, give risk consent, and you approve them.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: palette.surfaceMuted,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Icon(Icons.map_rounded, color: palette.primary, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '${manager?.territory ?? 'Your territory'} · ${manager?.managerCode ?? '—'}',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: palette.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          AppTextField(
            label: 'Full name',
            controller: _nameController,
            hint: 'e.g. Ravi Kumar',
            prefixIcon: Icons.person_outline_rounded,
            enabled: !_creating,
          ),
          const SizedBox(height: 16),
          AppTextField(
            label: 'Mobile number',
            controller: _phoneController,
            hint: '10-digit mobile number',
            keyboardType: TextInputType.phone,
            prefixIcon: Icons.call_outlined,
            enabled: !_creating,
            maxLength: 10,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          ),
          const SizedBox(height: 16),
          AppTextField(
            label: 'Email (optional)',
            controller: _emailController,
            hint: 'driver@example.com',
            keyboardType: TextInputType.emailAddress,
            prefixIcon: Icons.mail_outline_rounded,
            enabled: !_creating,
          ),
          if (_error != null) ...[
            const SizedBox(height: 14),
            Text(
              _error!,
              style: TextStyle(
                color: palette.error,
                fontWeight: FontWeight.w600,
                fontSize: 12.5,
              ),
            ),
          ],
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
          child: ElevatedButton(
            onPressed: _creating || manager == null
                ? null
                : () => _create(manager),
            child: _creating
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.4,
                    ),
                  )
                : const Text('Add driver'),
          ),
        ),
      ),
    );
  }
}
