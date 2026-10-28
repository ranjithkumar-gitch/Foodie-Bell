# Quicky — Firebase Architecture Audit (read-only)

Date: 2026-10-28 · Firebase project `quickmandi-3b017` · Repositories: `Foodie-Bell` (customer, vendor, driver and Manager app) and `QuickyAdmin` (Super Admin app, plus the only deploy source for rules, indexes and functions).

**Method.** A read-only review of the source code in both repositories as it stands today, which includes the uncommitted Phase 1–4 work. **No code, rules, configuration or data was changed, and nothing was deployed.** The only file written is this report.

Test evidence cited here comes from the emulator runs recorded in `PHASE_4_PRODUCTION_READINESS_REPORT.md` (same day). Those runs weren't repeated for this audit.

**Information that was not available.** These items need the owner or console access:
- The rules, indexes and functions **currently deployed** to `quickmandi-3b017` (not read: that needs a signed-in Firebase CLI or the console).
- Production data volumes, Firestore and Functions usage metrics, and billing history.
- App Check, Auth, API-key and quota settings in the console.
- Results from a real-device or staging run.

Wherever this report says "the code", it means the repository, not what is live.

---

## 1. Executive summary

| | |
|---|---|
| Architecture in the repo | Server-authoritative. Every order, payment, delivery and settlement step is a Cloud Function callable that checks custom claims and the order's state inside a transaction. Clients can't write orders, the ledger, statements or read models. Data access is scoped by territory ID, history is paged, and dashboards read totals kept by the server. |
| Biggest risk today | **What is live is not what is in the repo.** Phase 1's audit (2026-10-26) found the deployed rules let any signed-in user (including anonymous ones) read and write every collection, and found publicly readable Storage. None of Phases 1–4 has been deployed, so until the release in §11 happens **production runs the old, insecure model.** |
| Financial logic in the repo | Correct against the business rules. Checked with 152 matrix cases plus end-to-end ledger and settlement tests, all on the emulator. |
| Scalability | Per-screen reads are measured and bounded (10,000-order dataset). **Concurrent capacity is unverified:** only a 100-user emulator run exists, and the emulator can't simulate production function scaling. |
| Verdict | **Not production-ready** until the CRITICAL items in §10 are closed. |

Findings by severity (details in §7–§10):

| Severity | Count | Examples |
|---|---|---|
| CRITICAL | 4 | insecure rules live in production; release builds signed with the debug key; nothing deployed or device-tested; no billing budgets or alerts |
| HIGH | 9 | App Check not enforced; Maps key in the app with unknown restrictions; placeholder privacy policy; no crash reporting; manual UPI verification; old admin-written financial records parallel to the ledger; Manager docs (incl. `territoryFee`) readable by all accounts; offer details visible to all territory drivers; capacity untested |
| MEDIUM | 10 | statement rebuild still reads the day's ledger; hot per-territory counters; admin directories stream whole collections; admin coupons lack `territoryId`; legacy beta orders outside the ledger; refunds never marked `refunded` |
| LOW | 6 | dead `updateManagerTerritoryFee` path; leftover legacy fields; Telugu strings |

## 2. Existing Firebase architecture

| Service | Use | Where |
|---|---|---|
| Authentication | Phone OTP for customers, vendors, drivers and Managers; email + password + `superAdmin` claim for the Super Admin. Anonymous sign-in gets nothing (rules). | `Foodie-Bell/lib/core/session/*`, `account_resolver.dart`; `QuickyAdmin/lib/core/session/admin_session_controller.dart` |
| Custom claims | `role`, `accountId`, `territoryId`, `active`, set only by the server | `QuickyAdmin/functions/accounts.js` (`resolveSession`, `registerCustomer`, `sync*Claims`, `syncTerritoryManagerClaims`) |
| Firestore | All application data (§3) | rules `QuickyAdmin/firestore.rules` (≈750 lines, deny by default) |
| Cloud Functions (v2, Node 20) | 50 functions: 33 callables, 10 Firestore triggers, 6 scheduled jobs, 1 Storage trigger | `QuickyAdmin/functions/*.js` |
| Cloud Storage | KYC documents, photo orders, receipts, delivery proof (private, read through the rules); product, cover, promotion and theme images (public) | `QuickyAdmin/storage.rules` |
| Cloud Messaging | Personal pushes to registered device tokens; topics `all_users`, `territory_<id>` and `drivers_<territoryId>` | `functions/notifications.js`; `Foodie-Bell/lib/core/notifications/fcm_topics.dart` |
| App Check | Play Integrity / App Attest (with DeviceCheck fallback) / reCAPTCHA Enterprise integrated in both apps; **monitor mode only** | `lib/core/security/app_check.dart` (both); `functions/.env` `ENFORCE_APP_CHECK=false` |
| Google Routes API (server) | Road distance for delivery pricing, cached in `route_cache` | `functions/routing.js` (secret `ROUTES_API_KEY`) |
| Google Maps SDK / Routes (client) | Maps and route drawing | `Foodie-Bell/lib/data/providers/road_route_provider.dart`, `AndroidManifest.xml` (API key in source) |
| Indexes | 34 composite indexes and 17 field exemptions | `QuickyAdmin/firestore.indexes.json` |
| Deploy source | `QuickyAdmin/firebase.json` (rules, indexes, functions, emulators) | Foodie-Bell no longer deploys rules or indexes |
| Not integrated | Crashlytics, Performance Monitoring, Remote Config, Analytics-based alerting | `pubspec.yaml` (both) |

