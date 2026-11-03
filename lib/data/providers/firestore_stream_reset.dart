import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'firestore_addresses_provider.dart';
import 'firestore_branding_provider.dart';
import 'firestore_categories_provider.dart';
import 'firestore_chat_provider.dart';
import 'firestore_coupons_provider.dart';
import 'firestore_drivers_provider.dart';
import 'firestore_global_products_provider.dart';
import 'firestore_list_order_requests_provider.dart';
import 'firestore_managers_provider.dart';
import 'firestore_orders_provider.dart';
import 'firestore_products_provider.dart';
import 'firestore_promotions_provider.dart';
import 'firestore_reviews_provider.dart';
import 'settlement_provider.dart';
import 'firestore_territories_provider.dart';
import 'firestore_ticket_chat_provider.dart';
import 'firestore_tickets_provider.dart';
import 'firestore_users_provider.dart';
import 'firestore_vendors_provider.dart';

/// Every real-time Firestore `StreamProvider` in the app. None of them are
/// `.autoDispose` (each backs a directory/list screen that should keep
/// listening in the background across navigation), which means each one's
/// `.snapshots()` subscription survives for the whole app session — even
/// across a sign-out. `FirebaseAuth.instance.signOut()` revokes the token
/// out from under any still-subscribed listener, Firestore pushes a
/// `PERMISSION_DENIED` through it, and Riverpod caches that as a permanent
/// `AsyncError` on a provider that's never automatically retried. The next
/// role that logs in and happens to watch the same provider (e.g. two
/// sessions in a row both landing on a screen that reads
/// `firestoreVendorsProvider`) would see that stale error, even though a
/// perfectly valid new session now exists — exactly the "permission
/// denied" a user should never see. [SessionController] calls this on
/// every session-boundary transition (`completeLogin`, `completeRegistration`,
/// `logout`) so each stream gets torn down and rebuilt fresh under
/// whatever auth token is actually current the next time it's watched.
///
/// Called through [firestoreStreamResetProvider], never with the session
/// controller's own `ref`: most of these streams depend on the session
/// (via `accessScopeProvider`), and Riverpod refuses — a
/// `CircularDependencyError` in debug builds, which aborted every login —
/// to let a provider invalidate something that depends on it.
final firestoreStreamResetProvider = Provider<void Function()>((ref) => () => resetFirestoreStreams(ref));

void resetFirestoreStreams(Ref ref) {
  // Only rebuild streams that are already running. In Riverpod 2.6,
  // `ref.invalidate` on a provider nobody has read yet *creates* it — so
  // this reset used to open a listener on every collection below (the
  // whole `users`, `vendors`, `drivers`… collections) at each sign-in,
  // which the rules rightly refuse (PERMISSION_DENIED) and which, under
  // the old open rules, downloaded data this session must never see.
  // Families aren't affected (their invalidate only touches live members).
  void reset(ProviderOrFamily provider) {
    if (provider is ProviderBase<Object?> && !ref.exists(provider)) return;
    ref.invalidate(provider);
  }

  reset(firestoreAddressesProvider);
  reset(firestoreManagersProvider);
  reset(firestoreVendorsProvider);
  reset(firestoreDriversProvider);
  reset(driverLocationProvider);
  reset(firestoreTerritoriesProvider);
  reset(firestoreCategoriesProvider);
  reset(globalProductsProvider);
  reset(vendorProductsProvider);
  reset(activeOrdersProvider);
  reset(todaysOrdersProvider);
  reset(orderHistoryProvider);
  reset(driverPositionProvider);
  reset(orderByIdProvider);
  reset(vendorReviewsProvider);
  reset(driverReviewsProvider);
  reset(reviewForOrderProvider);
  reset(firestorePromotionsProvider);
  reset(territoryStatementsProvider);
  reset(myTransfersProvider);
  reset(firestoreCouponsProvider);
  reset(firestoreListOrderRequestsProvider);
  reset(listOrderRequestByIdProvider);
  reset(firestoreUsersProvider);
  reset(orderChatProvider);
  reset(firestoreTicketsProvider);
  reset(ticketByIdProvider);
  reset(ticketChatProvider);
  reset(brandThemeStreamProvider);
}
