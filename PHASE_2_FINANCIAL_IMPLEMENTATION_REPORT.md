# Phase 2 Financial Implementation Report — Orders, Payments and Settlements

Date: 2026-10-27 · Firebase project `quickmandi-3b017`
Status: **implemented and tested in the Firebase emulators; nothing committed, nothing deployed.**

Prerequisites: `PHASE_1_SECURITY_REPORT.md` was read and Phase 1 is code-complete (not yet deployed). `ARCHITECTURE_AUDIT_REPORT.md` and the "Quicky Business Model & Daily Settlement SOP" **do not exist** anywhere in either repository or on this machine; the business rules in the Phase 2 prompt (§1) were used as the source of truth.

## Decisions confirmed with the product owner

| Question | Decision |
|---|---|
| COD cash handling | **The rider hands over all cash** to the Manager; the Manager pays the rider's delivery earnings in the daily settlement. |
| GST | **Off for new orders** until tax rules are confirmed. Prices are treated as final; no GST line. The server refuses to switch it on. |
| Razorpay | **Disabled for new orders.** New orders: UPI paid directly to the vendor, or COD. The Razorpay code stays in the repo, unused. |
| Commission base | **10% of item value after the vendor's own coupon.** |
| Settlement cut-off | Defaults to **22:00 IST**, editable by the Super Admin (not final, per the prompt). |
| Photo ("list") orders | Same distance-based delivery fee as normal orders (assumption). |

---

## 1. Order architecture

**Server-authoritative.** The apps send only intent — shop, product IDs and quantities, saved address, coupon, payment method. `placeOrder` reads the catalogue prices, the road distance, the live pricing version and the coupon, computes every amount, and writes the order. Firestore rules give clients **no write on orders** except the assigned Driver's live position.

- **Order ID:** `ORD-` + 8 characters from a 30-symbol alphabet, from a cryptographic RNG, checked for existence inside the creating transaction (replaces `ORD-<ms % 1,000,000>`).
- **Idempotency:** every `placeOrder` carries an `idempotencyKey`; `order_requests/{account}_{key}` maps it to the order, written in the same transaction. Retries and double taps return the same order.
- **Immutable snapshot** on each order: `money` (paise: items, coupon, eligible value, delivery fee, total, commission, Manager share, Quicky share, vendor and driver entitlements) and `pricing` (version, road distance, slab, commission/share basis points, GST flag). Legacy rupee fields (`subtotal`, `deliveryFee`, `total`, …) are filled from the snapshot for existing screens; `platformFee` and `gstAmount` are 0.
- **Status machine** (values unchanged, so older builds can still read orders):
  `placed → vendorAccepted → driverAssigned → pickedUp → delivered`; `placed → rejected | cancelled`; `driverAssigned → vendorAccepted` (Manager releases the Driver); `pickedUp → cancelled` (Manager: delivery failed, returned). Every transition is a callable that checks the caller's role/claims and the current state inside a transaction. Nothing moves a delivered order.
- **Payment state** is separate: `payment.status` = `awaitingVerification → verified → (refundDue)` / `disputed` / `failed` / `unpaidCancelled` for UPI; `payOnDelivery → collected` for COD.
- **Audit trail:** every change appends `orders/{id}/events/{auto}` (type, actor UID, role, account, details, server time).

## 2. Cloud Functions added or modified (`QuickyAdmin/functions/`)

| Module | Function | Purpose |
|---|---|---|
| `money.js` (new) | — | Pure money rules in integer paise; unit-tested. |
| `pricing.js` (new) | `updatePricing` | Super Admin only; validates, writes a new version to `pricing_versions/{v}` and `app_config/pricing`. |
| `routing.js` (new) | — | Road distance via Google Routes API with the server secret `ROUTES_API_KEY`, cached in `route_cache`. |
| `orders.js` (new) | `quoteOrder`, `placeOrder` | Price / create orders. |
| | `submitUpiReference`, `confirmUpiPayment`, `reportPaymentIssue`, `resolvePaymentDispute` | UPI workflow. |
| | `vendorDecision`, `cancelOrder` | Accept/reject (UPI requires verified payment), customer cancel before acceptance; coupon released; refund flagged. |
| | `claimDelivery`, `reassignDriver` | Transactional driver claim; Manager reassignment. |
| | `recordCodCollection` | Driver records the cash actually collected (≤ total). |
| | `reportDeliveryFailure`, `resolveDeliveryIssue` | Failed delivery; Manager's authorised exception (delivered **only with an existing proof photo**, or returned). |
| | `quoteListOrder`, `acceptListOrder` | Photo orders priced and created server-side. |
| `ledger.js` (new) | `postOrderLedger` (trigger) | Posts ledger entries on delivery / refund, idempotently. |
| | `generateDailySettlement`, `recordSettlementTransfer`, `acknowledgeSettlementTransfer`, `proposeSettlementAdjustment`, `decideSettlementAdjustment`, `refreshDailySettlements` (22:30 IST) | Settlement. |
| `order_codes.js` | `confirmPickup`, `confirmDelivery` | Now also record the actor and an audit event; COD delivery requires recorded cash. |
| `index.js` | — | Loads every module, exporting only deployable functions. |

