import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/session/session_controller.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/vendor.dart';
import '../../data/providers/firestore_vendors_provider.dart';
import '../../data/providers/mock_accounts_provider.dart';

/// Fallback id used only when a Vendor-role screen builds outside a real
/// session (there shouldn't be one in practice — the router guards every
/// `/vendor/...` route on an active session — but a screen can still exist
/// for one more frame while `logout()` clears the session and the router
/// redirect catches up). Deliberately doesn't match any real id, so
/// [currentVendorProvider] and [currentVendorCategoryProvider] correctly
/// fall through to their own blank-placeholder branch below instead of that
/// one frame flashing a real-looking storefront that isn't this vendor's,
/// most visibly right after logging out.
const kDemoVendorId = '';

/// The signed-in vendor's real id (`Account.id` from `sessionControllerProvider`)
/// — every Vendor-role screen should key its data (catalogue, orders,
/// reviews, ...) off this rather than the old hardcoded [kDemoVendorId], so
/// Smoke & Patty's login actually sees Smoke & Patty's own data instead of
/// always showing Bella Napoli's.
final currentVendorIdProvider = Provider<String>((ref) {
  final account = ref.watch(sessionControllerProvider.select((s) => s.account));
  return account?.id ?? kDemoVendorId;
});

/// The signed-in vendor's [VendorCategory] — read off their `Account.category`
/// (set for real, Firestore-backed vendor identities, e.g. one a Manager
/// created), falling back to Food for a vendor identity with none (keeps
/// category-aware catalogue screens from crashing rather than reflecting
/// the truth for that edge case).
final currentVendorCategoryProvider = Provider<VendorCategory>((ref) {
  final account = ref.watch(sessionControllerProvider.select((s) => s.account));
  final accountCategory = account?.category;
  if (accountCategory != null) {
    for (final category in VendorCategory.values) {
      // Matches `category.id` (how vendors are created going forward —
      // manager_vendor_create_screen.dart), falling back to `category.label`
      // for vendor accounts created before that fix stored the display
      // label ("Pharmacy") instead of the stable id ("pharmacy") here.
      if (category.name == accountCategory ||
          category.label == accountCategory) {
        return category;
      }
    }
  }
  return VendorCategory.food;
});

/// This vendor's storefront record — name, cover photo, rating, delivery
/// fee/time, `isOpen`, and so on — synthesized from the session `Account`,
/// since there's no per-vendor storefront persistence yet, only the
/// Firestore-backed catalogue (`firestore_products_provider.dart`). Lets
/// Dashboard/Profile/Store Hours read a [Vendor] unconditionally instead of
/// crashing on a `firstWhere` that finds nothing.
final currentVendorProvider = Provider<Vendor>((ref) {
  final vendorId = ref.watch(currentVendorIdProvider);
  final account = ref.watch(sessionControllerProvider.select((s) => s.account));
  final category = ref.watch(currentVendorCategoryProvider);
  return Vendor(
    id: vendorId,
    name: account?.name ?? 'My Store',
    category: category,
    coverImageUrl: 'https://images.unsplash.com/photo-1490645935967-10de6ba17061?w=1000&q=80',
    tags: const [],
    rating: 0,
    ratingCount: 0,
    deliveryTimeMinutes: 30,
    deliveryFee: 20,
    distanceKm: 0,
    products: const [],
    rebatePercent: account?.rebatePercent ?? 15,
  );
});

/// Vendor's own "Open/Closed" toggle (Dashboard/Profile) — writes to the
/// real `vendors` Firestore doc when this identity has one
/// (`setVendorOpen`), or the in-memory mock store for the two demo logins
/// (`ven1`/`ven2`), which have no real vendor doc to update. Mirrors
/// `vendor_profile_edit_screen.dart`'s `isFirestoreBacked` check for the
/// same dual-path reason.
Future<void> setCurrentVendorOpen(WidgetRef ref, String vendorId, bool isOpen) async {
  final isFirestoreBacked = ref.read(firestoreVendorsProvider).valueOrNull?.any((v) => v.id == vendorId) ?? false;
  if (isFirestoreBacked) {
    await setVendorOpen(vendorId, isOpen);
  } else {
    ref.read(mockAccountsProvider.notifier).setOpen(vendorId, isOpen);
  }
}

/// Confirms before flipping the Open/Closed switch either direction —
/// closing takes the store off User Home immediately (`vendor_account_card.dart`'s
/// "CLOSED" overlay, `vendor_detail_screen.dart` blocking new orders), and
/// re-opening puts it straight back in front of customers, so both
/// directions are worth a deliberate confirm rather than a stray tap.
Future<void> confirmAndSetVendorOpen(BuildContext context, WidgetRef ref, String vendorId, bool goingOpen) async {
  final palette = context.colors;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      icon: Icon(
        goingOpen ? Icons.storefront_rounded : Icons.storefront_outlined,
        color: goingOpen ? palette.success : palette.error,
        size: 32,
      ),
      title: Text(goingOpen ? 'Open your store?' : 'Close your store?'),
      content: Text(
        goingOpen
            ? 'Customers will be able to see your store on Home and place new orders again.'
            : 'Your store will disappear from customers\' ordering flow until you turn availability back on.',
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
        ElevatedButton(
          style: goingOpen ? null : ElevatedButton.styleFrom(backgroundColor: palette.error),
          onPressed: () => Navigator.pop(dialogContext, true),
          child: Text(goingOpen ? 'Open Store' : 'Close Store'),
        ),
      ],
    ),
  );
  if (confirmed == true) await setCurrentVendorOpen(ref, vendorId, goingOpen);
}
