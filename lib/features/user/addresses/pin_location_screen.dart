import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
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
///
/// 2026-11-17: a search bar (area, street, landmark — the phone's own
/// geocoder, no extra API) and a "my location" button move the map; the
/// pin is still only what's confirmed. Also used by Vendors to set their
/// shop location ([title]/[hint]/[confirmLabel] override the wording).
class PinLocationScreen extends StatefulWidget {
  const PinLocationScreen({super.key, required this.initial, this.title, this.hint, this.confirmLabel});

  final LatLng initial;
  final String? title;
  final String? hint;
  final String? confirmLabel;

  @override
  State<PinLocationScreen> createState() => _PinLocationScreenState();
}

class _PinLocationScreenState extends State<PinLocationScreen> {
  late LatLng _center = widget.initial;
  String? _address;
  GoogleMapController? _map;
  final _searchController = TextEditingController();
  bool _searching = false;
  bool _locating = false;
  String? _message;

  /// Bumped on every lookup so a slow answer for an earlier spot never
  /// replaces the one for where the pin is now.
  int _lookup = 0;

  @override
  void initState() {
    super.initState();
    _lookUpAddress();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _lookUpAddress() async {
    final lookup = ++_lookup;
    final place = await placemarkAt(_center);
    if (!mounted || lookup != _lookup) return;
    setState(() => _address = place == null ? null : placemarkLine(place));
  }

  Future<void> _moveTo(LatLng target) async {
    _center = target;
    final map = _map;
    if (map != null) {
      await map.animateCamera(CameraUpdate.newLatLngZoom(target, 17));
    } else {
      _lookUpAddress();
    }
  }

  Future<void> _search(String raw) async {
    final query = raw.trim();
    if (query.isEmpty) return;
    FocusScope.of(context).unfocus();
    final noResults = context.l10n.pinScreenSearchNoResults;
    setState(() {
      _searching = true;
      _message = null;
    });
    LatLng? found;
    try {
      // Biased to India: a bare area name ("Gandhi Nagar") is ambiguous worldwide.
      final hits = await Geocoding().locationFromAddress(query.toLowerCase().contains('india') ? query : '$query, India');
      if (hits.isNotEmpty) found = LatLng(hits.first.latitude, hits.first.longitude);
    } catch (e) {
      debugPrint('pin_location_screen: search failed: $e');
    }
    if (!mounted) return;
    setState(() {
      _searching = false;
      if (found == null) _message = noResults;
    });
    if (found != null) await _moveTo(found);
  }

  Future<void> _useMyLocation() async {
    final l10n = context.l10n;
    setState(() {
      _locating = true;
      _message = null;
    });
    String? problem;
    LatLng? here;
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        problem = l10n.addAddressLocationGpsOff;
      } else {
        var permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
          problem = l10n.addAddressLocationPermissionNeeded;
        } else {
          final p = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 20)),
          );
          here = LatLng(p.latitude, p.longitude);
        }
      }
    } catch (e) {
      debugPrint('pin_location_screen: current location failed: $e');
      problem = l10n.addAddressLocationPermissionNeeded;
    }
    if (!mounted) return;
    setState(() {
      _locating = false;
      _message = problem;
    });
    if (here != null) await _moveTo(here);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(widget.title ?? l10n.pinScreenTitle)),
      body: Stack(
        alignment: Alignment.center,
        children: [
          MapsGate(child: GoogleMap(
            initialCameraPosition: CameraPosition(target: widget.initial, zoom: 18),
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            onMapCreated: (c) => _map = c,
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Material(
                  color: palette.surface,
                  borderRadius: BorderRadius.circular(12),
                  elevation: 3,
                  child: TextField(
                    key: const Key('pinSearchField'),
                    controller: _searchController,
                    textInputAction: TextInputAction.search,
                    onSubmitted: _search,
                    decoration: InputDecoration(
                      hintText: l10n.pinScreenSearchHint,
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: _searching
                          ? const Padding(
                              padding: EdgeInsets.all(14),
                              child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                            )
                          : IconButton(
                              tooltip: l10n.pinScreenSearchHint,
                              icon: const Icon(Icons.arrow_forward_rounded),
                              onPressed: () => _search(_searchController.text),
                            ),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      filled: false,
                      contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Material(
                  color: palette.surface.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(10),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Text(
                      _message ?? widget.hint ?? l10n.pinScreenHint,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _message != null ? palette.error : palette.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 12.5,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            right: 16,
            bottom: 16,
            child: FloatingActionButton.small(
              key: const Key('pinMyLocation'),
              heroTag: null,
              tooltip: l10n.pinScreenMyLocation,
              backgroundColor: palette.surface,
              foregroundColor: palette.primary,
              onPressed: _locating ? null : _useMyLocation,
              child: _locating
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.my_location_rounded),
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
                child: Text(widget.confirmLabel ?? l10n.pinScreenConfirm),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
