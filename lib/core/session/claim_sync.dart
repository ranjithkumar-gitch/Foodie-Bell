import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'account_resolver.dart';
import 'session_controller.dart';

/// When the server last changed the signed-in user's claims — the
/// `sync*Claims` Cloud Functions touch `claimSync/{uid}` whenever an
/// approval, suspension, deletion or territory move changes them.
final _claimSyncProvider = StreamProvider<DateTime?>((ref) {
  final signedIn = ref.watch(sessionControllerProvider.select((s) => s.account != null));
  final user = FirebaseAuth.instance.currentUser;
  if (!signedIn || user == null) return Stream.value(null);
  return FirebaseFirestore.instance
      .doc('claimSync/${user.uid}')
      .snapshots()
      .map((doc) => (doc.data()?['updatedAt'] as Timestamp?)?.toDate());
});

/// Keeps a running session in step with server-side changes to its
/// account: on a claims change it re-resolves the account (which also
/// refreshes the ID token, so the very next Firestore request carries the
/// new role/territory/active claims) and swaps it into the session. A
/// revoked or deleted sign-in is signed out. Called from `QuickyApp.build`,
/// like `fcm_topics.dart`'s `listenFor...` helpers.
void listenForClaimChanges(WidgetRef ref) {
  ref.listen<AsyncValue<DateTime?>>(_claimSyncProvider, (previous, next) async {
    final before = previous?.valueOrNull;
    final after = next.valueOrNull;
    // The first snapshot is just the baseline; a session's claims are
    // already fresh when it starts (login and restore both resolve them).
    if (before == null || after == null || !after.isAfter(before)) return;
    final session = ref.read(sessionControllerProvider.notifier);
    try {
      final account = await resolveSignedInAccount();
      if (account == null) {
        await FirebaseAuth.instance.signOut();
        session.logout();
      } else if (account.role == ref.read(sessionControllerProvider).role) {
        session.refreshAccount(account);
      } else {
        session
          ..selectRole(account.role)
          ..completeLogin(account: account);
      }
    } on FirebaseAuthException catch (e) {
      // Refresh tokens revoked (account suspended/deleted) or user gone.
      debugPrint('claim_sync: sign-in no longer valid (${e.code})');
      await FirebaseAuth.instance.signOut();
      session.logout();
    } catch (e) {
      // Offline or server busy — the next change, or the next launch's
      // session restore, picks it up.
      debugPrint('claim_sync: refresh failed: $e');
    }
  });
}
