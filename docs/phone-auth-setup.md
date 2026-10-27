# Phone authentication: setup and rollout

Foodie-Bell signs in every role (User, Vendor, Driver, Manager) with Firebase Phone Auth. The fixed demo OTP and anonymous sign-in are gone.

The server decides which account and role a verified phone number belongs to, using two callable Cloud Functions in `QuickyAdmin/functions/index.js`:

- **`resolveSession`:** takes the number from the caller's verified ID token, binds the matching account doc (`authUid`), and sets the `role`/`accountId` custom claims.
- **`registerCustomer`:** creates `users/{uid}` (role is always User), or returns the number's existing account instead.

## Rollout order

The two sign-in functions are already deployed. The rest of the rollout — the remaining functions, Super Admin grant, data migration and the new rules — is in [roles-and-access.md](roles-and-access.md#rollout); follow that order. Don't deploy `firestore.rules` on its own before then: it now relies on the role claims and migrated data from that rollout.

No account data migration is needed for sign-in itself. Each existing account doc is bound to its owner's phone sign-in the first time they log in.

## Firebase Console

- **Authentication → Sign-in method → Phone:** enable it.
- **Authentication → Settings → SMS region policy:** allow India only. The app only accepts `+91` numbers, and this limits SMS fraud.
- **Android** (Project settings → Android app `com.codeharbor.quickmandi`). No SHA fingerprints are registered yet, and phone auth needs them.
  - Add this machine's debug key:
    - SHA-1 `82:D8:33:DB:A6:E2:0A:37:65:A8:81:CE:D3:99:6E:B6:CC:8C:CA:88`
    - SHA-256 `DC:0C:15:42:90:96:B6:07:3C:B1:0D:29:53:4A:57:86:5B:46:3E:C8:D8:D4:52:C1:AE:BE:F4:BD:08:20:02:0E`
  - Add the release key's SHA-1/SHA-256, and the Play App Signing key's once the app is on Play.
  - `android/app/build.gradle.kts` still signs release builds with the debug key. Set up a real release key before shipping.
  - Enable the **Play Integrity API** in Google Cloud for this project.
- **iOS** (Project settings → Cloud Messaging → Apple app):
  - Upload an **APNs authentication key (.p8)**. Without it, verification falls back to a reCAPTCHA web page.
  - That fallback's URL scheme is already in `ios/Runner/Info.plist`.
  - The simulator always uses the reCAPTCHA fallback.

## Test phone numbers

Firebase test numbers (`Authentication → Sign-in method → Phone → Phone numbers for testing`) sign in without an SMS. The server limits what they can reach:

- **They can't reach real accounts.** A test number only resolves to accounts flagged `isTestAccount: true`. A real account that shares the number is never matched or bound.
- **Customers registered from a test number** are flagged `isTestAccount: true` automatically.
- **To test a Vendor, Driver or Manager flow,** create that account as usual, then set `isTestAccount: true` on its doc in the Firestore Console. No app or client can set or change that field (enforced by the rules).
- **The list is read live** from the project's Auth config, cached for 5 minutes. If it can't be read, sign-in fails closed.
- **The read uses the functions' runtime service account**, which needs permission to read Auth config. The default compute account has it. If you've restricted that account, grant it **Firebase Authentication Viewer**.
- **Use fictional numbers only,** never a real person's number.

For local emulator runs only, list test numbers in `EMULATOR_TEST_PHONE_NUMBERS`. It's ignored outside the emulator.

## What the rules enforce

See [roles-and-access.md](roles-and-access.md) — the rules now authorize by role, account and territory claims rather than only by sign-in method.
