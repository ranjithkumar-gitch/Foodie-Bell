import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/branding/branding_controller.dart';
import 'core/notifications/foreground_notification_handler.dart';
import 'core/notifications/local_notifications.dart';
import 'data/providers/brand_theme_cache.dart';
import 'data/providers/territory_cache.dart';
import 'features/user/home/selected_territory_provider.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // Load the last-known occasion theme before the first frame, so it's
  // already applied instead of flashing default branding while
  // brandThemeStreamProvider connects to Firestore.
  final cachedBrand = await loadCachedBrandTheme();
  // Same idea for the User's last-picked territory — see
  // `hydrateSelectedTerritoryFromCache`'s doc comment for why this also
  // needs to stay correct across restarts now, not just be a nice-to-have.
  final cachedTerritoryId = await loadCachedTerritoryId();
  // Fire-and-forget: shows a system permission prompt (iOS always, Android
  // 13+), not worth blocking the first frame on. A denial just means this
  // device never receives a push — nothing else in the app depends on it.
  FirebaseMessaging.instance.requestPermission();
  await initLocalNotifications();
  registerForegroundNotificationHandler();
  runApp(
    ProviderScope(
      overrides: [
        cachedBrandThemeProvider.overrideWithValue(cachedBrand),
        cachedTerritoryIdProvider.overrideWithValue(cachedTerritoryId),
      ],
      child: const QuickyApp(),
    ),
  );
}
