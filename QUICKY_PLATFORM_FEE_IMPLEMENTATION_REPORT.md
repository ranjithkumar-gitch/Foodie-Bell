# Quicky — Platform Fee Implementation Report

Date: 2026-10-28 · Firebase project `quickmandi-3b017`
Status: **implemented and tested on the Firebase Emulator Suite. Nothing is committed or deployed.**

## 1. Existing implementation findings

| Checked | Finding |
|---|---|
| Hard-coded ₹5 fee in `checkout_payment_screen.dart` | **Already removed in Phase 2.** Checkout showed only server-quoted amounts, and its comment said "There is no platform fee". No client code anywhere computes a fee, so there's no risk of charging it twice. |
| Order total calculation | Server-authoritative: `QuickyAdmin/functions/money.js` `computeOrderMoney` (integer paise), called by `placeOrder`, `quoteOrder` and `quoteListOrder`. New orders were written with `platformFee: 0`. |
| Display of an old fee | `order_detail_screen.dart` (customer), `vendor_order_detail_screen.dart` and the QuickyAdmin order card already show a "Platform fee" line when `order.platformFee > 0`, so they were reused. |
| Super Admin settings | `app_config/pricing` + `pricing_versions/{v}` + the `updatePricing` callable (Super Admin claim), edited on the Global Pricing screen (`rebate_config_screen.dart`). The fee follows the same pattern. |
| Rules | `app_config/{doc}` is already public-read with **no client write** (not even the admin client), so a new `app_config/platform_fee` doc is protected without any rule change. |
| Phase 1 and 2 foundations | Implemented in the repo (server orders, idempotency, ledger, statements, claims), **not deployed**. No insecure client workaround was needed. |

## 2. Business rules implemented

- A fixed fee per order, global across all territories, **default ₹5.00, on**. This applies until the Super Admin saves a config.
- Only the Super Admin can enable, disable or change it (server-checked claim). Every role can read it; nobody can write it from an app.
- The fee is added to the customer total. It is **outside the commission base**, not part of the Driver's fee, and not shared with the Manager. It is **100% Quicky's**.
- Example (₹100 item, 2 km, ₹5 fee): customer pays **₹125**.

| Party | Amount |
|---|---|
| Vendor | ₹90 |
| Driver | ₹20 |
| Manager | ₹6 |
| Quicky commission share | ₹4 |
| Quicky platform fee | ₹5 |
| **Quicky total** | **₹9** |

  Tested exactly (unit test "the ₹125 example").
- Validation (server): `enabled` must be a boolean; amount is whole paise, from 0 up to ₹100 (a typo guard), never negative; a reason is required for every change.

## 3. Firebase schema changes

| Path | Fields | Written by | Read by |
|---|---|---|---|
| `app_config/platform_fee` (new) | `enabled`, `amountPaise`, `feeType: "fixed"`, `currency: "INR"`, `scope: "global"`, `revenueOwner: "company"`, `version`, `updatedAt`, `updatedBy` (UID), `updatedByEmail`, `reason` | `updatePlatformFee` only | everyone (existing `app_config` rule) |
| `platform_fee_versions/{version}` (new) | the same record for every version ever used — the **audit trail** | `updatePlatformFee` only | Super Admin only (new rule) |
| `orders/{id}.money.platformFee` | paise charged | `placeOrder`, `acceptListOrder` | as orders |
| `orders/{id}.money.quickyRevenue` | `quickyShare + platformFee` | same | as orders |
| `orders/{id}.pricing.platformFee` | snapshot `{enabled, amountPaise, version}` at order creation | same | as orders |
| `orders/{id}.platformFee` | legacy rupee field, now the real fee (was 0) | same | as orders |
| `list_order_requests/{id}.quote.platformFee` | snapshot at quote time | `quoteListOrder` | as before |
| `ledger_entries/{order}_platform_fee` (new kind) | Manager → Quicky, the fee | `postOrderLedger` | parties, Manager, admin |
| `daily_settlements.totals` | + `platformFeePaise`, `quickyRevenuePaise` | server | Manager, admin |
| `territory_daily_stats`, `territory_totals` | + `platformFeePaise`, `platformFeeOrders`, `quickyRevenuePaise` | server | Manager, admin |

