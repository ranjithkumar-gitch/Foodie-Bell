import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/session/session_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/providers/firestore_drivers_provider.dart';
import '../../../data/providers/mock_accounts_provider.dart';
import '../../../shared/widgets/driver_document_checklist.dart';

/// Driver's own "My Documents" screen — thin wrapper around
/// [DriverDocumentChecklist], mirrors `vendor_documents_status_screen.dart`.
///
/// Looks the signed-in driver's live record up across both stores (same
/// merge `manager_driver_detail_screen.dart` uses) rather than trusting the
/// session's `Account` snapshot as-is, since that snapshot was captured at
/// login and won't reflect a Manager toggling required/not-required after.
class DriverDocumentsStatusScreen extends ConsumerWidget {
  const DriverDocumentsStatusScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.colors;
    final sessionAccount = ref.watch(sessionControllerProvider.select((s) => s.account));
    final mockAccounts = ref.watch(mockAccountsProvider);
    final firestoreDrivers = ref.watch(firestoreDriversProvider).valueOrNull ?? const [];

    if (sessionAccount == null) {
      return Scaffold(appBar: AppBar(title: const Text('My Documents')), body: const Center(child: Text('Not signed in.')));
    }
    final isFirestoreBacked = firestoreDrivers.any((d) => d.id == sessionAccount.id);
    final account = mergeDriverAccounts(mockAccounts, firestoreDrivers).where((a) => a.id == sessionAccount.id).firstOrNull ?? sessionAccount;

    return Scaffold(
      appBar: AppBar(title: const Text('My Documents')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Give your risk consent and submit whatever your Manager has marked as required below. Once everything required is in, your account is ready to be activated.',
            style: TextStyle(color: palette.textSecondary),
          ),
          const SizedBox(height: 16),
          DriverDocumentChecklist(account: account, isFirestoreBacked: isFirestoreBacked),
        ],
      ),
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
