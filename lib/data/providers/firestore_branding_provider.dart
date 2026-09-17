import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/brand_theme.dart';

/// Single-doc "app config" collection — today just the active occasion
/// theme (`current_theme`), set by QuickyAdmin. This app only ever reads
/// it. See `Quicky_Branding_UserApp.md` for the full spec.
const appConfigCollectionPath = 'app_config';
const currentThemeDocId = 'current_theme';

DocumentReference<Map<String, dynamic>> get currentThemeDoc =>
    FirebaseFirestore.instance.collection(appConfigCollectionPath).doc(currentThemeDocId);

/// The live occasion theme — null when the doc doesn't exist, or when it
/// exists but `occasionId` is null (both mean "render default branding",
/// see [BrandTheme.isDefault]).
final brandThemeStreamProvider = StreamProvider<BrandTheme?>((ref) {
  return currentThemeDoc.snapshots().map((doc) {
    final data = doc.data();
    if (data == null) return null;
    final theme = BrandTheme.fromMap(data);
    return theme.isDefault ? null : theme;
  });
});
