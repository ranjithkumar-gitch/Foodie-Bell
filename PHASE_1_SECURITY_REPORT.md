# Phase 1 Security Report — QuickMandi (Foodie-Bell + QuickyAdmin)

Date: 2026-10-27 · Firebase project `quickmandi-3b017`
Scope: Firestore rules, Storage rules, Cloud Functions, App Check, beta-data migration.
Status: **implemented and tested locally; nothing committed, nothing deployed.**

---

## 1. Initial findings

From `docs/auth-data-audit.md` (2026-10-26) and this phase's code review:

| # | Finding | Severity |
|---|---|---|
| 1 | Firestore rules let **any signed-in user, including anonymous**, read and write every collection (orders, KYC, settlements, app config…). | Critical |
| 2 | Storage: QuickyAdmin's deployed rules make **every object public-read** and writable by any signed-in user; KYC files were reached through permanent download URLs stored on vendor/driver docs that every client streamed. | Critical |
| 3 | Admin = a client-side email comparison (`admin@qm.com`); functions also accepted that email. No custom claims anywhere. | Critical |
| 4 | Order money fields (total, fees, rebate %, coupon, payment, COD collected) and status were plain client writes; any driver could take or overwrite any order. | High |
| 5 | Manager bank details stored on the manager doc that **every role** reads. | High |
| 6 | The Foodie-Bell client had moved to a claims model (phone auth, `resolveSession`, `accessScopeProvider`), but the **functions it calls did not exist** in the repo and the rules were never rewritten. | High |
| 7 | Whole-collection listeners (vendors, promotions, reviews…) that would break under owner-scoped rules. | Medium |
| 8 | `app_config` (live branding) written directly by the admin client; `sendPushNotification` sent to **any topic string**, incl. personal `account_*` topics; order notifications used free text from the order doc. | Medium |
| 9 | Rules/indexes/functions deployable from two repos with diverging copies. | Medium |
| 10 | No App Check. | Medium |

## 2. Security architecture implemented

**Identity.** Firebase Phone Auth (customers, vendors, drivers, managers) and email/password (Super Admin). Anonymous sign-in gets nothing.

**Authorization = server-set custom claims**, never document fields or client input:

| Claim | Set by | Meaning |
|---|---|---|
| `role` | `resolveSession` / `registerCustomer` / `sync*Claims`; `superAdmin` only by `scripts/super-admin.js` | user · vendor · driver · manager · superAdmin |
| `accountId` | same | caller's own account doc |
| `territoryId` | same (manager: from the territory doc naming them) | Manager/Vendor/Driver territory |
| `active` | same | approved and not deleted |

- `resolveSession` reads the **verified phone number from the ID token**, finds the account (managers → vendors → drivers → users), binds `authUid` on the doc, sets claims.
- `sync{User,Vendor,Driver,Manager}Claims` + `syncTerritoryManagerClaims` recompute claims on approval/suspension/deletion/territory change, touch `claimSync/{uid}` (app refreshes its token), and **revoke refresh tokens** when access is lost.
- **Server-only state transitions:** pickup/delivery (`confirmPickup`/`confirmDelivery`, 4-digit codes, 5-try lock), order codes (`createOrderCodes`), notifications (`onOrderStatusChange`, names taken from account docs), branding (`activate/resetOccasionTheme`), broadcasts (`sendPushNotification`, `all_users` / existing `territory_*` only).
- **Every callable** checks sign-in, role/active claims and validates input (`functions/common.js`).
- **App Check** (Play Integrity / App Attest→DeviceCheck / reCAPTCHA Enterprise; debug provider for dev) in both apps; callables in monitor mode (`ENFORCE_APP_CHECK=false`).
- **Storage:** private documents read by path through rules (`StorageImage`), never by download URL; `validateUpload` checks real file bytes and rotates the download token of private uploads to one never handed out.
- **One deployment source:** `QuickyAdmin` holds `firebase.json`, `.firebaserc`, rules, indexes, functions and tests.

Full access matrix: `docs/roles-and-access.md`.

## 3. Modified files

