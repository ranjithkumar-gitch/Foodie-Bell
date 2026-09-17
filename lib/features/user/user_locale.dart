import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/session/session_controller.dart';
import '../../data/providers/firestore_users_provider.dart';

/// The User module's active locale — derived from the signed-in User's own
/// [Account.languageCode] preference (`profile_screen.dart`'s language
/// switcher), defaulting to English. `app.dart`'s single `MaterialApp` reads
/// this for the whole app's `locale`, but since [Account.languageCode] is
/// only ever set from a User-role session (nothing in Vendor/Admin/Manager/
/// Driver ever writes it, and none of those screens' strings go through
/// `AppLocalizations` in the first place), signing in as any other role
/// always resolves back to English here — Telugu only ever shows up for a
/// User who chose it.
final userLocaleProvider = Provider<Locale>((ref) {
  final code = ref.watch(sessionControllerProvider.select((s) => s.account?.languageCode));
  return code == 'te' ? const Locale('te') : const Locale('en');
});

/// Persists the chosen language for the signed-in User and refreshes the
/// session immediately — every User session is a real Firestore-backed
/// account (login only ever resolves one, see `auth_navigation.dart`'s
/// `resolveAccountAcrossRoles`), so this always writes to their own doc.
Future<void> setUserAppLanguage(WidgetRef ref, String languageCode) async {
  final account = ref.read(sessionControllerProvider).account;
  if (account == null) return;
  await setUserLanguage(account.id, languageCode);
  ref.read(sessionControllerProvider.notifier).refreshAccount(account.copyWith(languageCode: languageCode));
}
