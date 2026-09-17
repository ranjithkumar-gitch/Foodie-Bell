import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/session/session_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/providers/firestore_vendors_provider.dart';
import '../../../data/providers/mock_accounts_provider.dart';
import '../../../shared/widgets/vendor_document_checklist.dart';

/// Vendor's own "My Documents" screen — thin wrapper around
/// [VendorDocumentChecklist] (shared with the "Account under review" screen
/// a still-pending Vendor sees instead, since they can't reach this route
/// yet — see that widget's doc comment).
///
/// Looks the signed-in vendor's live record up across both stores (same
/// merge `manager_vendor_detail_screen.dart` uses) rather than trusting the
/// session's `Account` snapshot as-is, since that snapshot was captured at
/// login and won't reflect a Manager toggling required/not-required after.
class VendorDocumentsStatusScreen extends ConsumerWidget {
  const VendorDocumentsStatusScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.colors;
    final sessionAccount = ref.watch(sessionControllerProvider.select((s) => s.account));
    final mockAccounts = ref.watch(mockAccountsProvider);
    final firestoreVendors = ref.watch(firestoreVendorsProvider).valueOrNull ?? const [];

    if (sessionAccount == null) {
      return Scaffold(appBar: AppBar(title: const Text('My Documents')), body: const Center(child: Text('Not signed in.')));
    }
    final isFirestoreBacked = firestoreVendors.any((v) => v.id == sessionAccount.id);
    final account = mergeVendorAccounts(mockAccounts, firestoreVendors).where((a) => a.id == sessionAccount.id).firstOrNull ?? sessionAccount;

    return Scaffold(
      appBar: AppBar(title: const Text('My Documents')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Submit whatever your Manager has marked as required below. Once everything required is in, your account is ready to be activated.',
            style: TextStyle(color: palette.textSecondary),
          ),
          const SizedBox(height: 16),
          VendorDocumentChecklist(account: account, isFirestoreBacked: isFirestoreBacked),
        ],
      ),
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
