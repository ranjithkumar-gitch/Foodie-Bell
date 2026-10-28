# Phase 4 Production Readiness Report — Quicky

Date: 2026-10-28 · Firebase project `quickmandi-3b017`
Nothing was deployed, published or written to the production project. All tests ran on the Firebase Emulator Suite on one Windows PC, with synthetic data.

## 1. Executive summary

**Recommendation: NO-GO for public launch today. GO for a staged beta on a staging Firebase project once the 6 release blockers in §9 are closed.**

The server-side core is in good shape and was **re-verified independently in this phase**: every Phase 1–3 suite was re-run and passes; 152 new financial-matrix tests and 9 new race/reliability tests pass; no security, order-integrity or financial-integrity defect is open in the code that was tested. What stops a launch is everything that has **not** been exercised: none of Phases 1–3 is deployed; no flow has been run on a real phone, real OTP, real FCM or real network; production capacity has not been load-tested (the local emulator cannot); and the release configuration has blockers (Android signed with the debug key, placeholder privacy policy, no crash reporting, App Check not enforced, iOS push/App Attest entitlements missing).

Prerequisite check: `ARCHITECTURE_AUDIT_REPORT.md` does not exist (noted in Phases 2 and 3). The Phase 1–3 reports were read and their test claims re-run (§3) rather than assumed.

## 2. Test inventory

| Layer | Suite (repo) | Cases | What it covers |
|---|---|---|---|
| Firestore rules | `QuickyAdmin/tests/rules/firestore.test.mjs` | 210 | every collection × every role; cross-territory, cross-vendor, cross-customer; money/price/role/claim/ledger writes; scoped queries |
| Storage rules | `QuickyAdmin/tests/rules/storage.test.mjs` | 59 | KYC, photo orders, receipts, delivery proof, public images |
| Functions unit | `tests/functions/money.test.mjs` | 13 | money rules, rounding, slabs, settlement day |
| Financial matrix (new) | `tests/functions/finance-matrix.test.mjs` | 152 | ₹40/₹100/₹250/₹500/₹1,000 × 10 distances (both sides of every slab) × 0/10/15 % coupons, checked against an independent calculation; >11 km blocked; COD and UPI obligations settle to zero |
| Functions end-to-end (Phase 1) | `tests/functions/functions.test.mjs` | 32 | phone sign-in → claims, registration, role revocation, territory moves, admin-only callables, codes, upload validation |
| Order/payment/settlement end-to-end | `tests/functions/orders.test.mjs` | 57 | Phase 2 (35) + Phase 3 (13) + **Phase 4 (9 new)**, real ID tokens through Auth+Firestore+Functions+Storage emulators |
| Migrations | `migration.test.mjs`, `migration3.test.mjs` | 11 + 3 | dry run, apply, re-run |
| Performance | `tests/perf/perf.mjs` | 9 screens × 3 sizes | reads/bytes per screen at 100 / 1,000 / 10,000 orders (Phase 3) |
| Concurrent load (new) | `tests/load/load.mjs` | scenario A run | 3 territories (Chityal, Territory B, Territory C), mixed traffic, contention and integrity |
| Flutter unit (new) | `Foodie-Bell/test/phase3_logic_test.dart` | 7 | settlement-day rule, live/history merge, history filters, earnings parsing |
| Flutter widget | `Foodie-Bell/test/widget_test.dart` | 1 | app boots to splash |
| Flutter integration (device) | — | **0** | **not written** — needs a device/emulator farm and test phone numbers |

Commands (from `QuickyAdmin/tests/functions`, on Windows from a path without spaces — see `package.json`): `npm test` (all functions suites), `node --test finance-matrix.test.mjs`, `npm run perf` (`ORDERS=…`); rules from `tests/rules`: `firebase emulators:exec --only firestore "node firestore.test.mjs"`; load: `USERS=100 SECONDS=60 firebase emulators:exec --only auth,firestore,functions "node tests/load/load.mjs"`; Flutter: `flutter test`, `flutter analyze`.

## 3. Actual test execution results (2026-10-28)

| Suite | Result |
|---|---|
| Firestore rules | **210 passed, 0 failed** |
| Storage rules | **59 passed, 0 failed** |
| money.test | **13 passed, 0 failed** |
| finance-matrix.test | **152 passed, 0 failed** |
| functions.test (Phase 1) | **32 passed, 0 failed** |
| orders.test (Phase 2+3+4) | **57 passed, 0 failed** |
| migration.test / migration3.test | **11 / 3 passed, 0 failed** |
| flutter test (Foodie-Bell) | **8 passed** |
| flutter analyze | Foodie-Bell: 3 pre-existing style infos; QuickyAdmin: no issues |

