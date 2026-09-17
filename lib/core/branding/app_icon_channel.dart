import 'dart:io';

import 'package:flutter/services.dart';

/// Switches the phone's home-screen (launcher) icon among the small, fixed
/// set of variants bundled into the app at build time — see
/// `tool/generate_occasion_icons.py` for how those are generated, and
/// `ios/Runner/AppDelegate.swift`/`android/.../MainActivity.kt` for the
/// native handlers this channel talks to. [iconKey] is one of
/// `"festiveGold"`/`"festiveRed"` (matching iOS's `CFBundleAlternateIcons`
/// keys and Android's aliased components 1:1 — see those files), or null to
/// revert to the default icon.
///
/// Best-effort and silent: unsupported platforms (web/desktop), an OS
/// version too old to support alternate icons, or any other native-side
/// failure are all swallowed rather than surfaced — a stuck icon is a
/// cosmetic issue, never worth crashing over or blocking the rest of the
/// theme (colors/logo/banner) from applying.
Future<void> setAppIcon(String? iconKey) async {
  if (!Platform.isIOS && !Platform.isAndroid) return;
  const channel = MethodChannel('com.quickmandi/app_icon');
  try {
    await channel.invokeMethod<void>('setIcon', {'name': iconKey});
  } catch (_) {
    // Swallow — see doc comment above.
  }
}