### Foodie-Bell
| File | Change |
|---|---|
| `firestore.rules`, `storage.rules`, `firestore.indexes.json` | **Removed** — moved to QuickyAdmin (single deploy source) |
| `firebase.json` | firestore/storage deploy sections removed |
| `pubspec.yaml` / `pubspec.lock` | `firebase_app_check` added |
| `lib/main.dart`, `lib/core/security/app_check.dart` (new) | App Check activation |
| `lib/data/providers/firestore_vendors_provider.dart` | vendor stream scoped per role |
| `lib/data/providers/firestore_promotions_provider.dart` | promotion stream scoped per role; `reviewedAt` = server time |
| `lib/data/providers/firestore_orders_provider.dart` | server timestamps for status/paidAt/redeemedAt; `couponId` on coupon orders; tolerant timestamp parsing |
| `lib/data/providers/firestore_tickets_provider.dart` | `closedAt` = server time |
| `lib/features/user/reviews/rate_review_screen.dart` | review ID `rev-<orderId>` (one per order) |
| `lib/data/providers/vendor_document_storage_provider.dart` | KYC never gets a download URL; public storefront copy in `vendor_covers/` |
| `lib/data/providers/list_order_image_storage_provider.dart` | photo orders/receipts stored as paths under `{user}/{vendor}` folders |
| `lib/shared/widgets/storage_image.dart` (new), `document_viewer_screen.dart` | private images read through rules |
| `lib/data/providers/kyc_document_url_provider.dart` | **Removed** (replaced by `StorageImage`) |
| KYC & photo-order screens: `vendor_document_checklist.dart`, `driver_document_checklist.dart`, `manager_vendor_detail_screen.dart`, `manager_driver_detail_screen.dart`, `list_order_status_screen.dart`, `order_detail_screen.dart`, `vendor_order_detail_screen.dart`, `vendor_order_queue_screen.dart` | use `StorageImage` |
| `docs/roles-and-access.md` | deploy location, tests |
| `PHASE_1_SECURITY_REPORT.md` (new) | this report |

### QuickyAdmin
| File | Change |
|---|---|
| `firestore.rules`, `storage.rules`, `firestore.indexes.json` | the authoritative rules + indexes |
| `firebase.json`, `README.md`, `.gitignore` | indexes wired in; deploy docs; `node_modules/` ignored |
| `functions/common.js` (new) | shared checks, App Check switch |
| `functions/accounts.js` (new) | `resolveSession`, `registerCustomer`, `sync*Claims`, `syncTerritoryManagerClaims` |
| `functions/order_codes.js` (new) | `createOrderCodes`, `confirmPickup`, `confirmDelivery` |
| `functions/index.js` | claim-only admin, input validation, topic allowlist, server-side notification names, `appIconKey`, sweep fix, `validateUpload` |
| `functions/.env` (new) | `ENFORCE_APP_CHECK=false` |
| `functions/scripts/super-admin.js`, `beta-inventory.js`, `migrate-phase1.js` (new) | admin grant, read-only inventory, migration |
| `tests/rules/*`, `tests/functions/*` (new) | emulator test suites |
| `lib/core/session/admin_session_controller.dart`, `lib/shared/auth/admin_login_screen.dart` | admin = `superAdmin` claim |
| `lib/data/providers/firestore_current_theme_provider.dart` | branding via callables |
| `lib/data/providers/firestore_managers_provider.dart`, `features/admin/managers/manager_detail_screen.dart` | bank details only in `private/bank` |
| `lib/main.dart`, `lib/core/security/app_check.dart` (new), `pubspec.yaml/.lock` | App Check |

No financial formula was changed. UI changes are limited to: KYC/photo images load through the rules (lock placeholder if denied); an admin without the claim sees "this account does not have Admin access".

## 4. Database migration details

Tools (in `QuickyAdmin/functions/scripts/`):