Phase 1–3 reported results were reproduced exactly. One Phase 4 test first failed on an emulator quirk (a garbage ID token is not signature-checked by the Functions emulator, so it arrived as a claim-less sign-in and was refused with PERMISSION_DENIED instead of UNAUTHENTICATED — still refused); the test now accepts either refusal.

## 4. Security verification

| Requirement | Status | Evidence |
|---|---|---|
| OTP sign-in for all five roles | **PASS (emulator)** | every role signs in by phone in `orders.test`/`functions.test`/`load.mjs`; Super Admin by email + claim |
| Invalid / forged OTP | **PASS** | P4 "wrong OTP is refused" |
| Expired OTP, SMS delivery, rate limits | **NOT TESTED** | emulator issues codes without SMS or expiry; needs real numbers on staging |
| Identity linked to Firebase UID | **PASS** | `resolveSession` binds `authUid`; tests |
| Session restoration, logout in the app | **NOT TESTED** | needs device run (code paths reviewed: claim sync, stream reset) |
| Role assignment / revocation | **PASS** | suspension → `active=false` + refresh-token revocation (Phase 1); P4 suspended driver refused at once |
| Territory isolation | **PASS** | rules tests; claims across territories; P4 rename test |
| Firestore / Storage access control | **PASS** | 210 + 59 rules tests |
| Cloud Function authorization | **PASS** | every callable checks claims; tests with wrong roles and other territories |
| Users cannot change prices, roles, commission, ledger, other territories | **PASS** | rules + "client cannot set prices", "driver cannot change money fields", "nobody writes the ledger/earnings", "manager cannot modify another territory" |
| App Check | **BLOCKED** | integrated in both apps, **not enforced** (`ENFORCE_APP_CHECK=false`, console unenforced); needs release builds registered (Play Integrity / App Attest) — §9 |
| API key restrictions | **NOT TESTED** | a Maps/Routes key is in `road_route_provider.dart` and `AndroidManifest.xml`; restrictions can only be checked in Google Cloud Console |

## 5. Functional verification

| Workflow | Status | Evidence |
|---|---|---|
| Registration, territory selection, vendor discovery, product browsing | **PASS (server/rules)**, UI **NOT TESTED** | registerCustomer tests; scoped queries in rules tests; Phase 3 perf |
| Cart, distance, delivery charge, checkout | **PASS (server)** | quote = order; every slab; >11 km and no-route blocked |
| Order → accept → assign → pickup → delivery codes → completion | **PASS** | Phase 2 + P4 tests; codes 5-try lock |
| Failure paths | **PASS** | closed shop, out of stock, other shop's items, other address, beyond range, wrong codes, cancel before acceptance, failed delivery (proof photo required), reassignment |
| Order history | **PASS (provider logic)**, UI **NOT TESTED** | paging queries in rules tests; Flutter unit test of merge |
| **UPI** valid reference, claim without paying, vendor confirms, vendor disputes, reject after payment, duplicate confirmation, cancel after payment | **PASS** | Phase 2 tests; screenshots are never proof — only the vendor's own confirmation moves payment to `verified`, and the app says so |
| **COD** full, partial (shortfall → disputed until adjusted), rider not settling (carried forward), duplicate collection record, delivered without collection | **PASS** | Phase 2 tests + P4 "cash recorded twice" (second record refused; first stands; more than total refused) |
| Rider holds cash overnight | **PASS** | carried into next day's opening balance (tested) |
| Notifications | **PASS (dedupe/logic)**, delivery **NOT TESTED** | one doc per recipient per step even when the trigger repeats; FCM has no emulator |

## 6. Financial reconciliation results

