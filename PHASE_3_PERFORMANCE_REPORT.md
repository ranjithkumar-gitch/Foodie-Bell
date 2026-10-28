# Phase 3 Performance Report — Scalability, Data Access and Firebase Cost

Date: 2026-10-28 · Firebase project `quickmandi-3b017`
Status: **implemented and tested in the Firebase emulators; nothing committed, nothing deployed.**

Prerequisites: `PHASE_1_SECURITY_REPORT.md` and `PHASE_2_FINANCIAL_IMPLEMENTATION_REPORT.md` were read. Both phases are code-complete and emulator-tested but **not deployed and not tried on devices**; the product owner asked to start Phase 3 on that basis. `ARCHITECTURE_AUDIT_REPORT.md` **does not exist** in either repository (as noted in Phase 2), so the baseline below comes from reading the code. All three phases are meant to ship as one coordinated release.

A pre-Phase-3 copy of both working trees was saved outside the repos (not committed): `…/scratchpad/backup/Foodie-Bell_pre_phase3.tgz` and `QuickyAdmin_pre_phase3.tgz`.

---

## 1. Baseline architecture (before Phase 3)

Every finding below was read from the code. The measured cost of each is in §8.

| # | Where | What it did | Why it doesn't scale |
|---|---|---|---|
| 1 | `firestoreOrdersProvider` (Foodie-Bell) | One live, never-disposed listener on **every order the account can see**: a customer's whole history, a vendor's, a driver's, a Manager's whole territory. No `limit`, no ordering. 19 screens filtered it on the phone. | Grows forever with history; every change to any of those orders is re-sent. |
| 2 | Earnings, dashboards (vendor, driver, manager) | Totals, weekly charts and "today" figures computed by downloading orders and adding them up on the phone. | Cost and memory grow with history; the Manager dashboard's "Today's GMV" actually summed every order ever. |
| 3 | Customer Home / Search | Streamed **every** active vendor, **every** product, **every** review and **every** coupon on the platform, and every live promotion, then filtered by the territory *name*. | ~10,500 documents per Home open with only 200 vendors (§8). |
| 4 | Trending searches | Counted dish names from the customer's own orders on the phone (rules already limit customers to their own orders, so it was never "trending"). | Wrong and grows with history. |
| 5 | Ratings | Every screen showing a star rating streamed the whole `reviews` collection and averaged it. | Grows with every review on the platform. |
| 6 | `rebuildStatement` (functions/ledger.js) | On **every delivery**, read the territory's **entire** ledger and transfer history. | ~4 reads × every delivered order in the territory's history, per delivery. Measured: ~4,400 reads for one delivery with 10,000 orders on the platform, growing with every delivery (§8). |
| 7 | Driver live location | Written onto the **order** every 4–30 s. Each write ran **two** order triggers (`postOrderLedger` read the pricing doc each time) and re-sent the whole order to every listener of it (customer, vendor's and Manager's all-orders lists). | ~150 extra order writes, ~300 function runs and ~750 listener reads per delivery. |
| 8 | `onOrderStatusChange` | `personal_notifications` created with `.add()` (a repeated trigger made duplicates); one notification **document per active driver** for every accepted order; pushes to `account_<id>` topics anyone could subscribe to; driver topic named after the territory *name*. | Duplicates, unbounded fan-out, private pushes on guessable topics. |
| 9 | `sweepExpiredPromotions` | No region (deployed to `us-central1`); read every active promotion; committed 400-update batches in parallel with `Promise.all`, so one failed batch failed the run half-applied, with no retry. | Partial failures, wrong region. |
| 10 | QuickyAdmin | 10 screens streamed **every order on the platform**; the dashboard streamed **every customer** to count them; financial and manager reports added up all orders on the device. | One admin session = the whole database. |
| 11 | Indexes | 7 composite indexes; none for the role-scoped order queries a scaled app needs. | Queries would fail in production once written. |
| 12 | Listener lifetimes | All 25 Firestore stream providers were deliberately non-`autoDispose` (`firestore_stream_reset.dart`), so every screen's listener stayed open for the whole session. | Listeners and memory accumulate as the user navigates. |

## 2. Modified data providers

### Foodie-Bell (`lib/data/providers/`)

