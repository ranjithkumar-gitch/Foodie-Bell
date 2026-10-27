import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../core/session/access_scope.dart';
import '../models/account.dart';
import '../models/address.dart';
import '../models/order.dart';
import 'firestore_addresses_provider.dart';
import 'geocode_provider.dart';

/// Where an order is going, as every map and Driver screen needs it.
typedef OrderDropOff = ({
  /// The drop-off's map position — null when nothing could place it.
  LatLng? position,

  /// True when [position] is an exact saved pin (the order's snapshot or
  /// the address's own latitude/longitude); false when it was looked up
  /// from the typed street address, which can be a street or more off —
  /// the "Arrived" geofence only locks against a pinned position.
  bool pinned,

  /// The saved address the order was placed to, when it still exists.
  Address? address,

  /// The full street address to show / hand to Google Maps — the saved
  /// address's every part when known, else the order's short label.
  String fullAddress,
});

/// Which of a User's [saved] addresses an order labelled [orderLabel]
/// ("Home · 3-112") went to, for orders placed before the address id was
/// recorded: the exact label, else the one whose street line appears in
/// the label (the address was relabelled since), else — when there's
/// nothing to go on (a label like "Saved address") — the User's default
/// address, else their only one / the first with a pinned position.
Address? _bestMatch(List<Address> saved, String orderLabel) {
  if (saved.isEmpty) return null;
  for (final a in saved) {
    if (a.shortLabel == orderLabel) return a;
  }
  final label = orderLabel.toLowerCase();
  for (final a in saved) {
    final line1 = a.line1.trim().toLowerCase();
    if (line1.isNotEmpty && label.contains(line1)) return a;
  }
  for (final a in saved) {
    if (a.isDefault) return a;
  }
  if (saved.length == 1) return saved.first;
  for (final a in saved) {
    if (a.latitude != null && a.longitude != null) return a;
  }
  return saved.first;
}

/// Resolves [order]'s drop-off from the best source available, in order:
///  1. for the order's own Customer only — the only one `firestore.rules`
///     lets read their address book — the saved address by id
///     (`Order.deliveryAddressId`), read live so a pin added after ordering
///     still counts, else (older orders without an id) their best-matching
///     saved address — see [_bestMatch];
///  2. the full address written onto the order at placement
///     (`Order.deliveryAddressFull`) — what the Vendor and Driver go by;
///  3. position: the order's own snapshot, else that address's
///     latitude/longitude, else the full address looked up on the map.
/// Call from a widget's build (it watches providers).
OrderDropOff watchOrderDropOff(WidgetRef ref, Order order) {
  final viewerIsCustomer = ref.watch(
    accessScopeProvider.select((s) => s?.role == AppRole.user && s?.accountId == order.userId),
  );
  Address? address;
  if (viewerIsCustomer) {
    final addressId = order.deliveryAddressId;
    if (addressId != null) {
      address = ref.watch(addressByIdProvider(addressId)).valueOrNull;
    }
    if (address == null) {
      final saved = ref.watch(firestoreAddressesProvider(order.userId)).valueOrNull ?? const <Address>[];
      address = _bestMatch(saved, order.deliveryAddressLabel);
    }
  }
  final writtenOut = address == null ? order.deliveryAddressFull : fullAddressText(address);
  final fullAddress = writtenOut ?? order.deliveryAddressLabel;

  if (order.deliveryLatitude != null && order.deliveryLongitude != null) {
    return (
      position: LatLng(order.deliveryLatitude!, order.deliveryLongitude!),
      pinned: true,
      address: address,
      fullAddress: fullAddress,
    );
  }
  if (address?.latitude != null && address?.longitude != null) {
    return (position: LatLng(address!.latitude!, address.longitude!), pinned: true, address: address, fullAddress: fullAddress);
  }
  // Only a full written-out address is worth geocoding — the order's short
  // "Home · line1" label alone is too vague to place reliably.
  final geocoded = writtenOut == null ? null : ref.watch(geocodedAddressProvider(writtenOut)).valueOrNull;
  return (position: geocoded, pinned: false, address: address, fullAddress: fullAddress);
}