39 functions load (`node -e "require('./index.js')"`).

## 3. Updated financial model

All amounts in **integer paise**. Rounding policy: each percentage is rounded **half-up to the nearest paisa, once**, in the order coupon → commission → Manager share; Quicky's share = commission − Manager share. The parts always sum exactly to the total (enforced by an invariant check that throws).

```
eligibleItemValue = Σ(catalogue price × qty) − vendor coupon
commission        = 10% × eligibleItemValue
managerShare      = 60% × commission        quickyShare = commission − managerShare
vendorEntitlement = eligibleItemValue − commission
deliveryFee       = slab(road distance)     driverEntitlement = deliveryFee
customerTotal     = eligibleItemValue + deliveryFee        (no platform fee, no GST)
```

| Example | Total | Vendor | Manager | Quicky | Driver |
|---|---|---|---|---|---|
| ₹100 item, 2 km | ₹120 | ₹90 | ₹6 | ₹4 | ₹20 |
| ₹40 item, 8 km | ₹90 | ₹36 | ₹2.40 | ₹1.60 | ₹50 |

**Delivery pricing** (global, `app_config/pricing`, versioned): 0–3 km ₹20 · >3–5 ₹30 · >5–7 ₹40 · >7–9 ₹50 · >9–11 ₹60. Beyond the last slab: **checkout is blocked** with the distance and the limit shown. No return-trip fee, no minimum order. Only the Super Admin can change it (QuickyAdmin → Global Pricing, which replaces the old demo "Rebate & Split" screen); Managers see it read-only on their settlement screen.

**Routing proposal (implemented):** reuse the Google Routes API the apps already use for maps, but call it **from the server** with a separate secret key (`ROUTES_API_KEY`, Routes-API-only), mode `TWO_WHEELER`, field mask `routes.distanceMeters`. Results are cached per (vendor, drop-off rounded to ~11 m) for 30 days while the shop doesn't move, so a checkout quote and the order it becomes cost **one** Routes call per new address. If no route can be computed, checkout is **blocked** (never straight-line).

## 4. UPI and COD workflows

**UPI (direct to vendor):**
1. Customer places the order with UPI → `payment.status = awaitingVerification`, the vendor's UPI ID and amount snapshotted on the order.
2. Order screen shows a **payment card**: amount, UPI ID, "Pay with a UPI app" (UPI intent), and a field for the UTR. The UPI app's result is only a hint; any reference is stored as the customer's claim.
3. Vendor taps **"Money received?"**, checks their own account, and confirms (`verifiedByUid`, time) — or reports "Not received". The dialog states that a screenshot is not proof and only money seen in the account counts. Confirmation is single-use.
4. Only then can the vendor **Accept**; Drivers are offered it after acceptance.
5. Disputes (customer or vendor) block acceptance until the territory Manager resolves: *received* (→ verified, or refund due if the order was cancelled meanwhile) or *not received* (→ order cancelled, payment failed).
6. Vendor rejection or customer cancellation after verification → `refundDue`, posted to the ledger as vendor → customer; the vendor records the refund and the customer acknowledges it.

The app states plainly that manual vendor confirmation is not bank-level proof.

**COD (rider hands over all cash):**
1. Vendor accepts; Driver claims (transactionally), picks up with the handover code.
2. At the door the Driver records the cash **actually** collected ("Collected the full amount" / "Customer paid less" → amount). Delivery can't be confirmed before this.
3. Driver confirms with the customer's delivery code.
4. Ledger: Driver → Manager the **full** total (accountable for any shortfall, which is flagged), Manager → Vendor the vendor entitlement, Manager → Driver the delivery fee, Manager → Quicky its share. "Delivered" never means "settled".

