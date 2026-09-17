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
import 'firestore_settlement_reconciliation_provider.dart';
import 'firestore_tax_categories_provider.dart';
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
void resetFirestoreStreams(Ref ref) {
  ref.invalidate(firestoreAddressesProvider);
  ref.invalidate(firestoreManagersProvider);
  ref.invalidate(firestoreVendorsProvider);
  ref.invalidate(firestoreDriversProvider);
  ref.invalidate(firestoreTerritoriesProvider);
  ref.invalidate(firestoreCategoriesProvider);
  ref.invalidate(globalProductsProvider);
  ref.invalidate(vendorProductsProvider);
  ref.invalidate(firestoreOrdersProvider);
  ref.invalidate(orderByIdProvider);
  ref.invalidate(firestoreReviewsProvider);
  ref.invalidate(firestorePromotionsProvider);
  ref.invalidate(firestoreReconciledSettlementsProvider);
  ref.invalidate(firestoreCouponsProvider);
  ref.invalidate(firestoreListOrderRequestsProvider);
  ref.invalidate(listOrderRequestByIdProvider);
  ref.invalidate(firestoreUsersProvider);
  ref.invalidate(firestoreTaxCategoriesProvider);
  ref.invalidate(orderChatProvider);
  ref.invalidate(firestoreTicketsProvider);
  ref.invalidate(ticketByIdProvider);
  ref.invalidate(ticketChatProvider);
  ref.invalidate(brandThemeStreamProvider);
}