Rules change: one new `match /platform_fee_versions/{version}` (read by admin only, write `false`). No other rule changed.

## 4. Cloud Functions changes (`QuickyAdmin/functions`)

| File | Change |
|---|---|
| `money.js` | `DEFAULT_PLATFORM_FEE` (₹5, on), `MAX_PLATFORM_FEE_PAISE`, `platformFeeProblems`, `platformFeeFor`. `computeOrderMoney({…, platformFeePaise})` adds the fee to `customerTotal` only and returns `platformFee` and `quickyRevenue`; the money invariant now includes the fee (it throws if any paisa is unaccounted for). `orderObligations`: UPI vendor → Manager = commission + delivery + **fee**; new `platform_fee` obligation Manager → Quicky (COD and UPI). |
| `pricing.js` | `loadPlatformFee(reader)`; new callable **`updatePlatformFee`**: Super Admin claim, validation, a transaction that writes the new version, the replaced version (if it was the default) and the live doc, logged. |
| `orders.js` | `quoteOrder`, `placeOrder` and `quoteListOrder` read the live fee. **`placeOrder` reads it inside its transaction**, so the order is charged the config that is live when it's written. The fee snapshot is stored on the order and in the quote. New optional **`expectedTotalPaise`**: if the total the customer saw no longer matches (e.g. the fee changed after the quote), the order is refused with "The total is now ₹X. Please check it and place the order again." `acceptListOrder` carries the quote's fee to the order. |
| `ledger.js` | `platform_fee` counts as an obligation in statements; statement totals and the territory read models include the fee and Quicky revenue; the nightly reconciliation covers the new fields automatically. |

The fee is never accepted from the client. Idempotency (one order per key) means a retried or double-tapped checkout charges the fee once (tested).

## 5. Admin Panel changes (QuickyAdmin)

- **More → "Pricing & Platform Fee"** (was "Rebate & Split Config") → a **Platform fee** section at the top of Global Pricing (`lib/features/admin/rebate_config/platform_fee_section.dart`). It has:
  - The current live value ("Now: ₹5.00 per order", or "off"), its version, when it was last updated and by which admin, live from Firestore.
  - An enable/disable switch, an amount field (₹, up to ₹100) and a "Why are you changing it?" field.
  - A **confirmation dialog** that states the new fee applies to every territory and that placed orders keep theirs.
  - Success and error messages from the server.
- **Financial reports:** "Platform fee revenue" now shows real figures (it was a fixed 0). A new **Platform fee & Quicky revenue** card shows total fee revenue, number of fee-bearing orders, Quicky's commission share, **total Quicky revenue**, fee revenue **by territory** and for the **last 7 days**, all from the ledger-derived totals. Territory reports' "admin net" now means commission share + fees. Pending and completed company settlements remain in **Quicky Settlements** (Phase 2).
- Changing the fee needs **no app release**: quotes and orders read it on the server.

## 6. Customer checkout and invoice (Foodie-Bell)

| Screen | Change |
|---|---|
| Checkout (`checkout_payment_screen.dart`) | A separate **"Platform fee"** line from the server quote, shown before the customer confirms; the total includes it. The shown total is sent as `expectedTotalPaise`; if it changed, checkout shows the error and fetches a new quote. |
| Order placed (`order_success_screen.dart`) | "Platform fee: ₹5" under the total. |
| Order details / receipt (`order_detail_screen.dart`) | the existing "Platform fee" line, now filled from the order's stored fee. |
| Order history | totals come from each order's own snapshot, so old orders keep the fee they paid. |
| Vendor order detail | "Platform fee (Quicky)", which makes clear the money isn't the shop's; the vendor's earnings are unchanged. |
| Manager → Daily Settlement | new lines **"Platform fees (100% Quicky)"** and **"Total to pay Quicky"** (commission share + fees). |
| Model | `OrderMoney.platformFee` (0 on older orders). |

The fee is never folded into product prices, and checkout can't add it twice because the client never calculates it.

