import 'package:flutter/foundation.dart';

/// Turns any caught error/exception into a short, non-technical message
/// safe to show a user — raw backend exception text (error codes like
/// `[cloud_firestore/permission-denied] Missing or insufficient
/// permissions.`, stack traces) never reaches the UI. A leaked backend
/// error reads as "this app is broken" even when the underlying cause is
/// transient (e.g. a stream reconnecting after a session change), which is
/// exactly the kind of thing that erodes trust in the app. The real error
/// is always still logged via [debugPrint], so it's visible in
/// development/QA — mirrors the pattern already used in
/// `admin_global_catalogue_screen.dart`/`vendor_catalogue_screen.dart`.
String friendlyError(Object error, {String? action, StackTrace? stackTrace}) {
  debugPrint('${action ?? 'Operation'} failed: $error${stackTrace != null ? '\n$stackTrace' : ''}');
  return 'Something went wrong. Please check your connection and try again.';
}
