import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'; 

import 'app.dart';
import 'core/branding/branding_controller.dart';
import 'core/dev/firebase_emulators.dart';
import 'core/dev/firebase_setup_error_app.dart';
import 'core/notifications/foreground_notification_handler.dart';
import 'core/notifications/local_notifications.dart';
import 'core/notifications/notification_routes.dart';
import 'core/security/app_check.dart';  
import 'data/providers/brand_theme_cache.dart';  
import 'data/providers/territory_cache.dart';
import 'features/user/home/selected_territory_provider.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Release: the real project. Debug/profile: the local emulators unless
  // FIREBASE_TARGET=production — and never a silent fallback to the real
  // project (lib/core/dev/firebase_target.dart).
  try {
    await initializeFirebaseFor(firebaseTarget, DefaultFirebaseOptions.currentPlatform);
  } on FirebaseSetupException catch (e) {
    debugPrint('Firebase: not started — ${e.message}');
    runApp(FirebaseSetupErrorApp(message: e.message));
    return;
  }
  // The emulators don't check App Check, and a debug token exchange would
  // reach the real project.
  if (!usingFirebaseEmulators) await activateAppCheck();
  // Debug builds can't pass Play Integrity (not installed from Play, and
  // emulators fail the device check), which Firebase phone auth uses on
  // Android before sending an SMS. Use its reCAPTCHA check there instead —
  // still a real verification.
  //
  // 2026-11-18: release APKs shared directly (not installed from Play)
  // fail Play Integrity the same way — a real number got "This app can't
  // verify phone numbers yet" (test numbers skip the check, so it went
  // unnoticed). They use reCAPTCHA too, until a Play Store build is made
  // with `--dart-define=PLAY_STORE_BUILD=true`.
  const playStoreBuild = bool.fromEnvironment('PLAY_STORE_BUILD');
  if ((kDebugMode || !playStoreBuild) && defaultTargetPlatform == TargetPlatform.android) {
    await FirebaseAuth.instance.setSettings(forceRecaptchaFlow: true);
  }
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
  // Taps on pushes that open the app lead to their page (2026-11-17).
  if (!usingFirebaseEmulators) await captureNotificationLaunch();
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
