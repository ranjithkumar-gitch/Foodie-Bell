import 'package:flutter/foundation.dart';

/// This app's build number — must equal the `+N` in pubspec.yaml's
/// `version:` (test/app_version_gate_test.dart checks). Compared with the
/// server's minimum supported build (`app_config/app_version`) so builds
/// the backend no longer supports can be stopped with an update screen.
const appBuildNumber = 2;

/// The platform name the backend's version policy uses.
String get appPlatformName => kIsWeb ? 'web' : (defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android');

/// [data] plus this build's number and platform, for order, code and refund
/// calls — the server refuses builds below the minimum (Phase I.8,
/// `functions/lib/client_build.js`), so even a build without the update
/// screen can't place or move an order once it's unsupported.
Map<String, dynamic> withClientBuild(Map<String, dynamic> data) =>
    {...data, 'clientBuild': appBuildNumber, 'clientPlatform': appPlatformName};
