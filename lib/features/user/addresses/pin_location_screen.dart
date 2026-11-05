import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import '../../../core/maps/maps_availability.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations_context.dart';

/// The street address at [point] (the device geocoder) — null when it
/// can't be found, so callers keep the pin and let the User type it in.
Future<Placemark?> placemarkAt(LatLng point) async {
  try {
    final places = await Geocoding().placemarkFromCoordinates(point.latitude, point.longitude);
    return places.isEmpty ? null : places.first;
  } catch (e) {
    debugPrint('pin_location_screen: address lookup failed: $e');
    return null;
  }
}

/// "12-4, Main Road, Gandhi Nagar, Kakinada 533001" — [place] on one line,
/// the same parts the Add Address form fills in.
String placemarkLine(Placemark place) {
  final parts = <String>[];
  for (final part in [place.name, place.thoroughfare, place.subLocality, place.locality, place.postalCode]) {
    final text = (part ?? '').trim();
    if (text.isNotEmpty && !parts.contains(text)) parts.add(text);
  }
  return parts.join(', ');
}

/// Full-screen "Confirm delivery location": the map starts at [initial]
/// (the phone's position, or the typed address looked up on the map) and
/// the User moves it until the fixed centre pin sits on the entrance. The
/// street address under the pin is shown as the map settles, so the User
/// sees what will be saved. Pops the pinned [LatLng] only when the User
/// taps Confirm — closing the screen any other way pins nothing. The
/// delivery fee and the Driver's route are worked out from this point
/// (`quoteOrder`), so it's never filled in silently.
class PinLocationScreen extends StatefulWidget {
  const PinLocationScreen({super.key, required this.initial});

  final LatLng initial;

  @override
  State<PinLocationScreen> createState() => _PinLocationScreenState();
}

class _PinLocationScreenState extends State<PinLocationScreen> {
  late LatLng _center = widget.initial;
  String? _address;

  /// Bumped on every lookup so a slow answer for an earlier spot never
  /// replaces the one for where the pin is now.
  int _lookup = 0;

  @override
  void initState() {
    super.initState();
    _lookUpAddress();
  }

  Future<void> _lookUpAddress() async {
    final lookup = ++_lookup;
    final place = await placemarkAt(_center);
    if (!mounted || lookup != _lookup) return;
    setState(() => _address = place == null ? null : placemarkLine(place));
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.pinScreenTitle)),
      body: Stack(
        alignment: Alignment.center,
        children: [
          MapsGate(child: GoogleMap(
            initialCameraPosition: CameraPosition(target: widget.initial, zoom: 18),
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            onCameraMove: (position) => _center = position.target,
            onCameraIdle: _lookUpAddress,
          )),
          // The pin's tip marks the map centre, so it's lifted by half its height.
          IgnorePointer(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 44),
              child: Icon(Icons.location_on_rounded, size: 48, color: palette.primary),
            ),
          ),
          Positioned(
            top: 12,
            left: 16,
            right: 16,
            child: Material(
              color: palette.surface,
              borderRadius: BorderRadius.circular(12),
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(context.l10n.pinScreenHint, textAlign: TextAlign.center, style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w600)),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_address != null) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.place_outlined, size: 20, color: palette.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(_address!, style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w600, fontSize: 14)),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
              ],
              ElevatedButton(
                onPressed: () => Navigator.pop(context, _center),
                child: Text(context.l10n.pinScreenConfirm),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
