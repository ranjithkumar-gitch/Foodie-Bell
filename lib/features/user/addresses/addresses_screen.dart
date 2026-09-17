import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/session/session_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/address.dart';
import '../../../data/providers/firestore_addresses_provider.dart';
import '../../../l10n/app_localizations_context.dart';
import '../../../shared/error_reporting.dart';
import '../address_label_text.dart';
import 'add_address_sheet.dart';

/// Saved Addresses (spec §4.18, and doubling as the registration-flow's
/// "Delivery Address Setup" step — reachable from Profile at any time).
/// Real CRUD backed by [firestoreAddressesProvider], one Firestore doc per
/// address for the signed-in User. Note: [Address.isDefault] isn't mutable
/// through the current provider (no `.setDefault` write), so "set as
/// default" below is intentionally cosmetic — it selects the address for
/// checkout via [selectedAddressProvider] instead of mutating the stored
/// record.
class AddressesScreen extends ConsumerWidget {
  const AddressesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.colors;
    final userId = ref.watch(sessionControllerProvider).account?.id;
    final addressesAsync = userId == null
        ? const AsyncValue<List<Address>>.data(<Address>[])
        : ref.watch(firestoreAddressesProvider(userId));
    final selected = ref.watch(selectedAddressProvider);

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.addressesScreenTitle)),
      body: addressesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text(friendlyError(e, action: 'Loading addresses', stackTrace: st))),
        data: (addresses) {
          if (addresses.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.location_off_outlined, size: 48, color: palette.textMuted),
                    const SizedBox(height: 14),
                    Text(context.l10n.addressesEmptyTitle, style: Theme.of(context).textTheme.headlineMedium, textAlign: TextAlign.center),
                    const SizedBox(height: 8),
                    Text(context.l10n.addressesEmptySubtitle, style: Theme.of(context).textTheme.bodyMedium, textAlign: TextAlign.center),
                  ],
                ),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            itemCount: addresses.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, i) {
              final address = addresses[i];
              final isSelected = selected?.id == address.id;
              return _AddressCard(
                address: address,
                isSelected: isSelected,
                onSetDefault: () => ref.read(selectedAddressProvider.notifier).state = address,
                onDelete: () async {
                  try {
                    await removeAddress(address.id);
                  } catch (e, st) {
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(friendlyError(e, action: 'Removing address', stackTrace: st))),
                    );
                  }
                },
              );
            },
          );
        },
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: ElevatedButton.icon(
            onPressed: userId == null ? null : () => _showAddAddressSheet(context),
            icon: const Icon(Icons.add_rounded),
            label: Text(context.l10n.addressesAddButton),
          ),
        ),
      ),
    );
  }

  void _showAddAddressSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const AddAddressSheet(),
    );
  }
}

class _AddressCard extends StatelessWidget {
  const _AddressCard({required this.address, required this.isSelected, required this.onSetDefault, required this.onDelete});

  final Address address;
  final bool isSelected;
  final VoidCallback onSetDefault;
  final VoidCallback onDelete;

  IconData get _labelIcon => switch (address.label) {
    AddressLabel.home => Icons.home_rounded,
    AddressLabel.work => Icons.work_rounded,
    AddressLabel.other => Icons.place_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onSetDefault,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isSelected ? palette.primary : palette.border, width: isSelected ? 1.4 : 1),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: palette.primaryLight.withValues(alpha: 0.18), shape: BoxShape.circle),
              child: Icon(_labelIcon, color: palette.primary, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(addressLabelText(context, address.label), style: const TextStyle(fontWeight: FontWeight.w800)),
                      if (isSelected) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(color: palette.primary.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
                          child: Text(context.l10n.addressDefaultBadge, style: TextStyle(color: palette.primary, fontSize: 10, fontWeight: FontWeight.w800)),
                        ),
                      ],
                      if (!address.isServiceable) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(color: palette.error.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
                          child: Text(context.l10n.addressNotServiceableBadge, style: TextStyle(color: palette.error, fontSize: 10, fontWeight: FontWeight.w800)),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text('${address.recipientName} · ${address.recipientPhone}', style: TextStyle(color: palette.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(address.line1, style: TextStyle(color: palette.textSecondary, fontSize: 13)),
                  if (address.landmark != null) Text(address.landmark!, style: TextStyle(color: palette.textMuted, fontSize: 12)),
                  Text('${address.city} · ${address.pincode}', style: TextStyle(color: palette.textMuted, fontSize: 12)),
                ],
              ),
            ),
            IconButton(
              onPressed: onDelete,
              icon: Icon(Icons.delete_outline_rounded, color: palette.error, size: 20),
              tooltip: context.l10n.addressRemoveTooltip,
            ),
          ],
        ),
      ),
    );
  }
}