| Provider | Before | After |
|---|---|---|
| `firestoreOrdersProvider` | All orders the role can read, live, forever | **Removed.** Replaced by the three below. |
| `activeOrdersProvider` (new) | — | Live; **only in-progress orders** (`status in [placed, vendorAccepted, driverAssigned, pickedUp]`) of the customer / vendor / driver / Manager's territory, plus a driver's open offers in their territory. A small, bounded set at any moment. |
| `orderHistoryProvider(filter)` (new) | — | `autoDispose` `StateNotifier`: **one-time reads, 20 orders per page**, newest first, `startAfterDocument` for the next page. Filters: all / finished / delivered / cancelled. |
| `todaysOrdersProvider` (new) | — | `autoDispose`, live, orders placed since midnight (vendor dashboard). |
| `orderCountProvider(filter)` (new) | — | Server-side `count()` (one read per 1,000 orders) — driver history totals. |
| `orderByIdProvider` | live, never disposed | `autoDispose`. |
| `driverPositionProvider` (new) | position read off the order | `autoDispose`, live, `order_tracking/{orderId}`. |
| `earnings_provider.dart` (new) | — | `myEarningsDaysProvider(days)`, `myEarningsTotalsProvider`, `territoryTodayStatsProvider` — server read models (§3). |
| `firestoreVendorsProvider` | every active vendor (customers/drivers/vendors) | Customer: active vendors **of the territory being browsed**, by `territoryId`. Driver: of their own territory. Vendor: **their own record only**. Manager: unchanged (their territory). `liveVendorAccountProvider` falls back to a one-document read for a shop outside the scope (opened from an old order). |
| `firestorePromotionsProvider` | every live promotion | Live promotions of the browsed / own territory (`status`, `territoryId`); Manager: their territory's. |
| `firestoreCouponsProvider` | every coupon | Customer: unexpired coupons of the browsed territory (`territoryId`, `endAt > now`). Vendor: their own. |
| `allProductsProvider` | every product | **Removed.** `catalogIndexProvider(territoryId)` reads the territory's 4 index shards; `productByIdProvider` loads one product's image only for a search result on screen. |
| `vendorProductsProvider` | live, never disposed | `autoDispose` (only while a catalogue is on screen). |
| `firestoreReviewsProvider` | every review | **Removed.** `vendorReviewsProvider(id)` / `driverReviewsProvider(id)` (latest 50) and `reviewForOrderProvider(orderId)` (one document). Averages and counts come from the server-kept `rating` on the vendor/driver record. |
| `trendingDishesProvider(territoryId)` (new) | — | One document, `trending/{territoryId}`. |
| `globalProductsProvider` | live, never disposed | `autoDispose`. |
| `browsingTerritoryIdProvider` (new, `selected_territory_provider.dart`) | screens compared territory **names** | The ID of the territory a customer browses; every storefront query uses it. |

