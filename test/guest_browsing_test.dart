// Browse first, verify the phone only when it matters (2026-11-17): a guest
// opens the customer app straight from the splash screen; orders, checkout
// and the profile ask for phone verification and then continue there.
import 'package:flutter_test/flutter_test.dart';
import 'package:foodiebell/core/router/session_redirect.dart';
import 'package:foodiebell/core/session/session_controller.dart';
import 'package:foodiebell/data/models/account.dart';

void main() {
  const guest = SessionState();
  String? go(String location, [SessionState s = guest]) => sessionRedirect(Uri.parse(location).path, s, location: location);

  test('a guest browses home, shops, search, cart and help freely', () {
    for (final path in ['/user/home', '/user/cart', '/user/search', '/user/help', '/user/vendor/v1', '/user/vendor/v1/reviews']) {
      expect(go(path), isNull, reason: path);
    }
  });

  test('orders, checkout, list orders and the profile ask to verify first, then continue there', () {
    for (final path in [
      '/user/orders',
      '/user/order/ORD-1',
      '/user/checkout/address',
      '/user/vendor/v1/list-order',
      '/user/profile',
      '/user/addresses',
      '/user/notifications',
      '/user/wallet',
    ]) {
      expect(go(path), '/auth/login?next=${Uri.encodeComponent(path)}', reason: path);
    }
  });

  test('a signed-in customer goes anywhere in the customer app; other roles stay out', () {
    const customer = SessionState(role: AppRole.user, stage: AuthStage.active);
    expect(go('/user/orders', customer), isNull);
    expect(go('/user/profile', customer), isNull);
    const vendor = SessionState(role: AppRole.vendor, stage: AuthStage.active);
    expect(go('/user/home', vendor), '/auth/login');
  });

  test('staff screens still need their own sign-in', () {
    expect(go('/driver/home'), '/auth/login');
    expect(go('/manager/dashboard'), '/auth/login');
  });
}