## 3. Firestore collection structure

| Collection | Written by | Read by (rules) | Notes |
|---|---|---|---|
| `users/{id}` | `registerCustomer`; the owner (name, email, avatar, language) | owner, admin | |
| `vendors/{id}` | Manager (onboarding, review), the vendor (limited fields), server (`rating`, claims) | active vendors: every account; otherwise the owner, territory Manager, admin | `rating` is server-only |
| `drivers/{id}` | Manager, the driver (limited fields), server (`rating`) | owner, territory Manager, admin | |
| `managers/{id}` (+ `private/bank`) | admin; the Manager (avatar, own bank doc) | **every account** (public doc, incl. `territoryFee`); bank: owner and admin | §7 H-7 |
| `territories/{id}` | admin | every account | ID = the stable `territoryId` |
| `categories`, `tax_categories`, `global_products` | admin | every account | |
| `products/{id}` | the vendor (own; prices, stock) | every account | prices are re-read by `placeOrder` |
| `catalog_index/{t}_{0..3}` | server | every account | search index |
| `orders/{id}` (+ `codes/*`, `events/*`, `private/*`) | **server only** | customer, vendor, assigned driver, territory drivers (open offers only), territory Manager, admin | |
| `order_requests`, `route_cache`, `statement_queue`, `device_tokens` | server only | nobody (no rule) | |
| `order_tracking/{orderId}` | server opens/closes it; the assigned driver moves the position | that order's customer, vendor and driver; territory Manager; admin | |
| `coupons/{id}` | the vendor (create; own territory); admin | every account | |
| `couponRedemptions/{coupon_user}` | server (`placeOrder` transaction) | that customer (get), admin | single-use lock |
| `promotions/{id}` | the vendor (request), Manager (approve, payment received), admin | live ones: everyone; otherwise vendor, Manager | promotion payments sit outside the ledger (§6) |
| `carts`, `recent_searches`, `addresses` | the customer | the customer | |
| `list_order_requests/{id}` | customer (create, mark paid), vendor (quote via callable); `acceptListOrder` creates the order | customer, vendor | "paid" is the customer's claim (§6) |
| `reviews/{rev-orderId}` | the order's customer, once, for a delivered order | every account | |
| `chat_messages`, `tickets`, `ticket_messages` | participants | participants, admin | |
| `ledger_entries/{id}` | **server only**, append-only | each named party; territory Manager; admin | source of financial truth |
| `settlement_transfers/{id}` | server (callables) | parties; territory Manager; admin | acknowledged by the other party |
| `settlement_adjustments/{id}` | server | territory Manager; admin | approved by the Super Admin only |
| `daily_settlements/{t}_{day}` | server | territory Manager; admin | |
| `earnings_daily`, `earnings_totals`, `territory_daily_stats`, `territory_totals`, `trending_daily`, `trending` | server (in the ledger transaction; trending hourly) | own party / territory Manager / admin; `trending` every account | read models derived from the ledger |
| `pricing_versions/{v}`, `app_config/{pricing,current_theme}` | server (`updatePricing`, theme callables) | every account (`app_config` is public) | |
| `settlements`, `managerPayouts`, `adRevenue` | **admin client directly** (append-only rules) | admin | §7 H-6 |
| `settlement_reconciliations` | legacy (read-only) | Manager, admin | |
| `personal_notifications`, `notification_broadcasts` | server | recipient / every account (broadcasts) | |
| `claimSync/{uid}`, `topics`, `occasions` | server / admin | owner / admin | |

## 4. Cloud Functions vs direct Firestore operations

### 4.1 Through Cloud Functions (server-validated)