- **`beta-inventory.js`** — read-only. Auth users by provider (anonymous count and age), claims, account docs per role/status, bound vs. unbound, **numbers on more than one account and which one login resolves to**, missing `territoryId`, bank fields on public manager docs, KYC stored as URLs, covers pointing at KYC, in-flight orders without codes, photo orders holding URLs. Phones masked.
- **`migrate-phase1.js`** — dry run by default; `--apply` backs up every document it changes to `_migrationBackups/{runId}/docs/…` first. Steps:
  1. `territoryId` on vendors/drivers/managers (from territory name; ambiguous → warning, untouched), then orders/promotions/reconciliations (from vendor).
  2. Manager bank fields → `managers/{id}/private/bank` (existing private values win), removed from the public doc.
  3. KYC `documentUrls` / URL `documentPaths` → Storage paths.
  4. Storefront covers that point at the KYC file → public copy in `vendor_covers/`.
  5. Flat photo-order images/receipts → copies under `{user}/{vendor}` paths; order line items updated.
  6. Pickup/delivery codes for in-flight orders.
  7. Download tokens of private Storage objects rotated to never-shared values (old URLs stop working — verify once on the real project, see §6). **Objects are never deleted.**
  - Optional, separately approved: `--delete-anonymous-users` (anonymous users hold no data; dry run lists them).

**Accounts are not pre-bound.** Each tester is bound on their next phone sign-in by `resolveSession`; nothing about their data changes. Manager email/password users (doc ID = uid) are left in place; managers now sign in by phone.

### Beta transition plan (no tester is cut off silently)
1. Run `beta-inventory.js`; resolve duplicate numbers and ambiguous territories by hand.
2. Export Firestore (`gcloud firestore export gs://…`) — rollback point.
3. Deploy functions (rules still old → old and new builds both work).
4. Grant Super Admin; ship new Foodie-Bell + QuickyAdmin builds; **notify testers to update** (date announced in advance).
5. `migrate-phase1.js` dry run → review → `--apply`.
6. Each role signs in on the new build (checklist §8, step 9).
7. Deploy rules. Old builds lose access from this moment; testers on them see sign-in errors until they update.
8. After a week with no issues: disable Anonymous provider; optionally `--delete-anonymous-users`.

## 5. Firestore and Storage rule changes

**Firestore** (`QuickyAdmin/firestore.rules`) — deny by default; per-collection rules for all 21 required collections plus `categories`, `tax_categories`, `topics`, `occasions`, `recent_searches`, `list_order_requests`, `claimSync`, `adRevenue`, `managerPayouts`, `settlements`, `managers/*/private`, `orders/*/codes`. Highlights:
- Orders: customer creates only with fixed fees, GST ≤ 28 %, totals that add up, rebate % from the vendor doc, real redeemed coupon; each later transition lists the only fields it may touch; money fields never in those lists; pickup/delivery server-only; managers/admin read-only.
- Settlement reconciliations create/delete only by the territory's manager; `settlements` append-only; payouts follow a fixed status flow.
- KYC verdicts and approvals only by the territory's manager; accounts can't edit their own status, territory, rebate, manager code.
- `app_config`, notifications, broadcasts, claims, codes: no client writes.
- Queries updated to match (vendors, promotions scoped by role).

**Storage** (`QuickyAdmin/storage.rules`) — private: `vendor_documents/`, `driver_documents/`, `list_order_images/{user}/{vendor}/`, `list_order_receipts/{vendor}/{user}/`, `delivery_proofs/{order}/` (owner, counterpart, territory manager via Firestore lookup, admin). Public read, owner write: `product_images/`, `vendor_covers/`, `global_product_images/`, `promotion_images/`, `occasion_themes/`. Avatars: accounts only. JPEG/PNG/WebP with matching extension, 5–10 MB caps; sent photos/receipts/proof can't be overwritten.

## 6. Test cases and actual results

All runs on the Firebase Emulator Suite (firebase-tools 15.2.0, Node 24, Java 25) on 2026-10-27.

