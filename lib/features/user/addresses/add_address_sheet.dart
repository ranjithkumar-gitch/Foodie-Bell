import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FilteringTextInputFormatter;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../core/session/session_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/address.dart';
import '../../../data/providers/firestore_addresses_provider.dart';
import '../../../l10n/app_localizations_context.dart';
import '../../../shared/error_reporting.dart';
import '../address_label_text.dart';
import 'pin_location_screen.dart';

/// Shared "Add Address" bottom sheet — used by both the Saved Addresses
/// screen and the Checkout address-selection screen (which needs the same
/// add-new-address capability without leaving the checkout flow). Writes a
/// real `addresses` doc (`firestore_addresses_provider.dart`) for the
/// signed-in User; pass [onSaved] to react to the newly created address
/// (e.g. auto-selecting it for checkout).
///
/// The address is saved only with a map pin the User confirmed themselves
/// ([PinLocationScreen]) — started from the phone's position or from the
/// typed address. The delivery fee and the Driver's route come from that
/// pin, so it's never taken silently from wherever the phone happens to be.
class AddAddressSheet extends ConsumerStatefulWidget {
  const AddAddressSheet({super.key, this.onSaved});

  final ValueChanged<Address>? onSaved;

  @override
  ConsumerState<AddAddressSheet> createState() => _AddAddressSheetState();
}

class _AddAddressSheetState extends ConsumerState<AddAddressSheet> {
  final _formKey = GlobalKey<FormState>();
  AddressLabel _label = AddressLabel.home;
  late final _nameController = TextEditingController(
    text: ref.read(sessionControllerProvider).account?.name ?? '',
  );
  late final _phoneController = TextEditingController(
    text: ref.read(sessionControllerProvider).account?.phone ?? '',
  );
  final _line1Controller = TextEditingController();
  final _landmarkController = TextEditingController();
  final _pincodeController = TextEditingController();
  final _cityController = TextEditingController();
  /// Set only by the User confirming a pin ([_confirmPin]).
  double? _latitude;
  double? _longitude;
  bool _locating = false;

