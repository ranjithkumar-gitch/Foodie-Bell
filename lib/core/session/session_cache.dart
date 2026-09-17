import 'package:shared_preferences/shared_preferences.dart';

/// Persists which account last completed login/registration, so a cold
/// start can restore that session instead of always landing back on the
/// sign-in screen — same `SharedPreferences` pattern as
/// `territory_cache.dart`/`brand_theme_cache.dart`.
///
/// Why this exists at all: `splash_screen.dart` restores a session by
/// reading `FirebaseAuth.instance.currentUser`'s own phone/email, which
/// works once real phone auth is on (`kUseDynamicOtp`, `otp_config.dart`).
/// Until then, `completePhoneAuth` (`auth_navigation.dart`) signs in
/// *anonymously* instead — a real, persisted Firebase session, but one
/// that carries no phone or email of its own, so there was nothing for
/// splash to resolve an [Account] from; splash was then actively signing
/// that anonymous session back out on every cold start rather than just
/// finding no match. This cache is what splash falls back to in that case
/// — the phone number is enough on its own, since [resolveAccountAcrossRoles]
/// (`auth_navigation.dart`) already resolves an [Account] role-agnostically
/// from just a phone.
const _cacheKey = 'session_phone';

Future<String?> loadCachedSessionPhone() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString(_cacheKey);
}

Future<void> saveCachedSessionPhone(String phone) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_cacheKey, phone);
}

Future<void> clearCachedSessionPhone() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove(_cacheKey);
}
