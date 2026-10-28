import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A territory's most-ordered dishes over the last week, most-ordered
/// first (`trending/{territoryId}`, refreshed hourly by the server from
/// delivered orders — QuickyAdmin `functions/aggregates.js`). Customers
/// read this one small document instead of anyone's orders; dishes ordered
/// only once or twice are left out, so no single order shows. Empty when
/// there's nothing yet — screens then show their fallback suggestions.
final trendingDishesProvider = StreamProvider.autoDispose.family<List<String>, String>((ref, territoryId) {
  return FirebaseFirestore.instance.doc('trending/$territoryId').snapshots().map((doc) => [
        for (final t in (doc.data()?['terms'] as List<dynamic>? ?? const []))
          if (t is Map && t['name'] is String) t['name'] as String,
      ]);
});
