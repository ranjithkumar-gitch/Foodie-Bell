import 'package:flutter/material.dart';
import '../../../core/maps/maps_availability.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations_context.dart';

/// Full-screen "Confirm delivery location": the map starts at [initial]
/// (the phone's position, or the typed address looked up on the map) and
/// the User moves it until the fixed centre pin sits on the entrance. Pops
/// the pinned [LatLng] only when the User taps Confirm — closing the screen
/// any other way pins nothing. The delivery fee and the Driver's route are
/// worked out from this point (`quoteOrder`), so it's never filled in
/// silently.
class PinLocationScreen extends StatefulWidget {
  const PinLocationScreen({super.key, required this.initial});

  final LatLng initial;

  @override
  State<PinLocationScreen> createState() => _PinLocationScreenState();
}

class _PinLocationScreenState extends State<PinLocationScreen> {
  late LatLng _center = widget.initial;

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
          child: ElevatedButton(
            onPressed: () => Navigator.pop(context, _center),
            child: Text(context.l10n.pinScreenConfirm),
          ),
        ),
      ),
    );
  }
}