| Suite | Location | Result |
|---|---|---|
| Firestore rules | `QuickyAdmin/tests/rules/firestore.test.mjs` | **171 passed, 0 failed** |
| Storage rules | `QuickyAdmin/tests/rules/storage.test.mjs` | **59 passed, 0 failed** |
| Functions end-to-end (Auth + Firestore + Functions + Storage emulators, real phone sign-ins, real ID tokens) | `QuickyAdmin/tests/functions/functions.test.mjs` | **32 passed, 0 failed** |
| Migration (legacy-shaped seed data; dry run, apply, re-run) | `QuickyAdmin/tests/functions/migration.test.mjs` | **11 passed, 0 failed** |
| Inventory script smoke run | `beta-inventory.js --json` on seeded emulator data | ran; reported 1 anonymous user, duplicate number → resolves to vendor, phones masked |
| Static analysis | `flutter analyze` both apps | no errors/warnings (Foodie-Bell: 3 pre-existing style infos) |

**Bugs the test runs found and fixed:**
1. Customers created by `registerCustomer` (`languageCode: null`) couldn't edit their own profile — rule now accepts null.
2. `onOrderStatusChange` didn't notify the territory Manager when the manager doc lacked `territoryId` — now reads the territory doc's `assignedManagerId` (same source as claims).
3. `validateUpload` trusted the trigger event's metadata copy — now reads the object's current metadata.
4. Setting a download token to `null` has no effect in the Storage emulator — tokens are now *rotated* to a never-shared value (`tokenRotated` marker) instead.

**Not verifiable in the emulator (manual check on the real project, checklist step 8):** the Storage emulator *appends* a rotated token instead of replacing it (observed: `tok-1,tok-2`, both still download), so the tests check that rotation happened, not that the old URL now fails. Before relying on it, upload one test file to `vendor_documents/`, note its URL, let `validateUpload` run, and confirm the old URL returns 403.

**Test-environment notes:** on Windows, firebase-tools can't start the Functions emulator from a path containing spaces, and `functions/node_modules` in the repo lacks the Windows `.cmd` launchers (installed on another OS). The functions/migration suites were run from a space-free copy with a fresh `npm install`. The emulator's ID-token refresh after `revokeRefreshTokens` still issued a token (with `active=false`); production refuses it — the claim change itself was verified.

Coverage of the required scenarios:

| Requirement | Covered by |
|---|---|
| Customer can't access another customer's data | rules: users/carts/addresses/orders/codes/list orders cross-customer cases; functions: REST read with a real token |
| Vendor can't access another vendor's private records | rules: vendor/product/coupon/order/KYC cross-vendor cases; storage: KYC & photo orders |
| Manager can't modify another territory | rules: vendor/driver approval, onboarding, promotions, reconciliations; functions: real token |
| Driver can't modify financial values | rules: total/rebate/COD twice/status; functions: real token PATCH refused |
| Customer can't self-promote | rules + functions: status/role edit refused, claims unchanged, admin callables refused |
| Anonymous/unauthenticated rejected | rules (both), storage, functions (`resolveSession` anonymous → refused) |
| Unauthorized KYC reads denied | storage: customer/driver/other vendor/other-territory manager/anonymous |
| Admin-only config writes | rules: `app_config` even for admin client; functions: theme callables admin-only, email without claim refused |
| Valid workflows still work | rules: checkout (COD/online/coupon), accept, assign, location, COD collect, list orders, reviews, chat, tickets, reconciliation; functions: login binding, registration, pickup with code |
| Revoked/changed roles lose authorization | functions: suspension → `active=false` + revoke; territory moves; manager unassigned → loses territory reads; soft-delete |

Not covered by automated tests: real devices (Play Integrity/App Attest tokens), FCM delivery (no emulator), Flutter widget flows end-to-end.

## 7. Remaining risks

