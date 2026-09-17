import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/session/session_controller.dart';
import '../../data/models/account.dart';

/// A blank placeholder — no name/territory a real Manager could ever have —
/// for the moment a Manager-role screen renders outside a real session (the
/// router guards every `/manager/...` route on one in practice, but a screen
/// can still exist for one more frame while `logout()` clears the session
/// and the router redirect catches up). Deliberately not a named demo
/// identity — see `driver_session.dart`'s `_blankDriverAccount` doc comment
/// for why a real-looking fallback would flash the wrong data for that one
/// frame, most visibly right after logging out.
const _blankManagerAccount = Account(id: '', role: AppRole.manager, name: '', phone: '');

/// The signed-in manager's real account (`Account` from
/// `sessionControllerProvider`) — screens that need "which territory am I
/// managing" (Dashboard, Order Oversight, Daily Settlement, Territory
/// Earnings) should key off this real, Admin-assigned `territory` rather
/// than the old hardcoded `ManagerConstants.managerId`, so a real Manager
/// Admin created sees their own territory's vendors/orders instead of a
/// stale placeholder's.
final currentManagerAccountProvider = Provider<Account>((ref) {
  final account = ref.watch(sessionControllerProvider.select((s) => s.account));
  return account?.role == AppRole.manager ? account! : _blankManagerAccount;
});
