import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/address.dart';

/// A User's real, persistent saved delivery addresses — one flat
/// `addresses` collection filtered by a `userId` field, same pattern as
/// `firestore_products_provider.dart` filters by `vendorId`, rather than a
/// `users/{userId}/addresses` subcollection.
const addressesCollectionPath = 'addresses';

CollectionReference<Map<String, dynamic>> get addressesCollection =>
    FirebaseFirestore.instance.collection(addressesCollectionPath);

Map<String, dynamic> _addressToDoc(String userId, Address address) => {
  'userId': userId,
  'label': address.label.name,
  'recipientName': address.recipientName,
  'recipientPhone': address.recipientPhone,
  'line1': address.line1,
  'landmark': address.landmark,
  'pincode': address.pincode,
  'city': address.city,
  'isDefault': address.isDefault,
  'isServiceable': address.isServiceable,
};

Address _addressFromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
  final data = doc.data();
  return Address(
    id: doc.id,
    label: AddressLabel.values.byName(data['label'] as String? ?? 'home'),
    recipientName: data['recipientName'] as String? ?? '',
    recipientPhone: data['recipientPhone'] as String? ?? '',
    line1: data['line1'] as String? ?? '',
    landmark: data['landmark'] as String?,
    pincode: data['pincode'] as String? ?? '',
    city: data['city'] as String? ?? '',
    isDefault: data['isDefault'] as bool? ?? false,
    isServiceable: data['isServiceable'] as bool? ?? true,
  );
}

/// This User's saved addresses — the single source of truth for the Saved
/// Addresses and Checkout address-selection screens.
final firestoreAddressesProvider = StreamProvider.family<List<Address>, String>((ref, userId) {
  return addressesCollection.where('userId', isEqualTo: userId).snapshots().map(
        (snapshot) => snapshot.docs.map(_addressFromDoc).toList(),
      );
});

Future<Address> addAddress(String userId, Address address) async {
  final doc = addressesCollection.doc();
  final saved = Address(
    id: doc.id,
    label: address.label,
    recipientName: address.recipientName,
    recipientPhone: address.recipientPhone,
    line1: address.line1,
    landmark: address.landmark,
    pincode: address.pincode,
    city: address.city,
    isDefault: address.isDefault,
    isServiceable: address.isServiceable,
  );
  await doc.set(_addressToDoc(userId, saved));
  return saved;
}

Future<void> removeAddress(String addressId) => addressesCollection.doc(addressId).delete();

/// The address selected during checkout — read by both the address-selection
/// and payment screens.
final selectedAddressProvider = StateProvider<Address?>((ref) => null);
