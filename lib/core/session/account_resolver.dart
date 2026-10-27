import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../data/models/account.dart';
import '../../data/providers/firestore_drivers_provider.dart';
import '../../data/providers/firestore_managers_provider.dart';
import '../../data/providers/firestore_users_provider.dart';
import '../../data/providers/firestore_vendors_provider.dart';

/// Same region every QuickMandi callable deploys to (`REGION` in
/// QuickyAdmin's `functions/index.js`).
const _functionsRegion = 'asia-south1';

FirebaseFunctions get _functions => FirebaseFunctions.instanceFor(region: _functionsRegion);

/// Thrown when the server can't be reached or refuses the sign-in — carries
/// a message that's safe to show as-is.
class AccountResolutionException implements Exception {
  const AccountResolutionException(this.message, {this.isNetwork = false});
  final String message;

  /// True when retrying later may well succeed (offline, server busy) —
  /// session restore keeps the sign-in in that case instead of signing out.
  final bool isNetwork;

  @override
  String toString() => message;
}

/// Which [Account] the currently signed-in, phone-verified Firebase user
/// is — or null if that verified number has no account yet.
///
/// The answer always comes from the `resolveSession` Cloud Function, which
/// reads the number from the verified ID token (never from anything typed
/// here), binds the account to this Firebase uid, and sets the `role`/
/// `accountId` claims Firestore rules check. Forces an ID-token refresh
/// afterwards so those claims apply to every request from here on.
Future<Account?> resolveSignedInAccount() async {
  final data = await _call('resolveSession');
  if (data['status'] != 'found') return null;
  return _loadResolvedAccount(data);
}

/// Creates the signed-in customer's own User account (`registerCustomer`).
/// The server decides the role (always User) and refuses to create a second
/// account for a number that already has one — it returns that existing
/// account instead, flagged [CustomerRegistration.alreadyRegistered].
Future<CustomerRegistration> registerCustomerAccount({required String name, String? email}) async {
  final data = await _call('registerCustomer', {'name': name, 'email': ?email});
  final account = await _loadResolvedAccount(data);
  return CustomerRegistration(account, alreadyRegistered: data['existing'] == true);
}

class CustomerRegistration {
  const CustomerRegistration(this.account, {required this.alreadyRegistered});
  final Account account;
  final bool alreadyRegistered;
}

Future<Map<String, dynamic>> _call(String name, [Map<String, dynamic>? args]) async {
  try {
    final result = await _functions.httpsCallable(name).call<Map<String, dynamic>>(args);
    return Map<String, dynamic>.from(result.data);
  } on FirebaseFunctionsException catch (e) {
    throw AccountResolutionException(
      switch (e.code) {
        'unavailable' || 'deadline-exceeded' || 'internal' =>
          "We couldn't reach the server. Check your connection and try again.",
        _ => e.message ?? 'Sign-in failed. Please try again.',
      },
      isNetwork: const {'unavailable', 'deadline-exceeded', 'internal'}.contains(e.code),
    );
  }
}

Future<Account> _loadResolvedAccount(Map<String, dynamic> data) async {
  final role = AppRole.values.byName(data['role'] as String);
  final accountId = data['accountId'] as String;
  await FirebaseAuth.instance.currentUser?.getIdToken(true);
  final account = await switch (role) {
    AppRole.manager => findFirestoreManagerById(accountId),
    AppRole.vendor => findFirestoreVendorById(accountId),
    AppRole.driver => findFirestoreDriverById(accountId),
    AppRole.user => findFirestoreUserById(accountId),
    AppRole.admin => Future<Account?>.value(),
  };
  if (account == null) {
    throw const AccountResolutionException('Your account could not be loaded. Please try again.');
  }
  // The territory in the server's claims is the one Firestore rules scope
  // this session by — keep the app's queries on the same one.
  return account.copyWith(territoryId: data['territoryId'] as String?);
}
