# Quicky: Phase I.8 Team Handoff (Internal Testing)

**Date:** 2026-11-02. The same file is in both repositories.

This handoff is for **source sharing and internal testing only**. Production deployment, migrations against live data, release signing and store publication are **not approved**.

## 1. Repositories

| Repository | URL | Branch | Source commit |
|---|---|---|---|
| Foodie-Bell (mobile app: Customer, Vendor, Driver, Manager) | https://github.com/ranjithkumar-gitch/Foodie-Bell | `main` | `4105694` (+ this handoff commit) |
| QuickyAdmin (admin web, Cloud Functions, rules, indexes, scripts, tests, reports) | https://github.com/udaytejach/QuickyAdminpanel | `main` | `63e7f38` (+ this handoff commit) |

**Clone the two repositories side by side:**

```
mkdir QuickMandi && cd QuickMandi
git clone https://github.com/ranjithkumar-gitch/Foodie-Bell.git
git clone https://github.com/udaytejach/QuickyAdminpanel.git QuickyAdmin
```

Several tests and the pre-deploy check expect the folder names `Foodie-Bell` and `QuickyAdmin`.

## 2. Toolchain (versions used for validation)

| Tool | Version |
|---|---|
| Flutter | 3.47.0 (stable), Dart 3.13.0 |
| Java | OpenJDK 21 (Firebase emulators and Android Gradle). On macOS: `brew install openjdk@21` and put `/opt/homebrew/opt/openjdk@21/bin` first on `PATH` |
| Node | 22 for Cloud Functions (`functions/package.json` engines); validated locally with Node 26 |
| npm | 11 |
| Firebase CLI | `firebase-tools` 15.x (`npm i -g firebase-tools`) |
| Xcode / CocoaPods | Xcode 26.x, CocoaPods 1.16 (iOS builds only) |
| Android SDK | build-tools 37 used; any current SDK with an emulator image |

You don't need to log in to Firebase for local work. **Never run `firebase use`, `firebase deploy` or anything with `--project quickmandi-3b017`.**

## 3. Firebase emulators (local backend)

```
cd QuickyAdmin
(cd functions && npm ci)
(cd integration-tests && npm ci)
(cd security-tests && npm ci)
# Emulator-only function settings (git-ignored; placeholders, no real key):
cp -n functions/.env.local.example functions/.env.local
cp -n functions/.secret.local.example functions/.secret.local
export PATH=/opt/homebrew/opt/openjdk@21/bin:$PATH   # macOS
firebase emulators:start --project demo-quickmandi --only auth,firestore,functions,storage
```

- **Without the two `.local` files**, the Functions emulator tries Google Secret Manager and the Google Routes API, and delivery quotes fail.
- **`integration-tests/run.sh` creates them automatically.**

- **Ports:** Auth 9099, Firestore 8080, Functions 5001, Storage 9199. They bind to `127.0.0.1`.
- **`demo-quickmandi`** is a demo project id: it has no real resources and can't reach production.

## 4. Seeding test users and roles (emulator only)

**Seed a territory with every role.** Run this with the emulators running; the harness refuses to run against anything except `demo-` projects on localhost:

```
cd QuickyAdmin/integration-tests
FIRESTORE_EMULATOR_HOST=127.0.0.1:8080 FIREBASE_AUTH_EMULATOR_HOST=127.0.0.1:9099 \
FIREBASE_STORAGE_EMULATOR_HOST=127.0.0.1:9199 GCLOUD_PROJECT=demo-quickmandi \
node -e "import('./harness.mjs').then(h => h.seedTerritory('TEAM')).then(() => process.exit(0))"
```

**What it creates:**
- territory `TEAM_t` and shop "Fresh Mart" with products;
- accounts that sign in by phone:

| Role | Phone |
|---|---|
| Manager | 9000000001 |
| Second Manager | 9000000008 |
| Vendor | 9000000002 |
| Other vendor | 9000000003 |
| Driver | 9000000004 |
| Driver | 9000000005 |
| Customer | 9000000006 |
| Customer | 9000000007 |

**Super Admin for the admin console:** email and password, in the Auth emulator only.

