import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/session/session_controller.dart';
import '../../data/models/account.dart';

/// A blank placeholder — no name/phone/id a real Driver could ever have —
/// for the moment a Driver-role screen renders outside a real session (the
/// router guards every `/driver/...` route on one in practice, but a screen
/// can still exist for one more frame while `logout()` clears the session
/// and the router redirect catches up). Deliberately *not* a named demo
/// identity (`MockAccounts.demoDriver`, "Ravi Kumar") — that used to flash
/// someone else's real-looking data for that one frame, most visibly right
/// after logging out.
const _blankDriverAccount = Account(id: '', role: AppRole.driver, name: '', phone: '');

/// The signed-in driver's real account (`Account` from `sessionControllerProvider`)
/// — every Driver-role screen should key its identity (home, incoming
/// offers, history, earnings) off this, so a real driver a Manager approved
/// sees their own orders instead of ever seeing another identity's data.
final currentDriverAccountProvider = Provider<Account>((ref) {
  final account = ref.watch(sessionControllerProvider.select((s) => s.account));
  return account?.role == AppRole.driver ? account! : _blankDriverAccount;
});
