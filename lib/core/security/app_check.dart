import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';

/// Forces the App Check *debug* provider in a non-debug build — for beta
/// builds installed outside the Play Store / App Store (sideloaded APKs,
/// Firebase App Distribution), which Play Integrity and App Attest can't
/// vouch for. Build with `--dart-define=APP_CHECK_DEBUG=true`; the app then
/// logs a debug token to register in Firebase console → App Check →
/// Manage debug tokens. Never ship a store build with it.
const _forceDebugProvider = bool.fromEnvironment('APP_CHECK_DEBUG');

/// Turns on Firebase App Check, which attests that requests to Firestore,
/// Storage and Cloud Functions come from a genuine copy of this app on a
/// genuine device. It is *not* sign-in or permission checking — who may do
/// what is still decided by the user's sign-in and claims in the rules.
///
/// Debug builds (and [_forceDebugProvider] builds) use the debug provider;
/// release builds use Play Integrity on Android and App Attest (falling
/// back to DeviceCheck on older iOS) on Apple. A failure here never stops
/// the app: until App Check is enforced in the console, requests without a
/// token still go through and only show up as "unverified" in its metrics.
Future<void> activateAppCheck() async {
  final useDebug = kDebugMode || _forceDebugProvider;
  try {
    await FirebaseAppCheck.instance.activate(
      androidProvider: useDebug ? AndroidProvider.debug : AndroidProvider.playIntegrity,
      appleProvider: useDebug ? AppleProvider.debug : AppleProvider.appAttestWithDeviceCheckFallback,
    );
  } catch (e) {
    debugPrint('App Check activation failed: $e');
  }
}