Screens moved off whole-history data (20): customer Home, Search, My Orders, Transactions, Help, Order detail (review), storefront, public reviews, vendor card; vendor Dashboard, Order queue (Active live + History paged), Earnings, Reviews, coupon creation; driver Home, Earnings, History, Reviews, Profile, location tracker; Manager Dashboard, Order oversight, Territory earnings, Daily settlement. Riverpod lifecycles: the four session-wide providers kept alive are small and bounded (in-progress orders, the account's own scoped lists); everything a single screen needs is `autoDispose`, so leaving the screen cancels its listener. `firestore_stream_reset.dart` invalidates the new providers on every sign-in/sign-out, as before.

### QuickyAdmin (`lib/data/providers/admin_read_models_provider.dart`, new)

| Need | Before | After |
|---|---|---|
| Dashboard today's orders / GMV / Quicky share | every order | `territory_daily_stats` for today (one document per territory) |
| 5-day GMV trend | every order | `territory_daily_stats` of the last 5 days |
| Active customers count | every user document | `count()` on the server |
| Financial reports, Manager reports, wallets | every order | `territory_totals` (one per territory) summed; `TerritoryReport` money getters read them |
| Settlement oversight | every order | `earnings_totals` of vendors (one per vendor) |
| Order list | every order | the latest 200, or the latest 200 of one territory (by ID) |
| Vendor / customer / Manager detail | every order, filtered | that vendor's / customer's / territory's latest 200 |
| Transactions | every order, filtered by date | orders in the date range, by `placedAt`, at most 500 |
| Vendor delete guard | every order | that vendor's orders, read when delete is pressed |

## 3. New query patterns and server read models

**Rule: no screen subscribes to a collection that grows with time.** Live listeners are kept for things that change while you look and are small (in-progress orders, offers, the order you're tracking, a few aggregate documents). History is paged one-time reads. Totals are server documents.

| Read model | Written by | Content | Read by |
|---|---|---|---|
| `earnings_daily/{party}_{day}` | `postOrderLedger`, **in the same transaction** as the `order_delivered` ledger entry | a Vendor's / Driver's / Manager's orders and earnings for a settlement day (vendor: item value, commission, COD/UPI totals, weekday) | vendor, driver, Manager earnings screens |
| `earnings_totals/{party}` | same transaction | running totals | vendor dashboard/earnings, Manager territory earnings, QuickyAdmin |
| `territory_daily_stats/{t}_{day}` | same transaction | delivered orders, customer total, item value, delivery fees, commission, Manager/Quicky shares, vendor/driver entitlements | Manager dashboard, QuickyAdmin dashboard |
| `territory_totals/{t}` | same transaction | running totals of the above | QuickyAdmin reports |
| `trending_daily/{t}_{day}` | same transaction | dish quantities (server-only) | `refreshTrendingSearches` |
| `trending/{t}` | `refreshTrendingSearches` (hourly) | top 8 dishes of the last 7 days, **only dishes ordered ≥3 times** (no single order is revealed); not rewritten when unchanged | customer Home and Search |
| `catalog_index/{t}_{0..3}` | `onProductWritten` (re-reads the product, so retries and out-of-order events converge); `rebuildCatalogIndex` callable; vendor territory moves | every product of the territory: name, vendor, price, veg, in stock, sub-category | Search, Food trending filter, Pure Veg filter |
| `vendors/{id}.rating`, `drivers/{id}.rating` | `onReviewWritten` — server `count()` + `average()` aggregation, idempotent | `{average, count}` | every star rating |
| `order_tracking/{orderId}` | opened by `claimDelivery` / `reassignDriver`, closed on delivery / release / return; the Driver may move only `latitude`, `longitude`, `updatedAt` | live position + who may read it | customer map |
| `statement_queue/{t}_{day}` | `postOrderLedger` | "this statement needs rebuilding" | `rebuildQueuedStatementsJob` (every 10 min) |

**Not a second source of truth.** All ledger-derived read models are written in the one transaction that creates the `order_delivered` entry; a repeated trigger finds the entry and writes nothing (tested). `reconcileAggregates` (nightly, 23:15 IST) recomputes yesterday's `earnings_daily`, `territory_daily_stats` and `trending_daily` from the ledger, checks every running total against a server-side sum of its days, logs any difference as an error and corrects it from the ledger. `reconcileTerritoryDay` (Super Admin callable) does the same for any day on demand.

**Daily statements** (`functions/ledger.js`):
- A statement now reads **only its own day** (plus still-open items: unacknowledged/disputed transfers, unadjusted COD shortfalls); opening balances are the previous statement's closing balances. A change to an earlier day (a late acknowledgement, an adjustment) is carried through every later statement (tested).
- After a delivery the statement is **queued**, and rebuilt once every 10 minutes; payments, acknowledgements, adjustments and the Manager opening Daily Settlement (`generateDailySettlement`) still rebuild immediately — the Manager's screen always shows a fresh statement.
- `reconcileStatements` (weekly, Sunday 03:00 IST) compares each territory's latest statement with a full recomputation from the whole ledger (the old algorithm, kept as `fullStatement`) and, on any difference, logs an error and rebuilds the chain.
- The statement logic itself (`buildStatement`) is the Phase 2 logic unchanged; all 35 Phase 2 settlement tests pass against it.

## 4. Territory data model

- **`territoryId` is the territory's Firestore document ID** (e.g. the auto-ID of "Chityal, Nalgonda"). It is already stable and already in the custom claims, the rules, every Phase 1/2 record and every new read model, so it was **not** renamed to `territory_chityal`: renaming would mean migrating every vendor, driver, Manager, order, ledger entry and claim for no functional gain. Display names are never used for authorization or querying any more (the last uses — customer vendor/promotion/search filters, Manager screens, the drivers' push topic — now use the ID).
- Every order carries a trusted `territoryId` copied from the vendor by `placeOrder` / `acceptListOrder` (Phase 2); clients cannot write orders.
- Coupons now carry `territoryId` (rules require the vendor's own, from the claim); `migrate-phase3.js` backfills existing ones.
- Access per role, enforced by the rules (tested in `tests/rules/firestore.test.mjs`):

| Role | Reads |
|---|---|
| Customer | own orders (in progress live, history paged), own cart/addresses, active vendors + live promotions + unexpired coupons + product index + trending of the browsed territory, own order's tracking |
| Vendor | own record, own orders, own catalogue, own coupons/promotions, own `earnings_*`, own reviews list |
| Driver | own deliveries, open offers in own territory, own `earnings_*`, vendors of own territory, own tracking writes |
| Manager | own territory's orders, vendors, drivers, statements, `territory_daily_stats`/`territory_totals`, territory parties' earnings, tracking |
| Super Admin | everything; QuickyAdmin reads per-territory summaries and bounded order lists |

## 5. Required indexes (`QuickyAdmin/firestore.indexes.json`)

34 composite indexes, each from an implemented query shape:

| Collection | Fields |
|---|---|
| orders | (userId, status) · (userId, placedAt↓) · (userId, status, placedAt↓) — same three for **vendorId**, **driverId**, **territoryId** |
| vendors | (status, territoryId) |
| promotions | (status, territoryId) · (status, startDate) |
| coupons | (territoryId, endAt) |
| reviews | (vendorId, createdAt↓) · (driverId, createdAt↓) |
| ledger_entries | (territoryId, settlementDay) · (territoryId, kind, settlementDay) · (parties ∋, settlementDay↓) |
| settlement_transfers | (territoryId, settlementDay) · (territoryId, status, settlementDay) · (parties ∋, settlementDay↓) |
| daily_settlements | (territoryId, settlementDay↓) · (territoryId, settlementDay↑) |
| earnings_daily | (party, settlementDay↓) · (territoryId, role, settlementDay↓) |
| territory_daily_stats | (territoryId, settlementDay↓) |
| trending_daily | (territoryId, settlementDay) |
| device_tokens | (accountId, updatedAt↓) |
| personal_notifications, notification_broadcasts | unchanged |
| global_products | (category, name) |

17 single-field **exemptions** for large maps/arrays that are never queried (the product index map, dish counts, the order `items` array, the ledger `money` snapshot, the statement's order rows and balance maps) — they cut index writes and storage on every update.

One deployment source, as since Phase 1: `QuickyAdmin/firebase.json` deploys rules, indexes and functions. It now also has an `emulators` block, so the test commands in `tests/*/package.json` work from the repo.

## 6. Cloud Functions optimization

| Function | Change |
|---|---|
| `postOrderLedger` | Exits on the first check unless the write is a delivery or a refund (no pricing read on other writes). Delivery posted in **one transaction**: checks the `order_delivered` entry, then creates all entries and updates all read models — exactly once on retries or duplicate events. `retry: true` (safe: idempotent). Statement queued, not rebuilt. |
| `rebuildStatement` | Day-only reads, carry-forward, cascade (§3). |
| `rebuildQueuedStatementsJob` (new) | Every 10 min; deletes a queue mark only if nothing re-queued it meanwhile (`lastUpdateTime` precondition). |
| `reconcileStatements`, `reconcileAggregates`, `reconcileTerritoryDay` (new) | Ledger reconciliation (§3). |
| `onOrderStatusChange` (moved to `notifications.js`) | Exits unless the status changed to a notified status. Deterministic notification IDs `{order}_{status}_{recipient}` created with `create()` — a repeated trigger sends nothing twice. Device-token delivery (§7). No per-driver documents. Manager lookup cached 5 minutes per instance. Still takes names from the account documents (Phase 1 rule, regression-tested). |
| `onReviewWritten`, `onProductWritten`, `rebuildCatalogIndex`, `refreshTrendingSearches`, `refreshTrendingNow` (new) | Read models (§3). `onProductWritten` ignores edits that don't change the index (description, image, tax). `retry: true` where idempotent. |
| `sweepExpiredPromotions` (moved to `promotions.js`) | Region `asia-south1`. Reads only active promotions that started ≥1 day ago, **paged 500 at a time**. Writes through a `BulkWriter` (batched, throttled, each update retried up to 3 times). Throws if any update finally failed, so Cloud Scheduler retries (`retryCount: 2`). Re-running is harmless. |
| `claimDelivery`, `reassignDriver`, `resolveDeliveryIssue`, `confirmDelivery` | Open/close `order_tracking`. |
| Driver location | Moved off the order (§1 #7): position updates no longer run any order trigger. The app also writes at most once per 10 s (plus the 30-s heartbeat). |
| `vendor` claims trigger | Moves a vendor's catalogue entries when its territory changes. |

All functions are in `asia-south1` except `validateUpload`, which must run in the bucket's region (`STORAGE_REGION`, unchanged from Phase 1). 49 functions load. Concurrency: v2 defaults (80 concurrent requests per instance) are kept; no `minInstances` (cost), no `maxInstances` cap was set, because there is no load-test evidence to size one (see §11).

## 7. Notification improvements

- **Personal pushes go to device tokens, not topics.** `registerDevice` (callable) files the device's FCM token under the **verified** caller (`device_tokens/{sha256(token)}`, server-only). The same device signing in as someone else moves the token to them; an account keeps at most 5 devices (oldest dropped), which bounds every send. Sign-out deletes the token on the device; the server drops tokens FCM reports as unregistered/invalid.
- The app unsubscribes once from the old `account_<id>` topic on sign-in.
- **No duplicates:** one deterministic notification document per recipient per step, created once; the push is sent only when the document was newly created.
- **No unbounded fan-out:** the "new delivery available" ping is one topic message to `drivers_<territoryId>` (shop name only, no customer data — the offer itself is read from Firestore under the rules), deduplicated per acceptance. The per-driver notification documents are gone.
- Territory broadcasts (`all_users`, `territory_<id>`) are unchanged.
- **Not verifiable in the emulator:** actual FCM delivery and its delay (no FCM emulator). Manual check on a staging project: §12 step 9.

## 8. Before-and-after performance results

**Measured** on the Firestore emulator with synthetic data (`QuickyAdmin/tests/perf/perf.mjs`), never the real project: 10 territories, 200 vendors, 10,000 products, 150 drivers, customers = orders ÷ 10 (min 50), 90 days of orders (95% delivered), 4 ledger entries per delivered order, reviews on 25% of delivered orders, a statement per territory per day. Each screen's old query shapes are run against its new ones, for the busiest customer, vendor, driver and territory in the data. **Documents read is exactly what Firestore bills for these queries.** Times are emulator times on one Windows PC — use them to compare old against new, not as production latency. "Before" counts only the initial load; the old listeners then also re-sent every changed document for the rest of the session.

| Screen / operation | 100 orders | 1,000 orders | 10,000 orders |
|---|---|---|---|
| Customer home + search (open once) | 10,484 → **57** reads<br>3,452 → 95 KB<br>791 → 46 ms | 10,715 → **71** reads<br>3,521 → 108 KB<br>858 → 99 ms | 12,968 → **71** reads<br>4,112 → 109 KB<br>849 → 1,147 ms |
| Customer "My orders" (first screen) | 6 → **7** reads<br>6 → 6 KB<br>7 → 11 ms | 22 → **21** reads<br>21 → 19 KB<br>32 → 47 ms | 50 → **21** reads<br>47 → 19 KB<br>227 → 717 ms |
| Vendor dashboard | 232 → **4** reads<br>79 → 0 KB<br>25 → 10 ms | 454 → **4** reads<br>140 → 1 KB<br>35 → 46 ms | 2,778 → **4** reads<br>797 → 0 KB<br>194 → 801 ms |
| Vendor earnings | 4 → **5** reads<br>4 → 4 KB<br>9 → 17 ms | 11 → **11** reads<br>10 → 10 KB<br>16 → 14 ms | 110 → **21** reads<br>104 → 19 KB<br>196 → 215 ms |
| Driver home | 233 → **27** reads<br>79 → 7 KB<br>33 → 15 ms | 457 → **30** reads<br>142 → 9 KB<br>46 → 43 ms | 2,837 → **30** reads<br>852 → 8 KB<br>194 → 732 ms |
| Driver earnings | 4 → **8** reads<br>4 → 4 KB<br>8 → 9 ms | 13 → **24** reads<br>12 → 14 KB<br>20 → 25 ms | 168 → **44** reads<br>158 → 22 KB<br>192 → 197 ms |
| Manager dashboard + oversight | 48 → **50** reads<br>20 → 20 KB<br>12 → 15 ms | 151 → **58** reads<br>117 → 29 KB<br>33 → 39 ms | 1,193 → **63** reads<br>1,100 → 34 KB<br>252 → 690 ms |
| Statement rebuild (per delivery, server) | 49 → **6** reads<br>16 → 0 KB<br>14 → 25 ms | 457 → **9** reads<br>154 → 1 KB<br>80 → 77 ms | 4,397 → **61** reads<br>1,488 → 19 KB<br>1,116 → 922 ms |
| Super Admin dashboard + reports | 150 → **115** reads<br>97 → 96 KB<br>20 → 24 ms | 1,100 → **244** reads<br>947 → 195 KB<br>120 → 44 ms | 11,000 → **261** reads<br>9,485 → 198 KB<br>1,487 → 183 ms |

Driver offer latency (listener sees a newly accepted order; emulator, 15 runs): 100 orders: median 7 ms, p90 9 ms · 1,000 orders: median 15 ms, p90 30 ms · 10,000 orders: median 168 ms, p90 210 ms. (Emulator times grow with the total data held in memory; the offer query reads only that territory's open offers at every size.)

Dataset sizes: 100 orders → 388 ledger entries, 50 customers · 1,000 orders → 3,816 ledger entries, 100 customers · 10,000 orders → 37,948 ledger entries, 1,000 customers; always 10,000 products, 200 vendors.

**100,000 orders: not measured.** On this PC the emulator needed 8 minutes just to load the ~500,000 synthetic documents and then ran out of time/memory; the read counts above grow linearly with history for every "before" shape and stay flat for every "after" shape, so at 100,000 orders the "before" figures are about 10× the 10,000 column. Emulator **times** for some "after" queries rise at 10,000 orders because the emulator scans in memory instead of using indexes like production; the **reads** column is the billing-accurate one.


**Not measured** (no tool for it in the emulator): mobile memory (the payload sizes above are a proxy — the old Home held ~3.5 MB of decoded documents), real-network transfer and latency, FCM delay, cold app start. These need a device run on a staging project (§12).

## 9. Estimated Firebase costs and assumptions

**These are estimates, not measurements**, built from the code paths and the measured per-screen reads above.

Assumed prices (Firestore Standard list prices; **check the Firebase pricing page for `asia-south1`, which can differ**): reads $0.06 / 100k, writes $0.18 / 100k, deletes $0.02 / 100k; free 50k reads, 20k writes per day. Cloud Functions (2nd gen): $0.40 per million invocations after 2 million free per month, plus compute — assumed ~$0.0000074 per invocation (≈300 ms on 1 vCPU / 256 MiB). FCM is free.

Per completed COD order (Phase 3):

| Item | Estimate | Basis |
|---|---|---|
| Writes | ~105 | order lifecycle 17 (order, idempotency key, codes, events, status changes, tracking open/close) · ledger 4–5 entries + 9 read-model updates · 1 queue mark · 14 notification docs · ~60 tracking positions (10 min moving, ≤1 per 10 s) |
| Reads | ~250–350 | callables ~37 (quote, place, accept, claim, pickup, cash, deliver) · triggers ~4 · notifications ~27 (names, Manager, token lookups) · order listener updates ~40 (≈8 changes × 5 watchers) · customer map ~60 · statement rebuilds amortised ≤ 2.5 × min(deliveries/day, 72) ≤ 180 |
| Function invocations | ~28 | ~9 callables + 2 order triggers × ~9 order writes + codes |
| Customer browsing | ~70 reads per Home open (measured) + ~50 per storefront | assume 3 browsing sessions per order → ~400 reads |

**≈ $0.85 per 1,000 completed orders** (reads ~0.7 M ≈ $0.42, writes ~0.1 M ≈ $0.19, functions ≈ $0.22), before free tiers, plus Storage egress for product images (not measured; ~$0.12/GB; a 50-product storefront of ~60 KB images is ~3 MB uncached). The same activity **before Phase 3** is dominated by Home opens (~10,700 reads each, measured → ~32,000 reads per order at 3 sessions, ≈ $19 per 1,000 orders) and by statement rebuilds that grow with history (measured ~4,400 reads per delivery at 10,000 orders, ≈ $2.60 per 1,000 orders at that size and rising linearly); the driver-location churn adds ~750 listener reads and ~300 function runs per delivery. Before Phase 3, cost per order rose with every order ever placed; it is now flat.

Per active customer: ~70 reads to open Home (vs ~10,500), ~7 for My Orders' first screen, a page of 20 per scroll. Per Manager dashboard session: ~25–60 reads (today's figures, in-progress orders, first history page, vendors and drivers of the territory) vs every order of the territory. Per Super Admin dashboard: ~T × 6 documents + 200 recent orders vs the whole database.

**Monitoring recommended (needs the owner, not done):**
1. **Budget alerts** — Google Cloud Billing → Budgets & alerts: a monthly budget for the project with email alerts at 50 / 90 / 100 % and a forecast alert. **A budget alert does not stop billing**; it only notifies. To cap spend automatically, a budget → Pub/Sub → function that disables billing is possible but takes the whole app offline — not recommended without a deliberate decision.
2. **Usage dashboards** — Firebase console → Firestore → Usage (reads/writes/deletes per day), Functions → Usage (invocations, errors), Cloud Monitoring alert policies on `firestore.googleapis.com/document/read_count` and function error rates.
3. **Anomaly alerts** — a Cloud Monitoring alert when daily reads exceed ~2× the trailing weekly average; Billing's anomaly detection on the account.
4. **Log-based alerts** on `reconcileAggregates:` / `reconcileStatements:` errors (a read model or statement drifted from the ledger) and `catalog_index … add shards`.

## 10. Regression test results (actually run, 2026-10-28, Firebase Emulator Suite)

| Suite | Result |
|---|---|
| `orders.test.mjs` — Phase 2 end-to-end (35) + Phase 3 (13: read models, duplicate events, carry-forward vs full recomputation, late acknowledgement, statement queue, reconciliation repair incl. running totals, tracking, ratings, catalogue index incl. vendor move, trending threshold, notification dedupe, device tokens, promotion sweep) | **48 passed, 0 failed** |
| `functions.test.mjs` — Phase 1 regression (incl. notification text from account docs) | **32 passed, 0 failed** |
| `migration.test.mjs` — Phase 1 migration | **11 passed, 0 failed** |
| `migration3.test.mjs` — Phase 3 migration (dry run, apply, re-run) | **3 passed, 0 failed** |
| `money.test.mjs` — unit | **13 passed, 0 failed** |
| Firestore rules (Phase 1–3; new: tracking, read models, territory totals, tokens, coupon territory, scoped queries per role) | **210 passed, 0 failed** |
| Storage rules | **59 passed, 0 failed** |
| `flutter analyze` | Foodie-Bell: 3 pre-existing style infos only · QuickyAdmin: no issues |
| `flutter test` (Foodie-Bell smoke test) | 1 passed |

Baseline before Phase 3: the orders suite was 34/35 — one timing failure (`createOrderCodes` queued behind ~1.6 s FCM attempts per notification); with token-based pushes it passes. Bugs found by the Phase 3 runs and fixed: notifications briefly took names from the order (Phase 1 test caught it; reverted to account documents); a statement for the next day could carry a stale opening balance while today's was still queued (settlement callables now process the territory's queue first); the perf harness's latency listener raced its first snapshot.

Regression requirements → evidence: customers see only their orders, vendors only theirs, Managers only their territory, drivers only their deliveries and their territory's offers (rules tests, scoped-query cases); Admin reads every territory (rules + QuickyAdmin read models); pricing unchanged (all Phase 2 pricing tests); settlements unchanged and equal to a full recomputation (reconciliation tests); notifications still sent once per recipient per step (dedupe test; actual FCM delivery not testable in the emulator); search, promotions, coupons, trending work from the territory read models (rules + catalogue/trending tests; UI on devices not yet tested).

## 11. Remaining bottlenecks

- **No production load test.** No concurrency capacity is claimed. The emulator numbers prove the read counts, not throughput under concurrent users; a staged load test against a separate Firebase project is needed before sizing `maxInstances` or promising a number of simultaneous users.
- **Statement rebuild** still reads the day's ledger entries (now at most ~72 times a day per territory). A fully incremental statement (update balances in the posting transaction) would remove it — a Phase 4 candidate, deliberately not done here to keep Phase 2's financial logic unchanged.
- **Statement documents** hold one row per delivered order; above ~5,000 deliveries a day in one territory a statement approaches Firestore's 1 MiB limit.
- **Hot documents:** each territory's `territory_daily_stats`/`territory_totals` and the Manager's earnings documents are updated on every delivery in the territory. Firestore sustains ~1 write/second per document; beyond ~1 delivery per second in one territory they would need sharded counters.
- **Catalogue index shards:** 4 per territory hold roughly 30–40k products; `rebuildCatalogIndex` warns at 700 KB per shard.
- **Vendor storefront** still streams the whole catalogue of the shop being viewed (needed for its category grouping and in-shop search); fine for typical catalogues (tens to a few hundred items), not paginated.
- **QuickyAdmin directories** (users, vendors, drivers, coupons, products, promotions lists) still stream whole collections when those admin screens are open — one admin, rarely; the dashboard no longer does. The customer directory should be paginated before the customer base is large.
- **Legacy beta orders** (no Phase 2 money snapshot) are not in the ledger, so they are not in earnings/totals; they still show in order lists.
- **Customer trending** now counts delivered orders only, platform-wide per territory (before: the customer's own orders, any status).
- The vendor earnings weekday chart and driver/Manager "today" now follow the **settlement day** (after 22:00 counts to the next day), consistent with the statements.

## 12. Deployment and rollback plan

**Deploy (needs your approval at each step; Phase 1 and 2 checklists first, all three phases in one release):**
1. Backup: `gcloud firestore export gs://quickmandi-3b017-backups/pre-phase3`.
2. `firebase deploy --only firestore:indexes` from QuickyAdmin; wait until every index shows *Enabled*.
3. `firebase deploy --only functions` (new functions are additive; Cloud Scheduler jobs are created for the new schedules).
4. `node functions/scripts/migrate-phase3.js` (dry run) → review → `--apply`: coupon territory IDs, catalogue indexes, ratings, tracking for deliveries in progress.
5. Ship the new Foodie-Bell and QuickyAdmin builds (the coordinated release Phase 2 already requires).
6. `firebase deploy --only firestore:rules` (no client writes on orders; new collections).
7. Billing budget + alerts (§9).
8. Watch for a day: Functions errors, `reconcileAggregates` logs, Firestore reads per day.
9. On a staging project with real devices: each role's screens; a push to two devices of one account; sign-out stops pushes; driver offer ping; live map.

**Rollback:**
- Rules: Console → Firestore → Rules → History → previous version.
- Functions: redeploy the previous `functions/` from the backup archive / git; delete new ones with `firebase functions:delete` (`onReviewWritten`, `onProductWritten`, `rebuildCatalogIndex`, `refreshTrendingSearches`, `refreshTrendingNow`, `registerDevice`, `unregisterDevice`, `rebuildQueuedStatementsJob`, `reconcileStatements`, `reconcileAggregates`, `reconcileTerritoryDay`).
- Data: everything Phase 3 writes is additive (read models, index documents, tracking, tokens, ratings, coupon `territoryId`); none of it is a source of truth and it can be left in place or deleted. The ledger and statements keep the Phase 2 shape.
- Apps: previous builds work against the previous rules and functions.
- Code: both working trees as they were before Phase 3 are in the backup archives (§ top).

## 13. Readiness for Phase 4

Phase 3 is **code-complete and emulator-tested**, not deployed, not tried on devices. Before or during Phase 4: device testing of Phases 1–3 on a staging Firebase project; a real load test there; commit the three phases (nothing is committed yet). Phase 4 candidates: incremental daily statements; sharded counters if any territory nears 1 delivery/second; paginated admin directories; image thumbnails (Resize Images extension) to cut Storage egress; Telugu strings for Phase 2/3 screens; CI running `tests/rules`, `tests/functions` and `tests/perf`.

## Files changed

**QuickyAdmin:** `functions/ledger.js`, `notifications.js` (new), `aggregates.js` (new), `promotions.js` (new), `orders.js`, `order_codes.js`, `accounts.js`, `index.js`, `scripts/migrate-phase3.js` (new); `firestore.rules`, `firestore.indexes.json`, `firebase.json`; `tests/functions/orders.test.mjs`, `migration3.test.mjs` (new), `package.json`; `tests/rules/firestore.test.mjs`; `tests/perf/perf.mjs` (new); `lib/data/providers/admin_read_models_provider.dart` (new), `firestore_orders_provider.dart`, `admin_stream_reset.dart`; admin dashboard, order list, financial reports, manager reports, settlement oversight, transactions, manager/vendor/user detail, vendor directory screens.

**Foodie-Bell:** `lib/data/providers/firestore_orders_provider.dart`, `earnings_provider.dart` (new), `trending_provider.dart` (new), `firestore_vendors_provider.dart`, `firestore_drivers_provider.dart`, `firestore_promotions_provider.dart`, `firestore_coupons_provider.dart`, `firestore_products_provider.dart`, `firestore_reviews_provider.dart`, `firestore_global_products_provider.dart`, `firestore_stream_reset.dart`; `lib/data/models/account.dart`; `lib/core/notifications/fcm_topics.dart`, `lib/app.dart`; `features/user/home/selected_territory_provider.dart`; the screens listed in §2; `shared/widgets/driver_live_map.dart`; `features/driver/driver_location_tracker.dart`.