| Operation | Function (file) | Checks |
|---|---|---|
| Sign-in binding, claims | `resolveSession`, `registerCustomer`, `sync*Claims` (accounts.js) | verified phone from the ID token; claims recomputed on every status or territory change; refresh tokens revoked on loss of access |
| Quote and place an order | `quoteOrder`, `placeOrder` (orders.js) | caller is an active customer; catalogue prices, coupon, road distance and pricing version are all read on the server; idempotency key; order ID from a cryptographic RNG; single transaction |
| UPI | `submitUpiReference`, `confirmUpiPayment`, `reportPaymentIssue`, `resolvePaymentDispute` | only the vendor confirms, once; only the territory Manager resolves disputes |
| Vendor decision, cancellation | `vendorDecision`, `cancelOrder` | owner and state checks in a transaction; UPI orders need verified payment before acceptance |
| Driver claim, reassignment | `claimDelivery`, `reassignDriver` | transactional single winner; territory claim |
| Pickup and delivery | `confirmPickup`, `confirmDelivery` (order_codes.js) | 4-digit codes, 5-attempt lock, constant-time compare; COD needs the cash recorded |
| COD cash, failed delivery | `recordCodCollection`, `reportDeliveryFailure`, `resolveDeliveryIssue` | amount ≤ total; Manager override needs an existing proof photo |
| Photo orders | `quoteListOrder`, `acceptListOrder` | server adds delivery; receipt path must be in the vendor's folder |
| Ledger and statements | `postOrderLedger` (trigger), `generateDailySettlement`, `recordSettlementTransfer`, `acknowledgeSettlementTransfer`, `proposeSettlementAdjustment`, `decideSettlementAdjustment`, `rebuildQueuedStatementsJob`, `refreshDailySettlements`, `reconcileStatements`, `reconcileAggregates`, `reconcileTerritoryDay` | idempotent posting; counterparty acknowledgement; Super-Admin-only adjustments |
| Pricing | `updatePricing` | Super Admin only; versioned; GST can't be switched on |
| Read models | `onReviewWritten`, `onProductWritten`, `rebuildCatalogIndex`, `refreshTrendingSearches`, `refreshTrendingNow` | server-only writes |
| Notifications | `onOrderStatusChange`, `registerDevice`, `unregisterDevice`, `sendPushNotification` | names come from the account docs; token filed under the verified caller; broadcasts limited to `all_users` or a real territory |
| Branding, uploads, promotions | `activateOccasionTheme`, `resetOccasionTheme`, `validateUpload`, `sweepExpiredPromotions` | admin only; real image-byte checks; private-file token rotation |

### 4.2 Direct from Flutter (protected only by the rules)

| Operation | File · method | Security implication |
|---|---|---|
| Product create/edit/delete, stock | `Foodie-Bell/lib/data/providers/firestore_products_provider.dart` · `addProduct`, `updateProduct`, `deleteProduct`, `setProductInStock` | vendor's own products only; price > 0. Prices are re-read on the server at checkout, so a later price edit can't change a placed order. Acceptable. |
| Vendor profile, open/closed, UPI IDs, KYC paths | `firestore_vendors_provider.dart` · `updateVendorProfile`, `setVendorOpen`, `setVendorUpiIds`, `updateVendorDocumentPath` | field allow-list; a vendor can't change status, territory, rating or commission. **UPI ID change** is client-editable (§6 F-5). |
| Manager onboarding / KYC review of vendors and drivers | `manager_vendor_create_screen.dart`, `manager_driver_create_screen.dart`, `updateVendorStatus`, `updateDriverStatus`, `update*DocumentStatus` | Manager's own territory, fixed fields; status changes trigger claim sync. Acceptable. |
| Coupons (create) | `firestore_coupons_provider.dart` · `createCoupon` | own vendor and territory; value bounds; enforced again at checkout |
| Promotion requests and approval, "payment received" | `firestore_promotions_provider.dart` · `createPromotionRequest`, `markPromotionPaid`, `approve/rejectPromotion` | fixed price plans; Manager-only approval. **Promotion money is outside the ledger** (§6 F-7). |
| Cart, addresses, recent searches | `firestore_carts_provider.dart`, `firestore_addresses_provider.dart`, `firestore_recent_searches_provider.dart` | owner only; the cart is advisory (the server prices orders) |
| Photo order create / mark paid | `firestore_list_order_requests_provider.dart` · `createListOrderRequest`, `markListOrderPaid` | "paid" is the customer's claim; the vendor must attach a receipt (§6 F-6) |
| Reviews | `firestore_reviews_provider.dart` · `submitReview` | one per delivered order, by its customer (rule checks the order) |
| Chat, tickets | `firestore_chat_provider.dart`, `firestore_tickets_provider.dart`, `firestore_ticket_chat_provider.dart` | participants only |
| Driver live position | `firestore_orders_provider.dart` · `updateOrderDriverLocation`; `firestore_drivers_provider.dart` · `updateDriverLocation` | assigned driver, open tracking only, server timestamp |
| Manager bank details | `firestore_managers_provider.dart` · `saveManagerBankDetails` | own `private/bank`, format-checked |
| Territory fee (Manager app) | `firestore_managers_provider.dart` · `updateManagerTerritoryFee` | **refused by the rules** (admin only): dead code (L-1) |
| **Admin financial records** | `QuickyAdmin/lib/data/providers/firestore_settlements_provider.dart`, `firestore_manager_payouts_provider.dart`, `firestore_ad_revenue_provider.dart` | admin-only, append-only rules, **but written from the client and not part of the ledger** (§7 H-6) |
| Admin catalogue, categories, territories, coupons, tax categories | QuickyAdmin providers | admin only. Admin-created coupons have no `territoryId` (M-6). |

