# QuickMandi auth & data audit

Date: 2026-10-26 · Firebase project `quickmandi-3b017`
Repos: `Foodie-Bell` @ `9161660` (+ uncommitted work) · `QuickyAdmin` @ `5a7b868`

**Not inspected:** the *deployed* rules and the *live* Firestore/Auth data. Everything below is from source. Section 10 says what is still needed to enumerate live beta records.

---

## 0. Findings that constrain any rules rewrite

1. **Firebase Auth identity is never bound to an account (User / Vendor / Driver / Manager).** Login takes a phone number plus the fixed OTP `123456` (`kUseDynamicOtp = false`, `lib/shared/auth/otp_config.dart`). The app then calls `signInAnonymously()` and looks the phone up in Firestore. The anonymous UID is new on every sign-in and is stored nowhere. So no rule can check `request.auth.uid` against an owner field today; the only check available is "signed in". **Anyone who knows a registered phone number can sign in as that account.**
2. **Session restore trusts a phone number in SharedPreferences** (`session_phone`, `core/session/session_cache.dart`), with no re-verification.
3. **Managers** have a real email/password Firebase user. Its doc ID is the UID, and every manager is created with the default password `123456`. But managers sign into Foodie-Bell by phone + demo OTP, so their on-device UID ≠ their doc ID.
4. **Admin** signs in with email/password. "Is admin" is a client-side email comparison (`admin@qm.com`). Cloud Functions accept `token.admin === true` **or** that email. No custom claims are set anywhere. The admin's account record in code is the mock `adm1`.
5. **Firestore rules** (identical in both repos) allow every listed collection to be read and written by any signed-in user, **including anonymous** users. `app_config` is public-read. **`adRevenue`, `managerPayouts` and `settlements` have no match block**, so they are denied by default. If those rules were live, QuickyAdmin's Reports/Transactions would fail, which suggests the live rules differ from both repos. **Confirm the live rules before changing anything.**
6. **Storage rules differ between the repos, and whichever was deployed last is live.**
   - Foodie-Bell: per-path, auth required, and **no `occasion_themes/` path**, so admin theme uploads fail if this one is live.
   - QuickyAdmin: **every object is public-read**; any signed-in user can write. Its comment implies this is the deployed version.
7. **KYC exposure doesn't depend on Storage rules.** KYC images are reached through token download URLs stored in `vendors.documentUrls` and `drivers.documentUrls`. Every role streams the entire `vendors` and `drivers` collections, so every signed-in (anonymous) client receives every vendor's and driver's KYC URLs.
8. **Whole-collection queries.** Many providers stream entire collections and filter on the device: orders, users, vendors, drivers, managers, reviews, tickets, list_order_requests, promotions, coupons, all products, settlement_reconciliations. Rules are not filters, so per-owner read rules will make these listeners fail. **The queries have to be scoped first.**
9. **Payment and state integrity are client-trusted.** The order's `paymentId` is written by the client and the Razorpay signature is never checked server-side, so "paid" just means `paymentId != null`. The driver writes `codPaymentReceived`. Order status, list-order quote/paid, promotion approval, account approval and KYC verdicts are all plain client updates.
10. **FCM is topic-only** and stores no device tokens. Anyone can subscribe to any topic, so the order notifications for `account_<id>` and `drivers_<territory>` can be received by anyone who knows the ID or territory name.

---

## 1. Login, registration, logout and session restore

### Foodie-Bell (User / Vendor / Driver / Manager)