- **Matrix:** 150 combinations of order value × distance × coupon equal an independent calculation to the paisa (10 % commission after coupon; 60/40 split; rider 100 % of the fee; no GST); every paisa paid lands with exactly one party. **PASS.**
- Tax: GST is off by agreement; the server refuses to turn it on (tested). Tax cases therefore **NOT APPLICABLE** until a tax adviser confirms rules.
- Ledger not duplicated under repeated triggers or three parallel delivery confirmations — **PASS** (P3, P4).
- Daily statements equal a full recomputation from the whole ledger — **PASS** (P3 reconcile).
- Pending settlements carry forward; disputed ones stay disputed until an admin-approved adjustment — **PASS** (Phase 2).
- Historical statements are not rewritten by later activity — **PASS** (P4: previous day's totals/rows/payments unchanged after a new delivery). Corrections only ever arrive as new adjustment entries.
- Settlement generated twice at once yields the same statement — **PASS** (P4).
- Refunds: tracked as `refund_due` + acknowledged transfer; order `payment.status` stays `refundDue` (known limitation, Phase 2).

## 7. Performance and load-test results

**Per-screen reads (Phase 3, measured on emulator):** at 10,000 orders the customer Home costs 71 reads (was 12,968), vendor dashboard 4 (2,778), driver home 30 (2,837), Manager dashboard 63 (1,193), Super Admin 261 (11,000), statement rebuild 61 (4,397) — full table in `PHASE_3_PERFORMANCE_REPORT.md` §8. 100,000 orders could not be loaded on this PC.

**Concurrent load — Scenario A, 100 virtual users, emulator** (3 territories; mix 70 % browse, 10 % order, 8 % vendor accept, 7 % driver claim, 5 % Manager dashboard; 0.5–2 s think time):

| Action | OK | Failed | p50 / p95 / p99 ms |
|---|---|---|---|
| Customer browse (Home queries) | 628 | 0 | 160 / 1,177 / 1,616 |
| Manager dashboard | 54 | 0 | 84 / 944 / 1,027 |
| Vendor / driver polling (nothing to do) | 141 | 0 | ~100 / ~890 / ~980 |
| Place order (callable) | 35 | 79 (`fetch failed`) | ~413,000 |
| Vendor accept (callable) | 2 | 11 | ~410,000 |

Integrity after the run: 35 orders, **0** duplicate orders, **0** orders assigned without a driver, no double claims. Reads by the load ≈ 7,200.

**Interpretation:** reads scale fine; **callables collapsed because the local Functions emulator executes requests one after another on this PC** — every trigger and callable queues behind the others — so these latencies say nothing about production, where each function scales out to many instances. **Scenarios B (500), C (1,000) and D (5,000) were NOT RUN**: the emulator cannot produce meaningful numbers at that load, and running them against Firebase needs a separate staging project, your approval and a billing cap. `tests/load/load.mjs` is ready to point at a staging project (it needs only host/port/project changes and pre-created test phone numbers). Transaction contention in production, function execution time, notification delay and p95/p99 under real load are therefore **NOT MEASURED**. **No concurrency capacity is claimed.**

## 8. Race conditions, reliability, low network

| Case | Status | Evidence |
|---|---|---|
| Two drivers claim the same order | **PASS** | exactly one wins (Phase 2) |
| Customer submits twice | **PASS** | same idempotency key in parallel → one order |
| Function retry / duplicate delivery event | **PASS** | ledger + read models posted once |
| Vendor accepts and rejects simultaneously | **PASS** | exactly one outcome (P4) |
| Delivery completion duplicated | **PASS** | 3 parallel confirmations → 1 success, 1 ledger entry (P4) |
| Settlement generation twice | **PASS** | identical statements (P4) |
| Network drop during checkout | **PASS (server)** | retry with the same idempotency key returns the same order; app keeps the key per checkout (Phase 2) — **device test NOT DONE** |
| App closed during UPI payment | **PASS (server)** | order stays `awaitingVerification`; nothing is paid until the vendor confirms — device test NOT DONE |
| Manager offline during settlement | **PASS (server)** | transfers are idempotent per key; acknowledgements single-use |
| Function temporarily failing | **PASS (design)** | ledger/aggregate triggers `retry: true` and idempotent; statements queued and rebuilt; nightly reconciliation |
| Notifications out of order | **PASS (design)** | the app shows Firestore state, not push content; pushes are hints |
| Slow / intermittent network, backgrounding, reconnection on low-end Android | **NOT TESTED** | needs real devices (e.g. a ₹8–10k Android with network throttling); Firestore offline cache is on by default; no duplicate financial events possible from reconnection because every money step is a server callable with state checks |

## 9. Unresolved issues

| # | Issue | Severity | Blocks launch |
|---|---|---|---|
| 1 | Phases 1–3 not deployed; nothing tested on a real Firebase project or device | **Critical** | Yes |
| 2 | Android release build signed with the **debug key** (`build.gradle.kts`: `signingConfig = debug`; no `key.properties`) | **Critical** | Yes (Play Store) |
| 3 | Privacy Policy / Terms are **placeholder text** (`auth_terms_screen.dart`) | **High** | Yes (Play Store, DPDP Act) |
| 4 | App Check not enforced; release builds not registered | **High** | Yes |
| 5 | No crash reporting / performance monitoring (no Crashlytics or Performance in `pubspec.yaml`) | **High** | Yes (operating blind) |
| 6 | iOS: no entitlements (push `aps-environment`, App Attest) | **High** | iOS launch only |
| 7 | Production load not tested (B–D) | **High** | Before scaling past beta |
| 8 | Maps/Routes API key in the app — restrictions unverified | **High** | Verify in console |
| 9 | Billing budget/alerts not configured | **High** | Yes |
| 10 | No device integration tests | Medium | Beta acceptable with manual test plan |
| 11 | Expired-OTP / SMS quota behaviour untested | Medium | — |
| 12 | Refund leaves `payment.status = refundDue`; Manager adjustment UI missing; Telugu strings missing for Phase 2/3 screens | Medium | — |
| 13 | Data-retention policy not defined (orders, KYC, chat, tokens) | Medium | — |
| 14 | UPI confirmation is manual (no bank proof) — by design, disclosed | Low (accepted risk) | — |
| 15 | Leftover emulator `java.exe` processes on the dev PC | Low | — |

No open Critical/High **code defect** in security, order integrity or financial integrity was found in the tested code; the Critical/High items are release configuration and untested environments.

## 10. Production release checklist

Nothing here is marked done without evidence.

| Item | Status | Evidence / action |
|---|---|---|
| Auth: phone provider, test numbers, anonymous disable plan | NOT DONE | Phase 1 §8 steps 2, 11 |
| Firestore rules | READY, NOT DEPLOYED | 210 tests |
| Storage rules | READY, NOT DEPLOYED | 59 tests |
| Firestore indexes | READY, NOT DEPLOYED | 34 composite + 17 exemptions |
| Cloud Functions | READY, NOT DEPLOYED | 49 load; tests above; set `STORAGE_REGION`, `ROUTES_API_KEY` secret |
| App Check enforcement | FAIL | issue 4 |
| Environment variables | PARTIAL | `functions/.env` (`ENFORCE_APP_CHECK=false`); `ROUTES_API_KEY` secret not set |
| API key restrictions | NOT VERIFIED | issue 8 |
| Google Maps billing & quotas | NOT VERIFIED | set quotas/caps on Routes and Maps SDK in Cloud Console |
| FCM | PARTIAL | Android OK in code; iOS APNs key + entitlement missing (issue 6) |
| Backups & recovery | NOT DONE | schedule `gcloud firestore export` (daily) + test one restore; enable PITR |
| Data retention | NOT DONE | issue 13 |
| Privacy policy & terms | FAIL | issue 3 |
| Payment & settlement policies | PARTIAL | rules agreed (Phase 2); written SOP for vendors/Managers/riders not in repo |
| Android release config | FAIL | issue 2; also review `minify`/ProGuard, versioning (1.0.0+1) |
| iOS release config | FAIL | issue 6 |
| Crash monitoring | FAIL | issue 5 |
| Billing budgets & alerts | NOT DONE | issue 9 |
| Rollback procedures | READY | Phase 1 §9, Phase 2 §12, Phase 3 §12 |

**Recommended alerts** (Cloud Monitoring / log-based, to create on deploy): failed `placeOrder` rate > 5 % over 10 min; `confirmUpiPayment`/`recordCodCollection` errors > 0 in 15 min; any order in `placed` > 30 min or `vendorAccepted` unclaimed > 20 min (scheduled check); `reconcileAggregates:`/`reconcileStatements:` error logs (any); `rebuildQueuedStatements` failures 3× in a row; Firestore reads/day > 2× weekly average; Functions error rate > 1 %; push `sendEachForMulticast` failure rate > 20 %; monthly budget 50/90/100 % (alerts do not stop billing).

## 11. Deployment and rollback plan

Order (each step needs your approval): (1) create a **staging** Firebase project; deploy Phases 1–3 there per their reports; run the device test plan for all five roles, real OTP and FCM; run `load.mjs` scenarios A→D there with a billing cap; (2) fix issues 2–6, 8, 9; (3) production: export backup → indexes → functions → `migrate-phase1` → `migrate-phase3` → app builds to testers → rules → App Check enforce after a week of clean metrics. Rollback: rules history restore, previous functions from git/backup, data changes are additive (migrations back up what they change), apps keep working on restored rules. Details: Phase 1 §9, Phase 2 §12, Phase 3 §12.

## 12. Final launch assessment

| Area | Verdict |
|---|---|
| Security rules & authorization | **PASS** (emulator) |
| Order integrity & races | **PASS** (emulator) |
| Financial correctness & reconciliation | **PASS** (emulator) |
| Territory isolation | **PASS** |
| Read scalability | **PASS** (measured to 10,000 orders) |
| Concurrent capacity | **NOT TESTED** (B–D) / BLOCKED on staging |
| Real devices, OTP, FCM, low network | **NOT TESTED** |
| App Check | **FAIL** (not enforced) |
| Release configuration (Android signing, iOS entitlements, privacy policy) | **FAIL** |
| Monitoring, crash reporting, budgets | **FAIL** |

**Final recommendation: NO-GO** for production launch. **GO** to deploy to a staging project and run a closed beta in one territory (Chityal) once issues 2–5, 8 and 9 are fixed, followed by staged load tests and a device test pass; re-assess for launch after that.