**Failed delivery:** Driver reports it (optionally with a photo, stored privately under `delivery_proofs/{order}/`). The Manager marks it returned, or delivered **only if a proof photo exists** (the server checks). A photo alone never completes a delivery.

## 5. Ledger schema

`ledger_entries/{id}` — append-only, server-written, never updated or deleted. Deterministic IDs make duplicate trigger events no-ops (`create()`):

| ID | kind | from → to | amount |
|---|---|---|---|
| `{order}_delivered` | `order_delivered` | — | 0 (carries the full `money` snapshot, cash holder, collected amount, collection status, pricing version, delivered time) |
| `{order}_vendor_commission_and_delivery` | UPI | vendor → manager | commission + delivery |
| `{order}_cod_cash_to_manager` | COD | driver → manager | full customer total |
| `{order}_vendor_payout` | COD | manager → vendor | vendor entitlement |
| `{order}_driver_payout` | all | manager → driver | delivery fee |
| `{order}_quicky_share` | all | manager → quicky | Quicky share |
| `{order}_cod_shortfall` | info | — | total − collected |
| `{order}_refund_due` | refund | vendor → user | customer total |
| `adjustment_{id}` | adjustment | as approved | as approved |

Every entry: `orderId`, `territoryId`, `vendorId`, `driverId`, `userId`, `managerId`, `paymentMethod`, `settlementDay`, `parties` (party keys for per-party queries), `createdAt`, plus actor/approver for adjustments. Party keys: `vendor:<id>`, `driver:<id>`, `manager:<id>`, `user:<id>`, `quicky`.

Other collections:
- `settlement_transfers/{uid}_{idempotencyKey}` — a payment between two parties (UPI ref or cash note), `status: pendingAck → confirmed | disputed`, acknowledged only by the **other** party (who/when stored). This doubles as the **settlement confirmation** (no separate `settlement_confirmations` collection; the acknowledgement lives on the transfer).
- `settlement_adjustments/{id}` — proposed by a Manager or Super Admin, **approved only by the Super Admin**, then posted as a ledger entry.
- `daily_settlements/{territory}_{day}` — the statement (§6).
- `pricing_versions/{v}`, `route_cache/{key}`, `order_requests/{key}` — supporting data (the last two server-only).

## 6. Daily settlement workflow

A settlement day is the IST date, where anything after the cut-off counts towards the next day (`settlementDayFor`; tested across midnight and at the cut-off). For each territory and day, `generateDailySettlement` (also run on every ledger post, transfer, acknowledgement and adjustment, and nightly at 22:30) rebuilds the statement from the ledger:

- completed orders; vendor-wise totals and entitlements; vendor UPI collections; rider COD collections; commission; driver, Manager and Quicky earnings;
- **opening balances** (everything before the day), **payments made** (acknowledged only), payments awaiting acknowledgement, **remaining balances**, **discrepancies** (unadjusted COD shortfalls, disputed payments, territory without a Manager);
- **status:** `disputed` if any discrepancy; `completed` only when every balance is zero through acknowledged transfers and nothing awaits acknowledgement; `partiallySettled` when some payments that day were acknowledged; otherwise `pending`. **Never completed just because the day has passed.** Balances net across all orders in the territory, and unpaid balances carry forward as the next day's opening.