| Risk | Mitigation / next phase |
|---|---|
| Line-item prices and online `paymentId` are client-supplied (totals are checked, prices aren't); Razorpay signature not verified. | Phase 2: create orders and verify payments server-side. |
| List-order "paid" is customer-attested (vendor then confirms with a receipt). | Phase 2 payment verification. |
| FCM topics (`account_<id>`, `drivers_<territory>`) can be subscribed to by anyone who knows the name. | Phase 2: per-device FCM tokens, server-side sends. |
| Manager docs (incl. `territoryFee`) readable by every account; active vendors' KYC *paths* (not files) visible to customers. | Split public profile docs. |
| Open delivery offers show customer name/drop-off to every active driver in the territory. | Reveal on assignment. |
| App Check not yet enforced. | Enforce after monitoring (checklist). |
| Storage trigger region (`STORAGE_REGION`) must match the bucket. | Set before deploying functions. |
| Functions emulator can't run from a path with spaces on Windows (firebase-tools bug); tests were run via the short path. | Run tests from a path without spaces. |
| Old beta builds stop working when rules deploy. | Transition plan §4. |

## 8. Firebase Console configuration checklist

Nothing below has been done; each step needs the owner's approval.

1. **Firestore backup**: `gcloud firestore export gs://quickmandi-3b017-backups/pre-phase1` (create the bucket first).
2. **Authentication → Sign-in method**: Phone enabled; add test numbers for QA. (Anonymous: disable only at the end — step 11.)
3. **Android**: Project settings → Android app → add the **SHA-256** of the release (and Play App Signing) keys. Play Console → link the app for **Play Integrity**.
4. **iOS**: Apple Developer → App ID → enable **App Attest**; Xcode → Runner → Signing & Capabilities → add *App Attest* (entitlement `com.apple.developer.devicecheck.appattest-environment` = `production`); upload a DeviceCheck key in App Check → Apps → iOS.
5. **App Check** → register Android (Play Integrity), iOS (App Attest), Web (reCAPTCHA Enterprise; pass the site key via `--dart-define=APP_CHECK_RECAPTCHA_SITE_KEY`). Add **debug tokens** from dev/sideloaded builds (`--dart-define=APP_CHECK_DEBUG=true`). Leave Firestore/Storage/Functions **unenforced**.
6. **Functions**: set `STORAGE_REGION` (functions/index.js) to the bucket location; `firebase deploy --only functions` from QuickyAdmin.
7. **Super Admin**: `node functions/scripts/super-admin.js grant admin@qm.com`; change that account's password.
8. **Migration**: `beta-inventory.js` → `migrate-phase1.js` → review → `--apply`. First verify token rotation on the real bucket: upload a test file to `vendor_documents/`, keep its URL, wait for `validateUpload`, confirm the old URL now returns 403.
9. **Verify each role on the new build**: customer sign-in/registration, order, review; vendor accept, KYC upload, coupon; driver take offer, pickup code, COD, delivery code; manager approve vendor, KYC view, promotion approve, reconciliation; admin theme, push, payouts.
10. **Rules**: `firebase deploy --only firestore,storage` from QuickyAdmin; allow Storage → Firestore cross-service access when prompted.
11. **After a week**: App Check → *Enforce* Firestore, Storage, then set `ENFORCE_APP_CHECK=true` and redeploy functions — once metrics show ~100 % verified requests from current builds. Disable Anonymous sign-in. Optionally delete anonymous users and old manager email/password users (keep the Super Admin).

## 9. Rollback instructions

| What | How |
|---|---|
| Rules | Firebase Console → Firestore / Storage → Rules → *History* → restore previous; or redeploy the previous `firestore.rules` from git. |
| Functions | `firebase functions:delete <name>` for new ones; redeploy the previous `functions/` from git for changed ones. |
| App Check | Console → App Check → *Unenforce* (instant). Clients keep working without it while unenforced. |
| Super Admin | `super-admin.js revoke <email>`. |
| Migration data | Every changed doc is in `_migrationBackups/{runId}/docs/{collection__id}` (`path` + original `data`): write `data` back to `path`. Full restore: `gcloud firestore import` of the pre-migration export. Storage objects were only copied, never deleted; the old token values are in the backed-up doc URLs and can be set back in object metadata if an old URL must work again. |
| Client builds | Previous builds work again once the old rules are restored. |

## 10. Readiness for Phase 2

**Ready for staged deployment** once the console checklist (§8) is done in order. Code-complete for Phase 1; every rule and function path has emulator coverage.

Phase 2 candidates (ordered): server-side order creation + Razorpay signature verification; per-device FCM tokens; public/private split of manager and vendor profiles; App Check enforcement; CI running `tests/rules` and `tests/functions` on every change.