```
cd QuickyAdmin/functions
FIREBASE_AUTH_EMULATOR_HOST=127.0.0.1:9099 GCLOUD_PROJECT=demo-quickmandi node -e "
const {initializeApp}=require('firebase-admin/app');const {getAuth}=require('firebase-admin/auth');
initializeApp({projectId:'demo-quickmandi'});const a=getAuth();
a.createUser({email:'admin@quicky.test',password:'test-only-123'})
 .then(u=>a.setCustomUserClaims(u.uid,{role:'superAdmin'})).then(()=>console.log('ok'))"
```

**Pricing:** the emulator starts with **no** saved pricing, so the server uses its built-in default (§9). To test the approved terms, sign in to the admin console and save pricing with a 50% Manager share.

## 5. Phone sign-in with the Auth emulator

- **No real SMS is sent.** Enter the phone number in the app, then read the code from:
  ```
  http://127.0.0.1:9099/emulator/v1/projects/demo-quickmandi/verificationCodes
  ```
  It's a JSON list. Use the latest code for your number.
- The 30 s resend cooldown and the 45 s send deadline still apply.

## 6. Foodie-Bell (mobile app)

```
cd Foodie-Bell
flutter pub get
```

**A plain `flutter run` (debug) fails closed.** The app shows "Firebase is not configured for this build" and never touches Firebase. Always pass a target:

| Where | Command |
|---|---|
| Android **emulator** | `flutter run --dart-define=FIREBASE_TARGET=emulator --dart-define=EMU_HOST=10.0.2.2` |
| iOS **simulator** / desktop | `flutter run --dart-define=FIREBASE_TARGET=emulator --dart-define=EMU_HOST=127.0.0.1` |
| Physical phone (same Wi-Fi) | `EMU_HOST=<your Mac/PC LAN IP>`, **and** start the emulators listening on that interface (set `host` to `0.0.0.0` for each emulator in a local, uncommitted copy of `firebase.json`) |

- **`10.0.2.2`** is the Android *emulator's* alias for your computer. It does **not** work on a physical phone.
- **Emulator builds** show a red **EMULATOR** ribbon and use project `demo-quickmandi` with a placeholder API key.
- **`FIREBASE_TARGET=production`** exists, but production use is **not approved**. Don't use it.

**Debug APK for internal testing** (emulator target):

```
flutter build apk --debug --dart-define=FIREBASE_TARGET=emulator --dart-define=EMU_HOST=10.0.2.2
# → build/app/outputs/flutter-apk/app-debug.apk ; adb install -r <apk>
```

It's signed only with your own debug key. Never upload it to a store. See `QuickyAdmin/PHASE_I8_INTERNAL_APK_TEST_GUIDE.md`.

**Tests:** `flutter analyze` (3 known infos) and `flutter test` (217).

**iOS (optional):**
- `cd ios && pod install`;
- the Google Maps key is optional: copy `ios/Flutter/Secrets.xcconfig.example` to `Secrets.xcconfig`, which is git-ignored. **Never commit a key.**
- Without a key, maps show "Map unavailable" and nothing crashes.

## 7. QuickyAdmin (admin web, backend)

```
cd QuickyAdmin
flutter pub get
flutter run -d chrome --dart-define=FIREBASE_TARGET=emulator --dart-define=EMU_HOST=127.0.0.1
```

Then sign in with the emulator Super Admin (§4). The admin console signs out after 30 minutes idle.

**Tests:**

| Suite | Command | Expected |
|---|---|---|
| Admin tests | `flutter analyze`, `flutter test` | No issues; 316 |
| Functions unit | `cd functions && npm test` | 154 |
| Rules | `cd security-tests && npm test` and `STAGE=2 npm test` | 55 each; need Java |
| Integration | `./integration-tests/run.sh` | 177; starts its own emulators; needs Java on `PATH` |
| Pre-deploy (read-only) | `./scripts/predeploy-check.sh ../Foodie-Bell` | 8 PASS, 1 known WARN |

**Full baseline: 974 automated tests.**

## 8. Local configuration templates