Manager app: **Daily Settlement** (statement, who owes whom, "Got paid"/"Paid" recording, awaiting acknowledgements, problems, read-only pricing, and a *Needs attention* list for payment disputes and failed deliveries); **Settlement History** (real statuses). Vendor and Driver apps: **Settlement payments** (confirm or dispute payments recorded with them). QuickyAdmin: **Quicky Settlements** (confirm Quicky's receipts, approve/reject adjustments).

## 7. Revenue mismatches fixed

| Mismatch | Fix |
|---|---|
| Vendor rebate 10–20% / default 15% | Commission is the global 10% from pricing, snapshotted per order. The vendor `rebatePercent` field is ignored for new orders (kept for history). |
| Hard-coded ₹20 rider earnings (`kDriverFlatPayout`) | Removed; earnings are each order's `driverEntitlement` (the distance-based delivery fee). Driver home, earnings, history and offer screens. |
| Inconsistent 60/40 split | One source: `money.managerShare` / `quickyShare`. QuickyAdmin's `RebateSplit` extension, dashboard and reports now read it. |
| Wrong vendor earnings (`total − rebate` included the driver's fee) | `vendorEntitlement` (goods less commission) on vendor dashboard, earnings and order detail. |
| ₹5 platform fee | Removed from new orders (0); shown only on old orders that had one. |
| Settlement screen showing full commission as Manager income | Manager dashboard shows **today's** 60% share (it summed all days' full commission); territory earnings report uses the 60% share. |
| History auto-"Settled" | History lists server statements with computed statuses. |
| Cart showing GST and a flat ₹20 | Cart shows items only; delivery "by distance, at checkout". |
| QuickyAdmin crashing on `online` payment orders | `PaymentMethod.online` added to its model. |

**Historical beta records are not rewritten.** Orders without a `money` snapshot keep their stored values; the `Order` getters fall back to the old rules (rebate %, 60/40, ₹20 driver payout) and are labelled as such; they are **not** in the ledger. Old `settlement_reconciliations` stay readable but no longer writable.

## 8. Files changed

**QuickyAdmin (backend + admin):** `functions/money.js`, `pricing.js`, `routing.js`, `orders.js`, `ledger.js` (new); `functions/order_codes.js`, `index.js`; `firestore.rules`, `firestore.indexes.json`; `.gitignore`; `tests/functions/money.test.mjs`, `orders.test.mjs` (new), `package.json`; `tests/rules/firestore.test.mjs`; `lib/data/models/order.dart`, `lib/data/providers/firestore_orders_provider.dart`; `lib/features/admin/rebate_config/rebate_config_screen.dart` (now Global Pricing), `settlement/quicky_settlement_screen.dart` (new), `settlement/settlement_oversight_screen.dart`, `reports/manager_reports.dart`, `dashboard/admin_dashboard_screen.dart`, `admin_routes.dart`.

**Foodie-Bell (apps):** new `lib/data/providers/order_actions.dart`, `settlement_provider.dart`, `lib/shared/widgets/upi_payment_card.dart`, `lib/shared/settlement_payments_screen.dart`, `lib/features/vendor/orders/vendor_order_actions.dart`; changed `lib/data/models/order.dart`, providers (`firestore_orders_provider`, `firestore_list_order_requests_provider`, `firestore_stream_reset`), removed `firestore_settlement_reconciliation_provider.dart`; screens: checkout, order success, order detail, cart, vendor order queue/detail/earnings/dashboard, driver offer/cash collection/delivery confirm/home/earnings/history, manager dashboard/territory earnings/daily settlement/settlement history, routes (vendor, driver).

No financial formula was changed outside what Phase 2 specified.

## 9. Database migration

No data needs rewriting. Additive only:
- Indexes: `ledger_entries` (territoryId+settlementDay; parties+settlementDay), `settlement_transfers` (same two), `daily_settlements` (territoryId+settlementDay).
- `app_config/pricing` is created on the first `updatePricing`; until then the built-in default (identical to the agreed table) applies and orders record `pricing.version = 1`.
- **Cut-over for orders in flight:** orders placed by the old app have no `money` snapshot and won't enter the ledger. Before deploying the Phase 2 rules, either let in-flight orders finish (recommended: announce a short ordering pause), or settle them manually as before; `beta-inventory.js` reports how many are in flight.
- Vendor `rebatePercent`, `settlement_reconciliations`, and legacy order money fields are left untouched.

## 10. Test results (actually run, 2026-10-27, Firebase Emulator Suite)

| Suite | Result |
|---|---|
| `money.test.mjs` (unit, Node test runner) | **13 passed, 0 failed** |
| `orders.test.mjs` (Phase 2 end-to-end: Auth + Firestore + Functions + Storage, real phone sign-ins) | **35 passed, 0 failed** |
| `functions.test.mjs` (Phase 1 regression) | **32 passed, 0 failed** |
| `migration.test.mjs` (Phase 1 regression) | **11 passed, 0 failed** |
| Firestore rules (updated for Phase 2) | **165 passed, 0 failed** |
| Storage rules | **59 passed, 0 failed** |
| `flutter analyze` | Foodie-Bell: 3 pre-existing style infos only · QuickyAdmin: no issues |

Required scenarios → tests: ₹100+₹20 and ₹40+₹50 (both levels); every slab boundary incl. 3.000/3.001 km and >11 km blocked (unit + server); coupon and rounding (unit + server, incl. 3×₹33.33); GST off; **two drivers claiming at once → exactly one wins**; **duplicate submissions in parallel → one order**; **duplicate trigger events → no duplicate ledger entries**; UPI not received → dispute → cancelled; vendor rejects after payment → refund due → refund acknowledged; COD cash not recorded → delivery refused; COD shortfall → disputed until admin-approved adjustment; rider not settling → carried into next day's opening; partial settlement → `partiallySettled`; duplicate transfer / duplicate acknowledgement refused; cancellation releases the coupon; settlement across midnight and cut-off (unit); territory separation (manager, driver, transfers); pricing versioning (old orders keep v1); delivery override requires a proof photo; **reconciliation: collections = vendor + Manager + Quicky + driver entitlements, all balances zero after acknowledged payments → `completed`**.

Bugs found by the tests and fixed: none in the money rules; one test expectation was wrong (a COD rider's carried balance nets their delivery fee: ₹100, not ₹120) and one test needed to wait for the ledger trigger (statements are eventually consistent).

Not covered by automated tests: real Google Routes responses (seeded cache in tests), FCM delivery, Flutter UI flows on devices.

## 11. Known limitations

- **UPI verification is manual** (vendor's own check). There is no bank-level proof; disputes go to the Manager. A gateway or bank-statement reconciliation is a later decision.
- Photo orders: the customer's "paid" is a claim; the vendor confirms receipt when accepting.
- Refunds are tracked in the ledger and settled by an acknowledged transfer; the order's `payment.status` stays `refundDue` (it isn't flipped to `refunded`).
- Managers can't yet propose adjustments from the app (the callable exists and is tested; the screen points them to the Super Admin).
- New customer/vendor/driver text in Phase 2 screens is **English only** — Telugu translations still to be added to `app_te.arb`.
- `ROUTES_API_KEY` must be set and the Routes API enabled; `TWO_WHEELER` routing availability for the region should be confirmed on the live API. Without a route, checkout is blocked by design.
- The nightly statement refresh runs at a fixed 22:30 IST even if the cut-off is changed (statements also refresh on every event).
- Old app builds stop working once these rules deploy (they wrote orders directly) — a coordinated release is required.
- GST and invoicing: off; needs a tax adviser's confirmation before enabling (Phase 3 candidate).

## 12. Deployment and rollback plan

**Deploy (needs your approval at each step):**
1. Phase 1 checklist first (claims functions, Super Admin, Phase 1 migration).
2. Google Cloud: enable **Routes API** for a server key restricted to it; `firebase functions:secrets:set ROUTES_API_KEY`.
3. From QuickyAdmin: `firebase deploy --only functions` (new functions are additive; old builds keep working under the Phase 1 rules).
4. `firebase deploy --only firestore:indexes`; wait for the indexes to finish building.
5. Ship the new Foodie-Bell and QuickyAdmin builds; ask testers to update; announce a short ordering pause.
6. Let in-flight orders finish (or settle them manually).
7. `firebase deploy --only firestore:rules` (Phase 2 rules: no client order writes).
8. Super Admin opens **Global Pricing**, reviews the default table, and saves it once (creates version 2 with a reason) — optional; version 1 = the same table.
9. Watch the first day's statements; Managers record and parties acknowledge payments.

**Rollback:**
- Rules: Console → Firestore → Rules → History → restore the Phase 1 version (old builds then place orders again).
- Functions: redeploy the previous `functions/` from git; new callables can be deleted with `firebase functions:delete`.
- Data: the ledger, statements and transfers are additive; nothing existing was modified. Orders created by Phase 2 remain valid orders for old screens (legacy fields are filled).
- Pricing: `updatePricing` with the previous values (every version is kept in `pricing_versions`).

## 13. Readiness for Phase 3

Phase 2 is **code-complete and emulator-tested**; it should be **reviewed and tried on devices** (customer, vendor, driver, manager, admin) against a staging project before Phase 3. Suggested Phase 3 inputs: GST/invoicing rules from a tax adviser; whether to add a payment gateway or bank reconciliation for UPI; Telugu strings for the new screens; a Manager UI for proposing adjustments; CI running `tests/functions` and `tests/rules`.