**Conclusion:** every critical business operation (order money, status, payment state, driver assignment, cash, ledger, settlements, pricing, roles) runs through Cloud Functions. What remains direct is catalogue, profile and support data constrained by the rules, with three money-adjacent exceptions (UPI IDs, promotion payments, admin payout records) covered in §6–§7.

## 5. Complete order processing flow

| Stage | Flutter | Firestore | Function | AuthN/AuthZ | Concurrency / duplicates |
|---|---|---|---|---|---|
| 1. Customer places order | `checkout_*` screens → `order_actions.dart` `quoteOrder`/`placeOrder` | `orders` create, `order_requests`, `couponRedemptions`, `events` | `placeOrder` (+ `createOrderCodes` trigger, `onOrderStatusChange`) | active `user` claim; own address; shop open; items from that shop and in stock | **Idempotency key** → one order per key, even when sent in parallel (tested). Coupon single-use inside the transaction. |
| 2. Vendor receives the order | `vendor_order_queue_screen.dart` (`activeOrdersProvider`) | listener: `vendorId ==` + active statuses | push via `onOrderStatusChange` | rules: own orders only | duplicate pushes prevented by deterministic notification IDs |
| 3. Vendor verifies UPI payment | `vendor_order_actions.dart`, `upi_payment_card.dart` | `payment.status` updated | `confirmUpiPayment` / `reportPaymentIssue` | the order's vendor only; once | second confirmation refused (tested) |
| 4. Vendor accepts | same | `status → vendorAccepted` | `vendorDecision` | owner; UPI must be `verified` | accept and reject at the same moment → exactly one (tested) |
| 5. Delivery partners notified | driver home (`activeOrdersProvider` offers query) | listener: `territoryId ==`, `status == vendorAccepted` | one topic ping `drivers_<territoryId>`, deduplicated per acceptance | rules: active driver of that territory | |
| 6. Driver accepts | `driver_offer_*` → `claimDelivery` | `status → driverAssigned`, `order_tracking` opened | `claimDelivery` | driver claim + territory | transaction: two drivers → one winner (tested) |
| 7. Pickup | handover code → `confirmPickup` | `status → pickedUp` | `confirmPickup` | assigned driver; vendor shows the code | 5-try lock; state check |
| 8. Delivery | COD: `recordCodCollection`; delivery code → `confirmDelivery` | `status → delivered`, tracking closed | `confirmDelivery`; `postOrderLedger` trigger | assigned driver; customer shows the code; COD cash recorded first | three parallel confirmations → one success, one ledger posting (tested) |
| 9. Ledger | — | `ledger_entries` (4–5) + read models in **one transaction** | `postOrderLedger` (`retry: true`) | server only | existence check inside the transaction makes duplicate events no-ops (tested) |
| 10. Daily settlement | `manager_daily_settlement_screen.dart` → `generateDailySettlement`; payments `recordSettlementTransfer` / `acknowledgeSettlementTransfer` | `daily_settlements`, `settlement_transfers`, `statement_queue` | ledger.js callables + 10-minute queue + nightly refresh and reconciliation | Manager of the territory / the parties / Super Admin | per-key transfer IDs; single-use acknowledgement; simultaneous generation gives the same statement (tested); the queue clears only if nothing re-queued it |

Failure branches covered by tests: shop rejects; customer cancels before acceptance; UPI not received (dispute → cancelled); rejected after payment (refund due → recorded → acknowledged); delivery failed (returned, or delivered only with a proof photo); Manager reassigns or releases a driver; COD shortfall (stays disputed until an approved adjustment).

## 6. Financial security assessment