| File | Purpose | Committed? |
|---|---|---|
| `Foodie-Bell/ios/Flutter/Secrets.xcconfig.example` | iOS Maps key template (`GMS_API_KEY =`) | template yes; the real `Secrets.xcconfig` **never** |
| `QuickyAdmin/functions/.env.local.example` → `.env.local` | Emulator-only function settings (`ROUTES_EMULATOR_MODE=haversine`: no Google Routes calls) | template yes; `.env.local` no (git-ignored) |
| `QuickyAdmin/functions/.secret.local.example` → `.secret.local` | Placeholder `ROUTES_API_KEY` for the emulator (not a key) | template yes; `.secret.local` no (git-ignored) |
| Dart defines | `FIREBASE_TARGET`, `EMU_HOST`, `EMU_*_PORT`, `ADMIN_IDLE_MINUTES` | Command line only |

There are no other secrets to set up for local work. Real credentials, keystores, `.p8` keys and service-account files must never be committed (`.gitignore` covers them).

## 9. Financial configuration: defaults vs approved go-live terms

| Term | Server built-in default (no saved config) | Approved for go-live |
|---|---|---|
| Commission | 10% of the tax-inclusive item value | 10% (same) |
| Manager / Quicky split | **60% / 40%** (`managerShareBps 6000`, deliberately unchanged) | **50% / 50%**: must be **saved** as a new pricing version by an authorised Super Admin before the first live order |
| Platform fee | ₹5 per completed order (Quicky) | ₹5 (same) |
| Delivery slabs | ₹20/30/40/50/60 up to 3/5/7/9/11 km | Same |
| Driver activation ₹25/day, paid promotions ₹100/day | **Not ledger-ready**, off | Off until designed and approved |

- The admin dashboard warns until the approved terms are saved.
- Manager screens show "your share: not yet set by Quicky" while no pricing is saved.
- Orders keep the terms they were priced with.

## 10. What can't be tested locally

These need real Firebase services, release signing or devices: real SMS OTP, Play Integrity and reCAPTCHA, APNs and FCM push delivery, App Check attestation, Google Maps tiles (needs a key), store installs, physical-device background location, and production data and migrations.

## 11. Known issues and deferred items

- **Signing:** Android release signing deferred (P0-6); iOS signing, APNs and App Attest not set up.
- **Data and config:**
  - production migrations and the 50/50 save await owner approval;
  - production rules may differ (P0-1).
- **Admin security:** the admin two-step (TOTP) needs Identity Platform setup; `REQUIRE_ADMIN_MFA` is off.
- **Not built:** auth screens are English-only before login; driver activation and promotion ledgers.
- **Known lint and warnings:** 3 analyzer infos in Foodie-Bell (pre-existing); `Foodie-Bell/storage.rules` is stale (not a deploy source).
- **Full list:** `QuickyAdmin/PHASE_I8_CONSOLIDATED_BLOCKER_REGISTER.md`; rollout plan in `PHASE_I8_BETA_ROLLOUT_RUNBOOK.md`.

## 12. Team testing checklist (emulator)

- **Customer:**
  - sign in by OTP;
  - browse the territory;
  - cart;
  - COD order;
  - UPI order with a UTR;
  - cancel before acceptance;
  - track the order;
  - refund confirm or dispute;
  - switch the language to Telugu.
- **Vendor:**
  - accept or reject;
  - confirm UPI;
  - list order with a photo quote;
  - cancel after acceptance (COD only; UPI post-acceptance cancellation stays **disabled**);
  - record a refund with evidence;
  - incidents show only its own.
- **Driver:**
  - go online;
  - claim an offer;
  - handover code;
  - delivery code with photo;
  - COD collection;
  - earnings.
- **Territory Manager:**
  - onboard a vendor;
  - daily settlement;
  - record and acknowledge transfers;
  - incidents and refunds lists;
  - sees only their own figures.
- **Super Admin:**
  - dashboard go-live warning;
  - save 50/50 pricing (emulator);
  - App Version Policy (raising a minimum blocks older builds' orders);
  - refunds and the notification center;
  - Manager takeover;
  - idle sign-out.

## 13. Reporting defects

Open an issue (or the team tracker) with:
- the repository and commit (`git log -1 --oneline`);
- the device or emulator and OS version;
- the role and steps;
- expected vs actual;
- screenshots;
- relevant `flutter run` / logcat lines.

**Never include real phone numbers, OTP codes, tokens or production data.** Tag financial issues `finance` and security issues `security` (report security privately).
