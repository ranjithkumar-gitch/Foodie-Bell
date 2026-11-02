import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geocoding/geocoding.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/address.dart';
import '../../../data/providers/device_position_provider.dart';
import '../../../data/providers/firestore_addresses_provider.dart';
import '../../../l10n/app_localizations_context.dart';
import 'pin_location_screen.dart';

/// Where a typed address is on the map (the device geocoder); null if it
/// can't be found.
Future<LatLng?> lookUpAddressOnMap(String query) async {
  if (query.trim().isEmpty) return null;
  try {
    final results = await Geocoding().locationFromAddress(query);
    return results.isEmpty ? null : LatLng(results.first.latitude, results.first.longitude);
  } catch (e) {
    debugPrint('pin_saved_address: address lookup failed: $e');
    return null;
  }
}

Future<LatLng?> _confirmOnMap(BuildContext context, LatLng start) => Navigator.of(context).push<LatLng>(
  MaterialPageRoute(fullscreenDialog: true, builder: (_) => PinLocationScreen(initial: start)),
);

Future<void> _savePin(String addressId, LatLng pin) => pinSavedAddress(addressId, latitude: pin.latitude, longitude: pin.longitude);

/// "Pin this address" for a saved address with no usable delivery point
/// (saved before a pin was required). The map starts at the address as
/// typed; if it can't be found there, the User is *asked* whether to start
/// from the phone's position instead — never used without asking — and
/// either way they place and confirm the pin themselves
/// ([PinLocationScreen]). Saves and returns the pinned address only for a
/// confirmed, valid pin; null otherwise.
///
/// [lookUp], [deviceStart], [confirmOnMap] and [save] default to the real
/// geocoder, GPS, map screen and Firestore write; tests replace them.
Future<Address?> pinSavedAddressFlow(
  BuildContext context,
  WidgetRef ref,
  Address address, {
  Future<LatLng?> Function(String query) lookUp = lookUpAddressOnMap,
  Future<LatLng?> Function()? deviceStart,
  Future<LatLng?> Function(BuildContext context, LatLng start) confirmOnMap = _confirmOnMap,
  Future<void> Function(String addressId, LatLng pin) save = _savePin,
}) async {
  final l10n = context.l10n;
  final messenger = ScaffoldMessenger.maybeOf(context);
  var start = await lookUp(fullAddressText(address));
  if (!context.mounted) return null;
  if (start == null) {
    final useDevice = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.addressPinNotFoundTitle),
        content: Text(l10n.addressPinNotFoundBody),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: Text(l10n.addressPinNotNow)),
          ElevatedButton(onPressed: () => Navigator.pop(dialogContext, true), child: Text(l10n.addressPinUseMyLocation)),
        ],
      ),
    );
    if (useDevice != true || !context.mounted) return null;
    start = await (deviceStart ?? () => ref.read(devicePositionProvider.future))();
    if (!context.mounted) return null;
    if (start == null) {
      messenger?.showSnackBar(SnackBar(content: Text(l10n.addressPinNoLocation)));
      return null;
    }
  }
  final pin = await confirmOnMap(context, start);
  if (pin == null || !isValidDeliveryPin(pin.latitude, pin.longitude)) return null;
  await save(address.id, pin);
  messenger?.showSnackBar(SnackBar(content: Text(l10n.addressPinSaved)));
  return address.withPin(pin.latitude, pin.longitude);
}

/// The "not pinned yet" notice with its "Pin this address" button, shown on
/// an address card while [Address.hasValidPin] is false.
class AddressPinNotice extends StatelessWidget {
  const AddressPinNotice({super.key, required this.onPin, this.busy = false});

  final VoidCallback onPin;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final color = context.colors.error;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 6,
        runSpacing: 4,
        children: [
          Icon(Icons.location_off_outlined, size: 16, color: color),
          Text(context.l10n.addressNotPinned, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
          OutlinedButton.icon(
            onPressed: busy ? null : onPin,
            icon: busy
                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.push_pin_outlined, size: 16),
            label: Text(context.l10n.addressPinThis),
          ),
        ],
      ),
    );
  }
}
