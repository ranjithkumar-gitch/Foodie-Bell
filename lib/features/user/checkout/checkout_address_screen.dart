import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/session/session_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/address.dart';
import '../../../data/providers/firestore_addresses_provider.dart';
import '../../../l10n/app_localizations_context.dart';
import '../../../shared/error_reporting.dart';
import '../addresses/add_address_sheet.dart';
import '../addresses/pin_saved_address.dart';
import '../address_label_text.dart';

/// Checkout – Address Selection (spec §4.9). Real, per-User saved addresses
/// (`firestoreAddressesProvider`) with an inline "Add new address" tile so
/// checkout never dead-ends on an empty list.
class CheckoutAddressScreen extends ConsumerStatefulWidget {
  const CheckoutAddressScreen({super.key});

  @override
  ConsumerState<CheckoutAddressScreen> createState() => _CheckoutAddressScreenState();
}

class _CheckoutAddressScreenState extends ConsumerState<CheckoutAddressScreen> {
  void _showAddAddressSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddAddressSheet(
        onSaved: (address) => ref.read(selectedAddressProvider.notifier).state = address,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    final userId = ref.watch(sessionControllerProvider).account?.id;
    final addressesAsync = userId == null
        ? const AsyncValue<List<Address>>.data(<Address>[])
        : ref.watch(firestoreAddressesProvider(userId));
    final picked = ref.watch(selectedAddressProvider);
    // The picked address as currently saved (e.g. just pinned).
    final selected = picked == null
        ? null
        : addressesAsync.valueOrNull?.where((a) => a.id == picked.id).firstOrNull ?? picked;
    final canDeliverHere = selected != null && selected.hasValidPin;

    // Nothing picked yet (fresh checkout, or the only-just-loaded address
    // list) — default to the saved default, or just the first one, same as
    // the old always-non-empty mock list used to via its initial state.
    final loadedAddresses = addressesAsync.valueOrNull;
    if (selected == null && loadedAddresses != null && loadedAddresses.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || ref.read(selectedAddressProvider) != null) return;
        // Prefer an address the order can actually be priced to (pinned).
        final pinned = loadedAddresses.where((a) => a.hasValidPin).toList();
        final pool = pinned.isNotEmpty ? pinned : loadedAddresses;
        final defaultMatch = pool.where((a) => a.isDefault);
        final fallback = defaultMatch.isNotEmpty ? defaultMatch.first : pool.first;
        ref.read(selectedAddressProvider.notifier).state = fallback;
      });
    }

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.checkoutAddressTitle)),
      body: addressesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text(friendlyError(e, action: 'Loading addresses', stackTrace: st))),
        data: (addresses) => ListView.separated(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          itemCount: addresses.length + 1,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, i) {
            if (i == addresses.length) {
              return InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => _showAddAddressSheet(context, ref),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: palette.primary, width: 1.4, style: BorderStyle.solid),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.add_location_alt_rounded, color: palette.primary),
                      const SizedBox(width: 12),
                      Text(context.l10n.checkoutAddNewAddress, style: TextStyle(fontWeight: FontWeight.w700, color: palette.primary)),
                    ],
                  ),
                ),
              );
            }
            final address = addresses[i];
            final isSelected = selected?.id == address.id;
            return InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => ref.read(selectedAddressProvider.notifier).state = address,
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isSelected ? palette.primaryLight.withValues(alpha: 0.15) : palette.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: isSelected ? palette.primary : palette.border, width: isSelected ? 1.6 : 1),
                ),
                child: Row(
                  children: [
                    Icon(
                      address.label == AddressLabel.home ? Icons.home_rounded : (address.label == AddressLabel.work ? Icons.work_rounded : Icons.place_rounded),
                      color: palette.primary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(addressLabelText(context, address.label), style: const TextStyle(fontWeight: FontWeight.w700)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '${address.recipientName} · ${address.recipientPhone}',
                                  style: TextStyle(color: palette.textSecondary, fontSize: 12.5, fontWeight: FontWeight.w600),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text('${address.line1}, ${address.city} - ${address.pincode}', style: TextStyle(color: palette.textSecondary, fontSize: 13)),
                          if (!address.hasValidPin)
                            AddressPinNotice(
                              onPin: () async {
                                final pinned = await pinSavedAddressFlow(context, ref, address);
                                if (pinned != null && mounted) ref.read(selectedAddressProvider.notifier).state = pinned;
                              },
                            ),
                        ],
                      ),
                    ),
                    Icon(isSelected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded, color: isSelected ? palette.primary : palette.textMuted),
                  ],
                ),
              ),
            );
          },
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // The server prices delivery from the pin and refuses an
              // address without one, so checkout doesn't go on without it.
              if (selected != null && !selected.hasValidPin) ...[
                Text(context.l10n.checkoutAddressNeedsPin, style: TextStyle(color: palette.error, fontWeight: FontWeight.w600, fontSize: 12.5)),
                const SizedBox(height: 8),
              ],
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: canDeliverHere ? () => context.push('/user/checkout/payment') : null,
                  child: Text(context.l10n.checkoutDeliverHere),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