  bool get _pinned => isValidDeliveryPin(_latitude, _longitude);
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _line1Controller.dispose();
    _landmarkController.dispose();
    _pincodeController.dispose();
    _cityController.dispose();
    super.dispose();
  }

  /// Where the User's phone is right now, or what stopped it being read
  /// (GPS off, permission refused, no fix in time).
  Future<({Position? position, String? problem})> _locate() async {
    final l10n = context.l10n;
    String? problem;
    Position? position;
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        problem = l10n.addAddressLocationGpsOff;
      } else {
        var permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }
        if (permission == LocationPermission.denied ||
            permission == LocationPermission.deniedForever) {
          problem = l10n.addAddressLocationPermissionNeeded;
        } else {
          position = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
              timeLimit: Duration(seconds: 20),
            ),
          );
        }
      }
    } catch (e, st) {
      problem = friendlyError(
        e,
        action: 'Getting your location',
        stackTrace: st,
      );
    }
    return (position: position, problem: problem);
  }

  /// Opens the map at [start] for the User to place and confirm the pin;
  /// keeps the pin only if they confirm, and fills house/street, pincode
  /// and city from where the pin was dropped — not from where the map
  /// started — so the saved address always matches the pin. Only staged
  /// here — it's written along with the rest of the form on "Save Address".
  Future<void> _confirmPin(LatLng start) async {
    final pinned = await Navigator.of(context).push<LatLng>(
      MaterialPageRoute(fullscreenDialog: true, builder: (_) => PinLocationScreen(initial: start)),
    );
    if (pinned == null || !mounted) return;
    setState(() {
      _latitude = pinned.latitude;
      _longitude = pinned.longitude;
      _error = null;
      _locating = true;
    });
    // A convenience on top: when the lookup fails the pin is still kept and
    // the User types the fields in themselves.
    final place = await placemarkAt(pinned);
    if (!mounted) return;
    setState(() {
      _locating = false;
      if (place != null) _fillFrom(place);
    });
  }

  /// Starts the pin from the typed address, looked up on the map.
  Future<void> _pinFromTypedAddress() async {
    final query = [_line1Controller.text, _cityController.text, _pincodeController.text]
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .join(', ');
    final notFound = context.l10n.addAddressPinNotFound;
    setState(() {
      _locating = true;
      _error = null;
    });
    LatLng? start;
    if (query.isNotEmpty) {
      try {
        final results = await Geocoding().locationFromAddress(query);
        if (results.isNotEmpty) start = LatLng(results.first.latitude, results.first.longitude);
      } catch (e) {
        debugPrint('add_address_sheet: address lookup failed: $e');
      }
    }
    if (!mounted) return;
    setState(() {
      _locating = false;
      if (start == null) _error = notFound;
    });
    if (start != null) await _confirmPin(start);
  }

  /// Starts the pin where the User's phone is right now — meant to be
  /// tapped while standing at the address. The pin still has to be
  /// confirmed on the map, and the fields are filled from that pin.
  Future<void> _useCurrentLocation() async {
    setState(() {
      _locating = true;
      _error = null;
    });
    final (:position, :problem) = await _locate();
    if (!mounted) return;
    setState(() {
      _locating = false;
      _error = problem;
    });
    if (position != null) await _confirmPin(LatLng(position.latitude, position.longitude));
  }

  /// Fills house/street, pincode and city from [place], leaving alone any
  /// field the lookup has nothing for.
  void _fillFrom(Placemark place) {
    final lineParts = <String>[];
    for (final part in [place.name, place.thoroughfare, place.subLocality]) {
      final text = (part ?? '').trim();
      if (text.isNotEmpty && !lineParts.contains(text)) lineParts.add(text);
    }
    if (lineParts.isNotEmpty) _line1Controller.text = lineParts.join(', ');

    final pincode = (place.postalCode ?? '').trim();
    if (pincode.isNotEmpty) _pincodeController.text = pincode;

    final locality = (place.locality ?? '').trim();
    final city = locality.isNotEmpty
        ? locality
        : (place.subAdministrativeArea ?? '').trim();
    if (city.isNotEmpty) _cityController.text = city;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    // The server prices delivery from this pin and refuses an address
    // without one, so it's required here rather than discovered at checkout.
    if (!_pinned) {
      setState(() => _error = context.l10n.addAddressPinRequired);
      return;
    }
    final userId = ref.read(sessionControllerProvider).account?.id;
    if (userId == null) return;

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final saved = await addAddress(
        userId,
        Address(
          id: '',
          label: _label,
          recipientName: _nameController.text.trim(),
          recipientPhone: _phoneController.text.trim(),
          line1: _line1Controller.text.trim(),
          landmark: _landmarkController.text.trim().isEmpty
              ? null
              : _landmarkController.text.trim(),
          pincode: _pincodeController.text.trim(),
          city: _cityController.text.trim(),
          latitude: _latitude,
          longitude: _longitude,
        ),
      );
      if (!mounted) return;
      Navigator.pop(context);
      widget.onSaved?.call(saved);
    } catch (e, st) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = friendlyError(e, action: 'Saving address', stackTrace: st);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Form(
          key: _formKey,
          // Scrolls rather than overflowing once the keyboard is up.
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: palette.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  context.l10n.addAddressTitle,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 16),
                Text(
                  context.l10n.addAddressLabelHeading,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: palette.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    for (final label in AddressLabel.values) ...[
                      Expanded(
                        child: _LabelChoice(
                          label: label,
                          selected: _label == label,
                          onTap: _saving
                              ? () {}
                              : () => setState(() => _label = label),
                        ),
                      ),
                      if (label != AddressLabel.values.last)
                        const SizedBox(width: 10),
                    ],
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _nameController,
                        enabled: !_saving,
                        decoration: InputDecoration(
                          labelText: context.l10n.addAddressRecipientName,
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? context.l10n.fieldRequired
                            : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _phoneController,
                        enabled: !_saving,
                        keyboardType: TextInputType.phone,
                        maxLength: 10,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        decoration: InputDecoration(
                          labelText: context.l10n.addAddressPhoneNumber,
                          counterText: '',
                        ),
                        validator: (v) => (v == null || v.trim().length != 10)
                            ? context.l10n.addAddressPhoneDigitsError
                            : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _line1Controller,
                  enabled: !_saving,
                  decoration: InputDecoration(
                    labelText: context.l10n.addAddressHouseStreet,
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? context.l10n.fieldRequired
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _landmarkController,
                  enabled: !_saving,
                  decoration: InputDecoration(
                    labelText: context.l10n.addAddressLandmarkOptional,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _pincodeController,
                        enabled: !_saving,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: context.l10n.addAddressPincode,
                        ),
                        validator: (v) => (v == null || v.trim().length != 6)
                            ? context.l10n.addAddressPincodeDigitsError
                            : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _cityController,
                        enabled: !_saving,
                        decoration: InputDecoration(
                          labelText: context.l10n.addAddressCity,
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? context.l10n.fieldRequired
                            : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  context.l10n.addAddressPinHeading,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: palette.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(
                      _pinned ? Icons.check_circle_rounded : Icons.location_off_outlined,
                      size: 18,
                      color: _pinned ? palette.success : palette.warning,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _pinned ? context.l10n.addAddressPinConfirmed : context.l10n.addAddressPinRequired,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: _pinned ? palette.success : palette.textSecondary,
                        ),
                      ),
                    ),
                    if (_pinned)
                      TextButton(
                        onPressed: _saving || _locating ? null : () => _confirmPin(LatLng(_latitude!, _longitude!)),
                        child: Text(context.l10n.addAddressPinChange),
                      ),
                  ],
                ),
                if (_locating)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Row(
                      children: [
                        const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                        const SizedBox(width: 10),
                        Text(context.l10n.addAddressGettingLocation),
                      ],
                    ),
                  )
                else if (!_pinned) ...[
                  TextButton.icon(
                    onPressed: _saving ? null : _useCurrentLocation,
                    icon: const Icon(Icons.my_location_rounded, size: 18),
                    label: Text(context.l10n.addAddressUseCurrentLocation),
                  ),
                  TextButton.icon(
                    onPressed: _saving ? null : _pinFromTypedAddress,
                    icon: const Icon(Icons.map_outlined, size: 18),
                    label: Text(context.l10n.addAddressPinFromAddress),
                  ),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 14),
                  Text(
                    _error!,
                    style: TextStyle(
                      color: palette.error,
                      fontWeight: FontWeight.w600,
                      fontSize: 12.5,
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.4,
                            ),
                          )
                        : Text(context.l10n.addAddressSaveButton),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LabelChoice extends StatelessWidget {
  const _LabelChoice({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final AddressLabel label;
  final bool selected;
  final VoidCallback onTap;

  IconData get _icon => switch (label) {
    AddressLabel.home => Icons.home_rounded,
    AddressLabel.work => Icons.work_rounded,
    AddressLabel.other => Icons.place_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? palette.primaryLight.withValues(alpha: 0.18)
              : palette.surfaceMuted,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? palette.primary : Colors.transparent,
            width: 1.4,
          ),
        ),
        child: Column(
          children: [
            Icon(
              _icon,
              size: 18,
              color: selected ? palette.primary : palette.textSecondary,
            ),
            const SizedBox(height: 4),
            Text(
              addressLabelText(context, label),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: selected ? palette.primary : palette.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