| Rule | Implementation | Status |
|---|---|---|
| Commission 10% of eligible value (after vendor coupon) | `functions/money.js` `computeOrderMoney`; integer paise, half-up once | **Correct.** 152 matrix cases match an independent calculation. |
| Manager 60% / Super Admin 40% of commission | `managerShare = round(60%)`, `quickyShare = commission − managerShare` | **Correct**, and never off by a paisa. |
| Rider 100% of the delivery fee | `driverEntitlement = deliveryFee` | **Correct.** |
| Slabs ₹20/30/40/50/60 up to 3/5/7/9/11 km; above 11 km blocked | `deliverySlabFor`; global `app_config/pricing`, versioned, Super Admin only | **Correct** at both sides of every boundary. |
| Distance | server-side Google Routes (two-wheeler), cached 30 days per shop and drop-off; no straight-line fallback | Correct. Depends on the Routes key being configured. |
| Order amount validation | the client sends only product IDs and quantities; the server prices everything | **Correct.** "Client cannot set prices" is tested. |
| UPI: vendor confirms before accepting | `confirmUpiPayment` gate in `vendorDecision` | Correct in code. **Manual verification only (F-1).** |
| COD: rider collects, hands over via the Manager | ledger: driver → Manager full total; Manager → vendor, rider, Quicky | Correct. Shortfall stays flagged until the Super Admin approves an adjustment. |
| Daily settlement | rebuilt from the ledger; opening balance = previous closing; "completed" only when balances are zero through acknowledged payments | Correct. Equals a full recomputation (tested); history isn't rewritten (tested). |
| Permissions on financial data | ledger, statements, transfers and read models are server-written; each party reads only its own | Correct in the rules (210 tests). |
| Duplicate settlement prevention | deterministic ledger IDs + transaction; transfer IDs per caller and key; single-use acknowledgements | Correct (tested). |

Financial findings:

| ID | Severity | Where | Issue | Impact | Recommendation |
|---|---|---|---|---|---|
| F-1 | HIGH (accepted design risk) | `functions/orders.js` · `confirmUpiPayment` | UPI receipt is the vendor's own manual check; the customer's reference is only a claim. The app states that a screenshot is not proof. | A dishonest or mistaken vendor confirmation can't be detected automatically; disputes go to the Manager. | Phase 5: a payment gateway or bank-statement reconciliation, or a UPI intent callback with a verified VPA response. Meanwhile, Manager spot checks. |
| F-2 | MEDIUM | `functions/ledger.js` · `rebuildStatement` | Each rebuild reads that day's ledger entries; rebuilt at most every 10 minutes (plus on Manager actions). | Bounded (~72 rebuilds/day/territory), but cost still grows with daily volume. | Incremental statements updated in the posting transaction. |
| F-3 | MEDIUM | ledger.js | Refunds end at `payment.status = refundDue`; never marked `refunded`. | Order screens keep showing "refund due" after it's paid. | Mark it `refunded` when the refund transfer is acknowledged. |
| F-4 | MEDIUM | `Order` getters (both apps) | Pre-Phase-2 beta orders have no money snapshot; they show legacy figures and aren't in the ledger or totals. | Beta history differs from the ledger. | Settle the beta period by hand once; mark those orders as legacy. |
| F-5 | MEDIUM | `firestore_vendors_provider.dart` · `setVendorUpiIds`; rules for `vendors` | A vendor can change their UPI ID at any time; new orders snapshot the current ID. | A compromised vendor account could redirect customer payments. | Notify the Manager on a UPI ID change; optionally require Manager approval, or a cooling-off period. |
| F-6 | MEDIUM | `firestore_list_order_requests_provider.dart` · `markListOrderPaid` | A photo order's "paid" is set by the customer. | The vendor relies on the receipt plus their own check. | Use the same `confirmUpiPayment` flow as normal orders. |
| F-7 | MEDIUM | `firestore_promotions_provider.dart` · `markPromotionPaid` | Promotion fees (₹300–1,000) are confirmed by the Manager on the client and aren't in the ledger. | Promotion revenue isn't reconciled. | A callable that posts a `promotion_fee` ledger entry. |
| F-8 | HIGH | QuickyAdmin `firestore_settlements_provider.dart`, `firestore_manager_payouts_provider.dart` | The legacy admin `settlements` and `managerPayouts` records are written by the admin client and sit **beside** the ledger; the Manager wallet combines them with ledger totals. | Two records of the same money can disagree. | Retire them in favour of `settlement_transfers` and adjustments, or post them through a callable into the ledger. |

## 7. Security vulnerabilities