| Flow | Path | What happens |
|---|---|---|
| Unified login | `auth_login_screen` → `auth_otp_screen` → `completePhoneAuth` (`shared/auth/auth_navigation.dart`) | Anonymous sign-in if there's no `currentUser`. `resolveAccountAcrossRoles(phone)` checks managers → vendors → drivers → users, first match wins. No match → `signOut()` and "no account found". `SessionController.completeLogin` maps `status`/`deletedAt` to a stage: `pendingReview` → under review, `rejected` → rejected, `suspended` or deleted → blocked, else active. |
| Real phone OTP (dormant) | `auth_login_screen:115`, `auth_phone_screen:98`, `auth_otp_screen:92/151` | `verifyPhoneNumber` + `signInWithCredential`. Only active when `kUseDynamicOtp = true`. |
| User registration | `auth_phone_screen` (stages phone in `userRegistrationDraftProvider`) → OTP → `auth_terms_screen._submit` | `users.add({...})` with a random doc ID → `completeRegistration` (active). No UID stored. |
| Vendor/Driver self-registration | `features/driver/registration/*`, "Become a Vendor/Driver" | **Not wired to Firestore.** `completeRegistration()` without an account is a no-op. |
| Vendor/Driver creation by Manager | `manager_vendor_create_screen:119`, `manager_driver_create_screen:82` | `vendors.add` / `drivers.add` with `status: pendingReview`. No Firebase Auth user. The person then logs in by phone. |
| Manager creation by Admin | QuickyAdmin `manager_create_screen:75–150` | Secondary `FirebaseApp` → `createUserWithEmailAndPassword(email, '123456')` → `managers/{uid}.set` → `assignTerritory`. |
| Under-review wait | `auth_under_review_screen` | Listens to the live account doc → `refreshAccount` → the router redirects. `setStage` can also simulate approval. |
| Logout | `logout_confirmation_sheet:26` → `SessionController.logout` | `FirebaseAuth.signOut()`, reset Firestore streams, clear local cart and selected address, clear the cached phone. The account FCM topic is unsubscribed through its listener. |
| Session restore | `features/user/splash/splash_screen._route` | Uses `currentUser.phoneNumber`/`email` (blank for anonymous), else the cached phone → `resolveAccountAcrossRoles` → `completeLogin`. No match → `signOut()`, clear cache → `/auth/login`. |

### QuickyAdmin (Admin)

| Flow | Path | What happens |
|---|---|---|
| Login | `shared/auth/admin_login_screen:50–76` | `signInWithEmailAndPassword` → client check `email == admin@qm.com`, otherwise `signOut()` → `login(MockAccounts.demoAdmin)` |
| Restore | `core/session/admin_session_controller` | Checks `currentUser` email at startup, then follows `authStateChanges()` |
| Logout | `shared/auth/logout_confirmation_sheet:26` | `signOut()` + `logout()` |

## 2. Firebase Auth providers

| Provider | Used by | Notes |
|---|---|---|
| Anonymous | Every Foodie-Bell login while `kUseDynamicOtp = false` | A new anonymous user per sign-in; old ones are orphaned and pile up. |
| Phone | Code present, switched off by the flag | Needs APNs, Play Integrity and test numbers before it can be enabled. |
| Email/password | Admin (`admin@qm.com`); every Manager (created with password `123456`) | Managers don't use it for Foodie-Bell login. The email lookup survives only for restoring old sessions (`findFirestoreManagerByEmail`). |
| Custom claims | None | `functions/index.js` already accepts a future `admin: true` claim. |

## 3. Account documents and identity mapping

| Role | Collection | Doc ID | Created by | Linked to Auth? | Login key |
|---|---|---|---|---|---|
| User | `users` | random (`add`) | the User (`auth_terms_screen`) | no | `phone` |
| Vendor | `vendors` | random | Manager (Foodie-Bell) | no | `phone` |
| Driver | `drivers` | random | Manager (Foodie-Bell) | no | `phone` |
| Manager | `managers` | email/password UID | Admin (QuickyAdmin) | the UID exists, but Foodie-Bell login doesn't use it | `phone` (`email` for old sessions) |
| Admin | — | mock `adm1` in code | — | email `admin@qm.com` | email |

- Phone numbers aren't unique across or within collections. If the same number is in two roles, login always resolves to the earlier one in the managers → vendors → drivers → users order.
- Territory links use the **display name**, not an ID: `vendors.territory`, `drivers.territory` and `managers.territory` are all names, and `onOrderStatusChange` joins on them. `territories/{id}` and `topics/{territoryId}` use IDs.
- Authorization-relevant fields on account docs: `status`, `deletedAt`, `rejectionReason`, `managerCode`, `territory`, `documentStatuses.*`, `documentUrls.*`, `isOnline`, location fields, `upiIds`, bank details (managers), `territoryFee`/`territoryFeePaidAt` (managers).

## 4. Firestore operations by collection

R = read, W = write. FB = Foodie-Bell, QA = QuickyAdmin. "all" means an unfiltered whole-collection stream.