## 7. Revenue distribution, UPI and COD settlement

Ledger entries for one ₹125 order (₹100 item, ₹20 delivery, ₹5 fee):

| | UPI (paid to the vendor) | COD (approved policy: rider hands over all cash) |
|---|---|---|
| Cash/UPI in | customer → vendor ₹125 | customer → rider ₹125 |
| Obligations | vendor → Manager **₹35** (₹10 commission + ₹20 delivery + ₹5 fee) | rider → Manager ₹125 |
| | Manager → rider ₹20 | Manager → vendor ₹90; Manager → rider ₹20 |
| | Manager → Quicky ₹4 (share) + **₹5 (platform fee)** | Manager → Quicky ₹4 + **₹5** |
| Manager keeps | ₹6 | ₹6 |

Both flows are tested end to end. The "rider keeps ₹20 and remits ₹105" variant isn't implemented: the approved Phase 2 policy is that the rider hands over all cash. The balances net to the same amounts either way, so switching later is only a policy change. Delivery and settlement remain separate steps, and UPI is still verified only by the vendor's own confirmation, never by a UPI-app result or a screenshot.

## 8. Refunds and cancellations

- A fee is **earned only when an order is delivered**: the `platform_fee` ledger entry is posted with the delivery. Unpaid, cancelled, rejected or failed orders create **no fee earnings** (tested for a customer cancellation and for a vendor rejection after UPI payment).
- A paid order that is cancelled or rejected creates a `refund_due` of the **full amount the customer paid, fee included**, from the vendor who holds the money (tested). The order's money snapshot is never altered; the refund is a separate, auditable ledger entry and acknowledged transfer.
- **Business decision needed:** whether the platform fee is refundable. The code refunds it (the vendor holds the customer's whole payment and Quicky has earned nothing on an undelivered order). A non-refundable fee was **not** invented. If you decide it should be kept, it needs a policy and a ledger rule (vendor → Quicky on cancellation).
- Partial refunds: none exist in the system (unchanged).

## 9. Test cases and actual results (2026-10-28, emulator)

| Requirement | Test | Result |
|---|---|---|
| Fee ₹5 on: quote and order add it once, outside the commission; snapshot stored | `orders.test` P5 "fee ₹5 on" | PASS |
| Fee disabled | P5 "fee off" | PASS |
| Admin changes ₹5 → ₹7; history keeps ₹5; new orders ₹7; audit trail | P5 "fee changed" | PASS |
| A stale total (customer saw ₹5) is refused | same | PASS |
| Customer / vendor / Manager / driver can't change the fee (callable) | P5 "only the Super Admin" | PASS |
| …nor by writing Firestore (incl. the admin client directly) | rules: 6 cases + audit-trail read cases | PASS |
| Negative, fractional, above-cap, non-boolean values and a missing reason refused | P5 + unit | PASS |
| Applied exactly once; duplicate submission | P5 (parallel same key → one order, fee once) | PASS |
| UPI settlement (vendor ₹35, Quicky share + fee) | P5 "UPI settlement" | PASS |
| COD settlement (rider hands over the total; Quicky share + fee; Manager keeps only 60%) | P5 "COD settlement" | PASS |
| Quicky revenue allocation; fee changes no one else's figures | finance matrix: 15 fee cases × COD/UPI, plus the ₹125 example | PASS |
| Daily statement and reports: fee totals, Quicky revenue, collections = entitlements + fees, statement = full recomputation | P5 "statements and reports" | PASS |
| Cancellation and refund: no fee earnings; refund = amount paid | P5 "cancelled and refunded" | PASS |
| Photo orders carry the fee | P5 "photo orders" | PASS |
| No cross-territory differences (global) | P5 "the same in every territory" | PASS |
| Invoice display | Flutter unit (fee parsed; 0 on old orders) + code review of the screens | PASS (screens **not** run on a device) |

Full regression after the change:

| Suite | Result |
|---|---|
| Firestore rules | **218 passed** |
| Storage rules | **59 passed** |
| `functions.test` (Phase 1) | **32 passed** |
| `orders.test` (Phases 2–5) | **67 passed** |
| Migrations | **11 + 3 passed** |
| `money` + `finance-matrix` | **182 passed** |
| `flutter test` (Foodie-Bell) | **9 passed** |
| `flutter analyze` | Foodie-Bell: 3 pre-existing infos; QuickyAdmin: no issues |

Commands: as in `PHASE_4_PRODUCTION_READINESS_REPORT.md` §2 (`npm test` in `QuickyAdmin/tests/functions`, the rules suite in `tests/rules`, `flutter test`).

## 10. Known limitations

- **Default on deploy:** with no `app_config/platform_fee` doc, the server charges the built-in **₹5**. If the fee shouldn't start the moment the functions deploy, save it as "off" in the admin panel first (step 3 below).
- **Fee refundability:** policy not decided (§8).
- Older app builds don't send `expectedTotalPaise`; for them the server still prices correctly, but there's no stale-total check. (Phase 2 already requires a coordinated release.)
- Checkout shows the fee only from the server quote; offline, there's no quote and no order can be placed.
- The ₹100 cap is a guard and is changeable in `money.js` (`MAX_PLATFORM_FEE_PAISE`).
- Telugu text for "Platform fees (100% Quicky)" and "Total to pay Quicky" (Manager screen) isn't added; the customer-facing label already exists in Telugu.
- Not run on real devices.

## 11. Manual configuration requirements

1. After deploying functions, open QuickyAdmin → More → **Pricing & Platform Fee** → **Platform fee**, set the switch and amount, give a reason and save. This creates version 2 and the audit record. (Optional: if you don't, ₹5 applies.)
2. Update the customer-facing price display in the store listing and terms if the fee must be disclosed there.
3. Tell Managers that daily settlements now include "Total to pay Quicky" (commission share + fees), and that vendors' UPI settlement includes the fee.

## 12. Deployment and rollback plan

**Deploy** (with the Phase 1–4 release; each step needs your approval):
1. `firebase deploy --only firestore:rules` (or with the release's rules step): adds the `platform_fee_versions` rule.
2. `firebase deploy --only functions`: the new `updatePlatformFee`, changed `placeOrder`, `quoteOrder`, `quoteListOrder`, `acceptListOrder` and `postOrderLedger`.
3. Set the fee in the admin panel (§11).
4. Ship the Foodie-Bell and QuickyAdmin builds (checkout line, success screen, Manager settlement lines, admin section and reports).
5. Check the first fee-bearing order: its `money.platformFee`, the `_platform_fee` ledger entry after delivery, and the statement totals.

**Rollback:**
- Fastest, no deploy: switch the fee **off** in the admin panel. New orders carry no fee; placed orders keep theirs.
- Code: first switch the fee off. Only after every fee-bearing order has been delivered or cancelled, redeploy the previous `functions/` if needed. The previous `ledger.js` doesn't know the `platform_fee` obligation, so a statement it rebuilt for a day with fee-bearing orders would leave those fees out of the balances. Keep the new `ledger.js` deployed for as long as such days are still being settled.
- Data: everything added (config doc, versions, ledger entries, read-model fields) is additive; nothing existing was rewritten.

## 13. Files modified

**QuickyAdmin:**
- `functions/money.js`, `pricing.js`, `orders.js`, `ledger.js`
- `firestore.rules`
- `tests/functions/orders.test.mjs`, `finance-matrix.test.mjs`
- `tests/rules/firestore.test.mjs`
- `lib/features/admin/rebate_config/platform_fee_section.dart` (new), `rebate_config_screen.dart`
- `lib/features/admin/more/admin_more_screen.dart`
- `lib/features/admin/reports/financial_reports_screen.dart`, `manager_reports.dart`
- `lib/data/providers/admin_read_models_provider.dart`

**Foodie-Bell:**
- `lib/data/models/order.dart`
- `lib/data/providers/order_actions.dart`
- `lib/features/user/checkout/checkout_payment_screen.dart`, `order_success_screen.dart`
- `lib/features/vendor/orders/vendor_order_detail_screen.dart`
- `lib/features/manager/settlement/manager_daily_settlement_screen.dart`
- `test/phase3_logic_test.dart`