| ID | Severity | Where | Explanation | Impact | Recommendation |
|---|---|---|---|---|---|
| C-1 | **CRITICAL** | live project `quickmandi-3b017` (deployed rules and functions) | Phase 1's audit found the deployed rules let any signed-in user, including anonymous, read and write every collection, and Storage was publicly readable. The fixed rules and functions exist **only in the repo**. | Anyone can read customer data and KYC, change orders and money, or impersonate roles **today**. | Deploy Phases 1–4 in the order in §11 as soon as possible; meanwhile restrict the live rules to admin-only for sensitive collections. Confirm the live rules in the console (needed info). |
| C-2 | **CRITICAL** | `Foodie-Bell/android/app/build.gradle.kts` (`signingConfig = debug`) | Release builds are signed with the debug key. | Can't publish safely; anyone with the debug key could sign an "update". | Create an upload keystore (`key.properties`), use Play App Signing, add its SHA-256 to Firebase and App Check. |
| C-3 | **CRITICAL** | whole release | Nothing is deployed, and no flow has run on real devices, real OTP or real FCM. | Unknown production defects. | Staging project + a device test plan (Phase 4 report §11). |
| C-4 | **CRITICAL** | Google Cloud Billing | No budget or alerts configured (as far as the code and reports show). | A runaway loop or attack runs up unbounded cost. | Budgets at 50/90/100%, anomaly alerts, quotas on Routes and Maps. |
| H-1 | HIGH | `functions/.env` `ENFORCE_APP_CHECK=false`; console unenforced | App Check is integrated but not enforced. | Scripts can call callables and read Firestore with a stolen token without a genuine app. | Register release builds, watch the metrics for a week, then enforce Firestore, Storage and callables. |
| H-2 | HIGH | `road_route_provider.dart`, `AndroidManifest.xml` | The Maps/Routes key ships in the app; restrictions unknown. | Key abuse means quota theft and billing. | Restrict to the Android package + SHA-1 and the iOS bundle; Maps SDK only; move Routes calls to the server (already done for pricing). |
| H-3 | HIGH | `lib/shared/auth/auth_terms_screen.dart` | Privacy policy and terms are placeholder text. | Play Store rejection; DPDP Act exposure (phone numbers, addresses, KYC). | Publish a real policy; link it in the app and the store listing. |
| H-4 | HIGH | `pubspec.yaml` (both) | No Crashlytics or Performance Monitoring. | Crashes and slow screens go unseen. | Add `firebase_crashlytics` and `firebase_performance`. |
| H-5 | HIGH | `ios/Runner` | No entitlements (push `aps-environment`, App Attest); no APNs key known. | No pushes and no App Check on iOS. | Add the capabilities; upload an APNs key to FCM. |
| H-6 | HIGH | see F-8 | Admin client writes financial records outside the ledger. | Inconsistency. | As F-8. |
| H-7 | HIGH | `firestore.rules` `managers` read | Every signed-in account can read Manager docs, including `territoryFee` (a business secret). | Commercial data leak to any customer. | Split into `managers_public/{id}` (name, phone, territory) and keep the rest admin-only. |
| H-8 | HIGH | `firestore.rules` `orders` (open offers) | Every active driver in a territory can read an open offer's customer name and drop-off address. | Customer privacy (address seen by drivers who don't take the job). | Put only the area and distance on offers; reveal the address after the claim (e.g. in `order_tracking` or a `private` subdoc). |
| H-9 | HIGH | — | Concurrent capacity unverified (§8). | Behaviour at an evening peak is unknown. | Staged load test on staging (`tests/load/load.mjs`). |
| M-1 | MEDIUM | `vendors` read rule | Active vendors' KYC *paths* (not files) are visible to customers. | Minor metadata leak. | Move `documentPaths`/`documentStatuses` to a private subdoc. |
| M-2 | MEDIUM | `firestore.rules` `reviews` | Reviews (with the customer's first name) are public to all accounts. | Expected for a storefront; disclose it in the privacy policy. | Show initials only. |
| M-3 | MEDIUM | `functions/notifications.js` | The `drivers_<territoryId>` topic can be subscribed to by anyone who knows a territory ID. | Reveals order volume and shop names only. | Acceptable; or move offer pings to driver device tokens. |
| M-4 | MEDIUM | Auth console | Anonymous provider still enabled (per Phase 1 plan); SMS quota and abuse limits unverified. | SMS-pumping cost. | Disable anonymous sign-in; set SMS region policy (India only) and App Check for Auth. |
| M-5 | MEDIUM | backups | No scheduled export or PITR known. | Data loss on a mistake. | Daily `gcloud firestore export`; enable point-in-time recovery; test a restore. |
| M-6 | MEDIUM | QuickyAdmin `firestore_coupons_provider.dart` · `createCoupon` | Admin-created coupons have no `territoryId`, so customers' territory query never shows them. | Admin coupons don't appear. | Add `territoryId` (or a "platform" flag queried separately). |
| L-1 | LOW | `firestore_managers_provider.dart` · `updateManagerTerritoryFee` | Refused by the rules: dead code in the Manager app. | None. | Remove it. |
| L-2 | LOW | `Order` model | Legacy rupee fields kept alongside `money`. | Confusion. | Remove after the beta is settled. |

What was checked and found sound in the repo: role-based access through server-set claims only; territory isolation by claim and document field; vendors can't see other vendors' records or orders; drivers can't write money or status; customers see only their own orders and data; the ledger and all derived financial data are server-written; every callable checks sign-in, role, `active` and territory; private Storage files are read only through the rules, with download tokens rotated.

## 8. Scalability assessment

**Verified results** (Firestore emulator, synthetic data; `PHASE_3_PERFORMANCE_REPORT.md` §8):

| | Before Phase 3 | Now |
|---|---|---|
| Reads per customer Home open (10,000 orders) | 12,968 | 71 |
| Vendor dashboard | 2,778 | 4 |
| Manager dashboard | 1,193 | 63 |
| Statement rebuild per delivery | 4,397 | 61 |
| Super Admin dashboard | 11,000 | 261 |

**Load test actually run:** scenario A, 100 virtual users on the emulator.
- Browsing and dashboard queries: no failures; p95 ≈ 1.2 s on one PC.
- Callables queued behind each other, because the local Functions emulator runs requests one after another.
- No integrity violations.

**Not run:** B (500), C (1,000), D (5,000). **No concurrency capacity is claimed.**

**Architectural estimates** (not verified):

| Factor | Analysis | A 100 | B 500 | C 1,000 | D 5,000 |
|---|---|---|---|---|---|
| Firestore throughput | Firestore handles many thousands of ops/s per database; per-user load is ~70 reads per Home open and a few listeners | ✓ | ✓ | ✓ | likely ✓ |
| Listeners | per user: in-progress orders (1–2), plus the open screen's bounded queries; history is never listened to | ✓ | ✓ | ✓ | ✓ (a few listeners per user) |
| Cloud Functions | v2, 80 concurrent requests per instance by default, autoscaling; no `maxInstances`; cold starts likely in asia-south1 without `minInstances` | ✓ | ✓ | check cold starts at peak | needs a load test; consider `minInstances: 1` on `placeOrder`, `claimDelivery` |
| Hot documents (~1 sustained write/s per doc) | `territory_daily_stats`, `territory_totals`, the Manager's `earnings_*` take one write per delivery in the territory | ✓ | ✓ | ✓ unless one territory delivers > ~1/s | shard counters if one territory reaches ~1 delivery/s (~3,600/hour) |
| Transaction contention | per-order transactions; driver claims contend only on the same order (one winner by design) | ✓ | ✓ | ✓ | ✓ |
| Territory filtering and indexes | every list query is territory- or owner-scoped with a composite index | ✓ | ✓ | ✓ | ✓ |
| Notifications | one doc + token multicast per recipient; one topic message per acceptance | ✓ | ✓ | ✓ | ✓ (FCM quotas far higher) |
| Google Routes API | one call per new address per shop (30-day cache) | ✓ | ✓ | quota | **check quota and billing** |
| Auth SMS | one OTP per sign-in | ✓ | ✓ | quota | **SMS quota and cost** |

"Concurrent users" here means connected app users following the traffic mix (70% browsing, 10% ordering, 8% vendors, 7% drivers, 5% Managers). It does **not** mean simultaneous order placements.

## 9. Firebase cost optimization

Already done in the repo (Phase 3): territory-scoped queries; paged history; server totals in place of client sums; a product search index in place of the products collection; ratings on vendor/driver docs; trending as one doc per territory; live location off the order doc, written at most every 10 s; triggers exit early; deterministic notifications; no per-driver fan-out; `autoDispose` listeners; queued statement rebuilds; index exemptions for big maps. Estimate: **≈ $0.85 per 1,000 completed orders** (assumed list prices; see Phase 3 §9), against costs that used to grow with history.

Remaining opportunities:

| Severity | Where | Issue | Recommendation |
|---|---|---|---|
| MEDIUM | ledger.js `rebuildStatement` | day-scoped rebuild reads | incremental statements (F-2) |
| MEDIUM | QuickyAdmin directories (users, vendors, drivers, coupons, products, promotions screens) | whole-collection streams when an admin opens them | paged queries and `count()` |
| MEDIUM | Storage egress | product images served at full size | Resize Images extension (thumbnails); long cache headers |
| MEDIUM | `onOrderStatusChange` | 3 account reads per status change (kept on purpose, Phase 1 rule) | acceptable; cache the vendor doc per instance briefly |
| LOW | vendor storefront | whole catalogue of the shop being viewed | fine for typical catalogues; page it if a shop has more than ~500 items |
| LOW | client cache | Firestore offline cache is on by default; `trending` and `catalog_index` are re-listened per screen | keep them alive for the session, or read from cache first |
| — | Billing risks | Routes/Maps calls, SMS OTP, runaway retries | quotas, budgets, App Check (C-4, H-1, H-2, M-4) |

## 10. Recommended improvements (by priority)

**CRITICAL — before production**
1. Deploy Phases 1–4 (rules, functions, indexes, migrations) to staging, then production, in the documented order (C-1, C-3).
2. Release signing for Android (C-2).
3. Billing budgets, alerts and API quotas (C-4).
4. A device test pass for all five roles with real OTP and FCM (C-3).

**HIGH — as soon as possible**
5. Enforce App Check (H-1).
6. Restrict the Maps key (H-2).
7. Publish a real privacy policy and terms (H-3).
8. Add Crashlytics and Performance Monitoring (H-4).
9. Add iOS push and App Attest entitlements (H-5).
10. Retire the admin-side payout and settlement records, or post them through the ledger (F-8 / H-6).
11. Split the public Manager profile out (H-7).
12. Hide customer details on open offers (H-8).
13. Run staged load tests B → D on staging with a cost cap (H-9).
14. Plan UPI verification beyond the vendor's manual check (F-1).

**MEDIUM**
15. Incremental statements (F-2).
16. Mark refunds `refunded` (F-3).
17. Settle legacy beta orders (F-4).
18. Notify the Manager on vendor UPI ID changes (F-5).
19. Route photo-order payment through the server (F-6).
20. Post promotion fees to the ledger (F-7).
21. Hide KYC paths from customers (M-1).
22. Disable anonymous sign-in and set SMS limits (M-4).
23. Backups and PITR (M-5).
24. Add `territoryId` to admin coupons (M-6).
25. Page the admin directories.
26. Image thumbnails.

**LOW**
27. Remove dead code (L-1).
28. Remove legacy fields after the beta (L-2).
29. Telugu strings for the Phase 2/3 screens.
30. Sharded counters when needed.

## 11. Production readiness assessment

| Area | Status |
|---|---|
| Authorization model and rules (repo) | **PASS** (210 rules tests, emulator) |
| Live production security | **FAIL** (C-1: old rules deployed) |
| Order integrity and race safety | **PASS** (emulator tests) |
| Financial correctness | **PASS** (152 matrix + e2e, emulator) |
| UPI verification strength | **PARTIAL** (manual, by design) |
| Scalability, per-screen | **PASS** (measured to 10,000 orders) |
| Concurrent capacity | **NOT TESTED** (B–D) |
| App Check | **FAIL** (not enforced) |
| Release configuration (Android, iOS, privacy) | **FAIL** |
| Monitoring and billing protection | **FAIL** |
| Devices, OTP, FCM, low network | **NOT TESTED** |

**Overall: NOT production-ready.** Recommended path: staging deployment → device tests → a closed beta in one territory (Chityal) → staged load tests → launch review.

### Production launch checklist

Tick an item only once you have evidence for it.

- [ ] Check the live rules in the console and confirm they're the insecure pre-Phase-1 version (the information this audit couldn't read)
- [ ] Create the staging Firebase project; deploy rules, indexes and functions there; set `ROUTES_API_KEY` and `STORAGE_REGION`
- [ ] Run `migrate-phase1.js` and `migrate-phase3.js` dry runs on staging, then `--apply`
- [ ] Device test, all five roles: sign-in/out, session restore, order COD and UPI, failure paths, push on two devices, live map
- [ ] Low-network test on a low-end Android (throttled 3G, airplane-mode toggle mid-checkout): no duplicate orders or money events
- [ ] Load tests A → D on staging with a billing cap; record p50/p95/p99, errors, reads/writes, cost
- [ ] Android upload keystore + Play App Signing; SHA-256 in Firebase; release build tested
- [ ] iOS: push + App Attest capabilities; APNs key in FCM
- [ ] App Check: release apps registered; one week of metrics; enforce Firestore, Storage, callables
- [ ] Maps/Routes keys restricted; quotas set
- [ ] Crashlytics + Performance Monitoring added and receiving data
- [ ] Billing budget (50/90/100%), anomaly alerts, Firestore-reads alert, Functions error alert, failed-order / unpaid / unclaimed-order alerts, reconciliation-error log alerts
- [ ] Daily Firestore export + PITR; one restore rehearsed
- [ ] Real privacy policy, terms and data-retention policy published and linked
- [ ] Written settlement SOP for vendors, riders and Managers (UPI check, COD hand-over, daily cut-off 22:00)
- [ ] Production: export backup → indexes → functions → migrations → app release → rules → App Check enforcement
- [ ] Disable anonymous Auth; restrict SMS regions
- [ ] Rollback rehearsed (rules history restore, previous functions)
- [ ] Commit Phases 1–4 to version control (nothing is committed yet)
