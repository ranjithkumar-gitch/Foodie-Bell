import 'package:cloud_firestore/cloud_firestore.dart';

/// A User's recent search terms (`search_screen.dart`), persisted so they
/// survive logout/app-restart instead of resetting to a hardcoded starter
/// list every time the screen is reopened — same one-doc-per-user,
/// one-shot-load-not-a-stream shape as `firestore_carts_provider.dart`
/// (a search history only ever needs to load once per screen visit, not
/// stay subscribed).
const recentSearchesCollectionPath = 'recent_searches';

CollectionReference<Map<String, dynamic>> get recentSearchesCollection =>
    FirebaseFirestore.instance.collection(recentSearchesCollectionPath);

Future<List<String>> loadRecentSearches(String userId) async {
  final doc = await recentSearchesCollection.doc(userId).get();
  final data = doc.data();
  if (data == null) return const [];
  return (data['terms'] as List<dynamic>? ?? const []).map((e) => e.toString()).toList();
}

/// Overwrites the whole list — called after every local mutation
/// (`search_screen.dart`'s `_runSearch`/clear), same as `saveCart`.
Future<void> saveRecentSearches(String userId, List<String> terms) => recentSearchesCollection.doc(userId).set({
  'terms': terms,
  'updatedAt': FieldValue.serverTimestamp(),
});

Future<void> clearRecentSearches(String userId) => recentSearchesCollection.doc(userId).delete();