| Collection | Reads | Writes (who) | Transactions / batches |
|---|---|---|---|
| `users` | FB+QA stream all; `where phone ==` | `add` (User registration); `updateUserProfile`, `setUserLanguage` (User) | — |
| `vendors` | FB+QA stream all; `where phone ==` | `add` (Manager); `updateVendorStatus` (Manager, QA Admin); `softDeleteVendor` (QA Admin); `setVendorOpen`, `setVendorUpiIds`, `updateVendorProfile` (Vendor); `documentUrls.*` (Vendor via checklist); `documentStatuses.*` (Vendor submit, Manager verdict) | — |
| `drivers` | FB+QA stream all `orderBy createdAt`; doc stream (live location); `where phone ==` | `add` (Manager); `updateDriverStatus` (Manager, QA Admin); `setDriverOnlineStatus`, `updateDriverLocation` (Driver); `submitDriverDocuments`, `clearDriverDocumentUrl` (Driver via checklist); `updateDriverDocumentStatus` (Manager) | — |
| `managers` | FB+QA stream all `orderBy createdAt`; `where phone/email ==` | `set` with doc ID = UID (QA create); status, `territoryFee`, `territoryFeePaidAt`, soft delete (QA Admin); `updateManagerAvatar`, `updateManagerBankDetails` (Manager) | — |
| `territories` | stream all `orderBy createdAt` | QA `createTerritory`, `setTerritoryActive`, `softDeleteTerritory`, `assignTerritory`; FB Manager `setTerritoryDisabledCategories` | QA batch: territory + `topics` doc |
| `topics` | QA stream (notification picker) | QA (in the `createTerritory` batch) | batch |
| `categories` | stream `orderBy sortOrder` | **seed-if-empty on first read, by any client in either app**; QA add/update/delete/activate/reorder | batch seed, batch reorder |
| `products` | `where vendorId ==` (vendor catalogue, storefront); **stream all** (User home/search) | Vendor add/update/remove/stock; `copyGlobalProducts`; QA seeds mock vendors `ven1`/`ven2` on first read; QA tax backfill | batches |
| `global_products` | stream all | QA CRUD; QA import (reads all `products`) | batch |
| `tax_categories` | stream | seed-if-empty (either app); QA update; QA backfill (updates `products` + `global_products`) | batches |
| `orders` | **stream all** (every role filters on device); doc stream | User `createOrder`; User `createOrderWithCoupon`; Vendor status → `vendorAccepted`/`rejected`; Driver → `driverAssigned` (self-assigns `driverId`/name/phone), `pickedUp`, `delivered`; Driver `markCodPaymentReceived`; **Vendor creates the order** in `acceptListOrderRequestAndCreateOrder`; QA read-only. `cancelOrder` is unused. | Transaction: coupon redemption + order. Batch: list-order accept + order |
| `couponRedemptions` | `get` doc `${couponId}_${userId}` | `set` inside the order transaction (User) | transaction |
| `coupons` | stream all | Vendor `createCoupon` | — |
| `promotions` | stream all | Vendor `requestPromotion`; Manager approve/reject/mark paid; QA create/delete/end/reactivate; **QA client sweep on every stream read**; scheduled function sweep | batch (client sweep) |
| `list_order_requests` | **stream all**; doc stream | User submit (`set`)/`markPaid`/`cancel`; Vendor quote/decline/accept | batch (accept + create order) |
| `chat_messages` | `where orderId ==` | `add` (User, Driver) | — |
| `tickets` | **stream all**; doc stream | `raiseTicket` (all four roles); `updateTicketStatus` (Manager, QA Admin) | — |
| `ticket_messages` | `where ticketId ==` | `add` (all roles; Admin posts as `adm1`) | — |
| `reviews` | **stream all** | User `submitReview` (`set` with ID) | — |
| `addresses` | `where userId ==`; doc | User add (`set`)/delete | — |
| `carts` | doc ID = userId | User get/set/delete | — |
| `recent_searches` | doc ID = userId | User get/set/delete | — |
| `settlement_reconciliations` | stream all (doc IDs) | Manager set/delete `${vendorId}_${date}` | — |
| `personal_notifications` | `where recipientId == accountId orderBy createdAt` | **Function only** creates; any role deletes | — |
| `notification_broadcasts` | FB `where topic in [...] orderBy sentAt`; QA stream all | **Function only** creates; QA Admin deletes | — |
| `app_config/current_theme` | public; FB stream (splash + branding) | **QA client `set`** (`activateOccasion`). The admin callables exist but aren't called. | — |
| `occasions` | QA stream | QA save/delete | — |
| `adRevenue` | QA stream | QA add/delete | — **no rule** |
| `managerPayouts` | QA stream | QA create request/approve/settle/reject (Admin acts on the Manager's behalf) | — **no rule** |
| `settlements` | QA stream | QA `recordSettlement` | — **no rule** |

## 5. Cloud Functions (`QuickyAdmin/functions/index.js`, Node 20)

| Function | Trigger | Region | Authorization | Data touched |
|---|---|---|---|---|
| `sweepExpiredPromotions` | schedule, 00:00 IST | default (us-central1) | scheduler | `promotions where status == active` → `ended` |
| `activateOccasionTheme` | callable | asia-south1 | `assertAdmin` | reads `occasions/{id}`, sets `app_config/current_theme`. **Not called by the client.** |
| `resetOccasionTheme` | callable | asia-south1 | `assertAdmin` | sets `app_config/current_theme`. **Not called.** |
| `sendPushNotification` | callable | asia-south1 | `assertAdmin` | FCM send to **any topic string the caller passes**; adds to `notification_broadcasts` |
| `onOrderStatusChange` | `orders/{id}` written | asia-south1 | none: trusts the order's fields | reads `vendors/{vendorId}`, `managers where territory ==`, `drivers where territory == && status == active`; writes `personal_notifications`; FCM `account_<id>`, `drivers_<territory>` |

- `assertAdmin` accepts `token.admin === true` or `email == admin@qm.com`, and doesn't check `email_verified`.
- `onOrderStatusChange` uses `userId`, `vendorId`, `driverId`, `vendorName` and `userName` from the order doc. Any signed-in client can write orders, so any client can trigger notifications to arbitrary recipients with arbitrary text.
- Which functions are actually deployed hasn't been checked.

## 6. Rules

### Firestore (identical in both repos)
`allow read, write: if request.auth != null` on: managers, territories, categories, vendors, drivers, users, carts, addresses, orders, chat_messages, promotions, coupons, couponRedemptions, tickets, ticket_messages, reviews, settlement_reconciliations, products, global_products, tax_categories, recent_searches, list_order_requests, occasions, topics, notification_broadcasts, personal_notifications.
`app_config`: public read, signed-in write.
**Missing:** `adRevenue`, `managerPayouts`, `settlements`.

### Storage

| Path | Writer | Reader | Foodie-Bell rules | QuickyAdmin rules |
|---|---|---|---|---|
| `vendor_documents/{vendorId}/{type}.jpg` | Vendor (checklist) | Manager, Vendor (by URL) | signed-in | **public read** |
| `driver_documents/{driverId}/{type}.jpg` | Driver | Manager | signed-in | **public read** |
| `user_avatars/{userId}.jpg` | User | anyone with the URL | signed-in | public read |
| `manager_avatars/{managerId}.jpg` | Manager | — | signed-in | public read |
| `promotion_images/{ownerId}_{ts}.jpg` | Vendor (FB), Admin (QA) | User | signed-in | public read |
| `product_images/{vendorId}/{productId}.jpg` | Vendor | User | signed-in | public read |
| `global_product_images/{productId}.jpg` | Admin (QA) | Vendor | signed-in | public read |
| `list_order_images/{vendorId}_{ts}_{i}.jpg` | User | Vendor | signed-in | public read |
| `list_order_receipts/{vendorId}_{ts}.jpg` | Vendor (`vendor_order_queue_screen:625`) | User | signed-in | public read |
| `occasion_themes/{occasionId}/{slot}.png` | Admin (QA) | everyone (via `current_theme`) | **no match (denied)** | public read |

- The `list_order_*` paths are keyed by vendor and timestamp, not by user, so owner-scoped Storage rules for them would need a path change.
- `QuickyAdmin/cors.json` allows all origins and methods (for the web admin).

## 7. KYC documents

- **Upload:** `shared/widgets/vendor_document_checklist.dart` and `driver_document_checklist.dart`, used on the vendor profile, vendor documents-status and under-review screens, the driver documents-status screen, and the manager's vendor/driver detail screens.
  - Steps: pick (`document_source_sheet`) → crop → `putFile` to `{vendor|driver}_documents/{id}/{type}.jpg` → `getDownloadURL` → write `documentUrls.{type}` and set `documentStatuses.{type} = submitted`.
  - Driver: `submitDriverDocuments` writes the URLs plus `riskConsentAccepted`.
- **Delete:** deletes the file, clears the URL, and sets status back to `required`.
- **Review:** the Manager's vendor/driver detail screens call `update{Vendor|Driver}DocumentStatus` and `update{Vendor|Driver}Status`. **QuickyAdmin has no KYC review UI** (the provider functions exist but are unused).
- **Retrieval:** `AppNetworkImage(url)` loads the stored token URL, which works for anyone holding it whatever the Storage rules say. Since every app streams `vendors` and `drivers` wholesale, every signed-in client receives every KYC URL.

## 8. Notification subscriptions and device tokens

- `main.dart` requests notification permission. **No FCM token is ever read or stored** (no `getToken`, no token collection), so the server can only target topics.
- Topics subscribed in `core/notifications/fcm_topics.dart`:

  | Topic | Who | When |
  |---|---|---|
  | `all_users` and `territory_<territoryId>` | User | active, with a territory selected |
  | `account_<accountId>` | any role | active |
  | `drivers_<sanitized territory name>` | Driver | active |

  Topics are re-synced when the session changes and unsubscribed on logout.
- **Senders:** QA `sendPushNotification` (territory and all-users topics) and `onOrderStatusChange` (`account_*` and `drivers_*` topics).
- **In-app history:** `personal_notifications` filtered by recipient, and `notification_broadcasts` filtered to the user's topics.
- FCM topic subscription has no authentication, so `account_<id>` pushes are not private.

## 9. Admin authentication

- **Client:** `admin_login_screen` (email/password plus email comparison) and `admin_session_controller` (same check on restore). No Firestore admin record.
- **Server:** `assertAdmin` in the three callables. Firestore and Storage rules have no admin concept, so every admin write is just "signed in".
- **Hardcoded secrets:** the admin password isn't in either repo. The default manager password `123456` is (`manager_create_screen.dart:33`) and is shown to the admin after creation.

## 10. Existing beta account records

**Live data was not enumerated.** Read-only access through local Google credentials was blocked in this session.

What the code shows:

- **Shared demo credentials:** every phone accepts OTP `123456`; every admin-created manager has password `123456`.
- **QuickyAdmin mock identities still in use:** `MockAccounts` (`u1`, `ven1`, `ven2`, `ven3`, `drv1`–`drv3`, `mgr1`, `adm1`; phones `98765000xx`) and `MockVendors`. They're used for:
  - the admin identity (`adm1`, including as the ticket-reply sender)
  - banner management (`mock_banners_provider`)
  - **seeding Firestore `products` for `ven1`/`ven2`** on first read
  - the vendor → category mapping in the global-catalogue import
- Foodie-Bell's `mock_accounts_provider` is an empty in-memory mirror and seeds nothing.
- **Likely in the live project:**
  - anonymous Auth users (one per login)
  - manager email users with password `123456`
  - `users`/`vendors`/`drivers` docs with random IDs and no UID link
  - possibly `products` seeded for `ven1`/`ven2`
  - `categories` and `tax_categories` seeded by whichever client loaded first
- **To enumerate them:** run a read-only Admin SDK script, or export from the console. It should cover:
  - Auth users grouped by provider
  - account docs per role with `status`, `deletedAt` and `createdAt`
  - phone numbers used by more than one account
  - products whose `vendorId` matches no vendor

## 11. Dependency map: collection → features

Feature folders are under `lib/features/`. QA folders are under `lib/features/admin/`. **Bold** = writes.

| Collection | Foodie-Bell | QuickyAdmin | Functions |
|---|---|---|---|
| `users` | **auth (register)**, **user/profile**, user, shared | users, dashboard | — |
| `vendors` | **manager/vendors**, **vendor**, **shared (KYC)**, manager/dashboard, oversight, reports, settlement, user/home, search, storefront, checkout, help, reviews, driver/home, driver/orders | **vendors**, managers, orders, promotions, reports, transactions, dashboard | `onOrderStatusChange` (R) |
| `drivers` | **manager/drivers**, **driver/home, orders, profile**, **shared (KYC)**, manager/dashboard, user (tracking) | **drivers**, managers, reports, dashboard | `onOrderStatusChange` (R) |
| `managers` | **manager/profile**, auth (login lookup), support/help screens of every role | **managers**, territories, vendors, reports, support, transactions, dashboard | `onOrderStatusChange` (R) |
| `territories` | **manager/categories**, manager/vendors, user/home, search, help, core/notifications | **territories**, **managers**, notifications, promotions, vendors, transactions | — |
| `topics` | — | **territories**, notifications | — |
| `categories` | **seed (any)**, manager/categories, manager/vendors, user/home, search, storefront, vendor/catalogue | **categories**, global_catalogue | — |
| `products` | **vendor/catalogue**, **vendor/promotions**, user/home, search, storefront | **vendors (seed)**, **tax_categories (backfill)**, **global_catalogue (import R)** | — |
| `global_products` | vendor/catalogue | **global_catalogue**, **tax_categories** | — |
| `tax_categories` | **seed (any)**, user/cart, checkout, shared | **tax_categories** | — |
| `orders` | **user/checkout**, **vendor/orders**, **driver/orders, home**, user/home, orders, reviews, help, driver/earnings, history, manager/dashboard, oversight, reports, settlement, shared | orders, users, vendors, managers, reports, settlement, transactions, dashboard | `onOrderStatusChange` (trigger) |
| `couponRedemptions` | **user/checkout** | — | — |
| `coupons` | **vendor/promotions**, user/cart, checkout, home, storefront | — | — |
| `promotions` | **vendor/promotions**, **manager/promotions**, user/home | **promotions**, dashboard, transactions | `sweepExpiredPromotions` (W) |
| `list_order_requests` | **user/list_order**, **vendor/orders**, user/home | — | — |
| `chat_messages` | **shared (order chat: user, driver)** | — | — |
| `tickets` | **support/help of every role**, **manager/support** | **support**, dashboard | — |
| `ticket_messages` | **shared (ticket chat)** | **shared** | — |
| `reviews` | **user/reviews**, user/home, orders, storefront, vendor/dashboard, reviews, driver/home, profile, reviews | — | — |
| `addresses` | **user/addresses**, user/checkout, list_order, core/session | — | — |
| `carts` | **user/cart** (cart_provider) | — | — |
| `recent_searches` | **user/search** | — | — |
| `settlement_reconciliations` | **manager/settlement** | — | — |
| `personal_notifications` | **notifications screens of every role (delete)** | — | `onOrderStatusChange` (W) |
| `notification_broadcasts` | user/notifications, shared | **notifications (delete)** | `sendPushNotification` (W) |
| `app_config` | core/branding, splash | **branding** | `activate`/`resetOccasionTheme` (W, unused) |
| `occasions` | — | **branding** | `activateOccasionTheme` (R) |
| `adRevenue` | — | **transactions**, dashboard | — |
| `managerPayouts` | — | **reports** | — |
| `settlements` | — | **reports** | — |

## 12. What has to change before owner/role rules are possible

These are prerequisites, not rules:

1. **Bind identity:** real phone auth (or custom tokens minted by a function), then key account docs by UID or store `authUid`. Retire anonymous sign-in and the cached-phone restore.
2. **Give rules a role source:** custom claims (`role`, `accountId`, `territoryId`, `admin`) set server-side on creation and approval.
3. **Scope every whole-collection query** (orders, list_order_requests, tickets, reviews, users, vendors, drivers, managers, all products) to `where` clauses the rules can match.
4. **Move privileged transitions to functions:**
   - order status changes and Razorpay signature verification
   - list-order acceptance (it creates an order)
   - approvals and KYC verdicts
   - account creation by managers
   - promotion approval
   - payouts and settlements
5. **Move KYC fields** out of the public vendor/driver docs into a private subcollection. Stop storing token URLs; serve KYC files through Storage rules instead.
6. **Use one rules source** for both apps, and add `adRevenue`, `managerPayouts`, `settlements` and `occasion_themes/`.
7. **Fetch the live rules first** and diff them against the repo.
