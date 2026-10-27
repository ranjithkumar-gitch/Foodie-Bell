# Roles and access control

How Quicky decides who can see and do what. Phone sign-in is covered in [phone-auth-setup.md](phone-auth-setup.md).

## The model

**Identity.** The Firebase Auth UID is the identity:
- Customers, Vendors, Drivers and Managers sign in with Firebase Phone Auth.
- The Super Admin signs in to QuickyAdmin with email and password.

**Authorization.** Access comes from **custom claims** on the Firebase user. Only Cloud Functions in `QuickyAdmin/functions/index.js` set them:

| Claim | Meaning |
|---|---|
| `role` | `user` (Customer), `vendor`, `driver`, `manager`, or `superAdmin` |
| `accountId` | The caller's own `users`/`vendors`/`drivers`/`managers` doc ID |
| `territoryId` | The territory a Manager runs, or a Vendor or Driver works in |
| `active` | `true` only while that account is approved and not deleted |

**Profiles.** Firestore account docs hold profile information only; nothing in them grants access. The private parts sit apart from the main doc:
- KYC files are in Storage, referenced only by path.
- Manager bank details are in `managers/{id}/private/bank`.
- Pickup and delivery codes are in `orders/{id}/codes/*`.

### How claims are assigned and refreshed

- **On sign-in.** `resolveSession` and `registerCustomer` bind the account doc to the caller's UID and set its claims.
- **When an account changes.** Approval, suspension, soft-delete or a territory change on any account doc triggers `sync{Manager,Vendor,Driver,User}Claims`, and a territory reassignment triggers `syncTerritoryManagerClaims`. Each one:
  - recomputes the claims;
  - touches `claimSync/{uid}`, so the open app refreshes its token straight away (`claim_sync.dart`);
  - revokes the user's refresh tokens if they lost access, which signs them out everywhere.
- **Super Admin.** Granted and revoked only by a project owner running `QuickyAdmin/functions/scripts/super-admin.js`. Nothing else grants it, including an email address.

### Who can access what (enforced by `firestore.rules` and `storage.rules`)

| | Customer | Vendor | Driver | Manager | Super Admin |
|---|---|---|---|---|---|
| Orders | own | placed with them | assigned to them, plus open offers in their territory (when approved) | their territory, read-only | all |
| Pickup/delivery codes | delivery code of own orders | handover code of own orders | never; confirmed by the server | — | all |
| Customer profiles, addresses, carts | own only | — | — | — | all |
| Vendor records | storefront info | own (operational fields and KYC upload) | storefront info | approve, suspend and review KYC in their territory | all |
| Driver records | — (driver position comes via their order) | — | own | their territory | all |
| KYC files | — | own | own | their territory's | all |
| Tickets and messages | own | own | own | own, plus those addressed to them | all |
| Promotions | read | request in own territory | read | approve in their territory | all |
| Catalogue (categories, tax, global products) | read | read; own products | read | read | write |

Server-only actions:
- **Pickup and delivery** go through `confirmPickup` and `confirmDelivery`. They check the code, lock after 5 wrong attempts, and only the order's assigned Driver can call them.
- **Pushes and branding:** `sendPushNotification`, `activateOccasionTheme` and `resetOccasionTheme` are Super Admin only.

## Rollout

Order matters. Steps 6 and 7 lock out older app builds and anyone without the new claims.

1. **Deploy the Cloud Functions** (from `QuickyAdmin`):
   ```sh
   firebase deploy --only functions
   ```
2. **Grant Super Admin** to the admin console account:
   ```sh
   cd functions && node scripts/super-admin.js grant admin@qm.com
   ```
   Run it with your own credentials (`gcloud auth application-default login`).
3. **Change that account's password.** The old one, `Admin@123`, was pre-filled in QuickyAdmin's login screen source.
4. **Ship the new Foodie-Bell and QuickyAdmin builds.** They work under the current rules too.
5. **Migrate existing data.** Dry run first, then apply:
   ```sh
   node scripts/migrate-step3.js
   node scripts/migrate-step3.js --apply
   ```
   This adds territory IDs, moves KYC URLs to paths (rotating the old download tokens), moves bank details and order codes to private docs, and writes out delivery addresses. Fix any territories it warns about.
6. **Deploy the rules** (identical in both repos):
   ```sh
   firebase deploy --only firestore:rules,storage
   ```
   The first Storage deploy asks to let Storage rules read Firestore; allow it, since KYC access checks the Manager's territory. If you need to roll back, Firebase Console → Firestore/Storage → Rules → history.
7. **Clean up in the Firebase Console:**
   - Disable the **Anonymous** sign-in provider.
   - Delete the old Manager email/password users. Keep the Super Admin.

## Testing

Emulator suites covered all of this (they live outside the repos):
- 70 Firestore rule cases across every role
- the claim triggers, order-code callables and Super Admin script
- Storage KYC access
- the migration on seeded legacy data

One thing the emulator can't check: whether a suspended account's sessions are actually revoked. That relies on Firebase's standard `revokeRefreshTokens`.

## Known gaps

- **Online payments are still client-trusted.** An order's `paymentId` is written by the app, and the Razorpay signature isn't verified on the server.
- **Manager docs are readable by every signed-in user** (for support contact details). That includes `territoryFee` and `territoryFeePaidAt`; bank details are private.
- **Open delivery offers expose the customer's name and drop-off address** to every approved Driver in that territory until one takes the order.
- **FCM topics aren't access-controlled.** Anyone who knows an account ID can subscribe to its `account_<id>` notifications.
- **There's no photo proof-of-delivery any more.** The old screen only picked a photo without uploading it, and marked the order delivered without the code. If a customer can't be reached, the Driver contacts their Manager.
