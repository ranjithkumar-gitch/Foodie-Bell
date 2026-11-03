/// Which Firebase this build talks to — decided once at startup, before
/// `Firebase.initializeApp`.
///
/// * **Every build uses the live project (`quickmandi-3b017`) by default**
///   — release, debug and profile alike; a plain `flutter run` connects to
///   live data (owner decision, 2026-11-03).
/// * The local Firebase Emulator Suite is used only when asked for, e.g.
///   `--dart-define=FIREBASE_TARGET=emulator --dart-define=EMU_HOST=127.0.0.1`
///   (iOS simulator, web) or `EMU_HOST=10.0.2.2` (Android emulator). The
///   older `--dart-define=USE_FIREBASE_EMULATORS=true` still works and keeps
///   its documented `10.0.2.2` default. Release builds ignore these defines.
/// * An invalid emulator request (no host, a non-local host, a bad port, an
///   unknown target) is [FirebaseTargetKind.misconfigured]: the app shows a
///   setup error instead of guessing.
///
/// Ports default to the emulators' standard ones (`firebase.json`) and can
/// be overridden with `EMU_AUTH_PORT`, `EMU_FS_PORT`, `EMU_FN_PORT` and
/// `EMU_ST_PORT`.
library;

/// The emulator project the backend's tests use (`firebase emulators:exec
/// --project demo-quickmandi`). A `demo-` project has no real resources, so
/// even an SDK call that escaped the emulators couldn't touch real data.
const emulatorProjectId = 'demo-quickmandi';

/// A placeholder API key for emulator builds. It has the format the native
/// SDKs validate (39 URL-safe characters starting with `A`), so they don't
/// crash, but it belongs to no project — Google rejects it.
const emulatorPlaceholderApiKey = 'ADemo-QuickMandi-LocalEmulatorOnly-Key0';

const _defineNames = [
  'FIREBASE_TARGET',
  'USE_FIREBASE_EMULATORS',
  'EMU_HOST',
  'EMU_AUTH_PORT',
  'EMU_FS_PORT',
  'EMU_FN_PORT',
  'EMU_ST_PORT',
];

/// The `--dart-define` values this build was compiled with.
const compiledFirebaseDefines = <String, String>{
  'FIREBASE_TARGET': String.fromEnvironment('FIREBASE_TARGET'),
  'USE_FIREBASE_EMULATORS': String.fromEnvironment('USE_FIREBASE_EMULATORS'),
  'EMU_HOST': String.fromEnvironment('EMU_HOST'),
  'EMU_AUTH_PORT': String.fromEnvironment('EMU_AUTH_PORT'),
  'EMU_FS_PORT': String.fromEnvironment('EMU_FS_PORT'),
  'EMU_FN_PORT': String.fromEnvironment('EMU_FN_PORT'),
  'EMU_ST_PORT': String.fromEnvironment('EMU_ST_PORT'),
};

enum FirebaseTargetKind { production, emulator, misconfigured }

class FirebaseTarget {
  const FirebaseTarget._(
    this.kind, {
    this.host = '',
    this.authPort = 0,
    this.firestorePort = 0,
    this.functionsPort = 0,
    this.storagePort = 0,
    this.problem = '',
  });

  const FirebaseTarget.production() : this._(FirebaseTargetKind.production);

  const FirebaseTarget.misconfigured(String problem) : this._(FirebaseTargetKind.misconfigured, problem: problem);

  const FirebaseTarget.emulator({
    required String host,
    int authPort = 9099,
    int firestorePort = 8080,
    int functionsPort = 5001,
    int storagePort = 9199,
  }) : this._(
          FirebaseTargetKind.emulator,
          host: host,
          authPort: authPort,
          firestorePort: firestorePort,
          functionsPort: functionsPort,
          storagePort: storagePort,
        );

  final FirebaseTargetKind kind;
  final String host;
  final int authPort;
  final int firestorePort;
  final int functionsPort;
  final int storagePort;

  /// Why the build can't start, for [FirebaseTargetKind.misconfigured].
  final String problem;

  bool get isProduction => kind == FirebaseTargetKind.production;
  bool get isEmulator => kind == FirebaseTargetKind.emulator;
  bool get isMisconfigured => kind == FirebaseTargetKind.misconfigured;
}

const setupHint = 'For the local emulators, run for example:\n'
    '  flutter run --dart-define=FIREBASE_TARGET=emulator --dart-define=EMU_HOST=127.0.0.1\n'
    '(EMU_HOST=10.0.2.2 on the Android emulator). For live data, run without FIREBASE_TARGET:\n'
    '  flutter run';

/// Decides the target from the build mode and the compiled defines. Pure,
/// so the rules are unit-tested (`test/phase_i8_b11_firebase_safety_test.dart`).
FirebaseTarget resolveFirebaseTarget({required bool isRelease, Map<String, String> defines = compiledFirebaseDefines}) {
  if (isRelease) return const FirebaseTarget.production();
  String read(String name) => (defines[name] ?? '').trim();

  final target = read('FIREBASE_TARGET').toLowerCase();
  final legacyFlag = read('USE_FIREBASE_EMULATORS').toLowerCase();
  if (legacyFlag.isNotEmpty && legacyFlag != 'true' && legacyFlag != 'false') {
    return FirebaseTarget.misconfigured('USE_FIREBASE_EMULATORS must be true or false, not "$legacyFlag".');
  }
  final legacyEmulators = legacyFlag == 'true';

  switch (target) {
    case 'production':
      if (legacyEmulators) {
        return const FirebaseTarget.misconfigured(
            'FIREBASE_TARGET=production conflicts with USE_FIREBASE_EMULATORS=true. Pick one.');
      }
      return const FirebaseTarget.production();
    case '':
      // Nothing asked for: live data, unless the legacy emulator flag is on.
      if (!legacyEmulators) return const FirebaseTarget.production();
    case 'emulator':
      break;
    default:
      return FirebaseTarget.misconfigured('Unknown FIREBASE_TARGET "$target" (use emulator or production).');
  }

  // Emulator — only when explicitly requested.
  var host = read('EMU_HOST');
  if (host.isEmpty && legacyEmulators) host = '10.0.2.2';
  if (host.isEmpty) {
    return const FirebaseTarget.misconfigured(
        'FIREBASE_TARGET=emulator was given without EMU_HOST (where the emulators run). '
        'Add EMU_HOST, or drop FIREBASE_TARGET to use live data.');
  }
  if (!isLocalEmulatorHost(host)) {
    return FirebaseTarget.misconfigured(
        'EMU_HOST "$host" is not a local address (localhost, 127.x, 10.0.2.2, a private LAN address or *.local).');
  }

  final ports = <String, int>{};
  for (final entry in const {'EMU_AUTH_PORT': 9099, 'EMU_FS_PORT': 8080, 'EMU_FN_PORT': 5001, 'EMU_ST_PORT': 9199}.entries) {
    final raw = read(entry.key);
    final port = raw.isEmpty ? entry.value : int.tryParse(raw);
    if (port == null || port < 1 || port > 65535) {
      return FirebaseTarget.misconfigured('${entry.key} must be a port number (1–65535), not "$raw".');
    }
    ports[entry.key] = port;
  }
  return FirebaseTarget.emulator(
    host: host,
    authPort: ports['EMU_AUTH_PORT']!,
    firestorePort: ports['EMU_FS_PORT']!,
    functionsPort: ports['EMU_FN_PORT']!,
    storagePort: ports['EMU_ST_PORT']!,
  );
}

final _privateIpv4 = RegExp(r'^(10|127)\.\d{1,3}\.\d{1,3}\.\d{1,3}$|^192\.168\.\d{1,3}\.\d{1,3}$|^172\.(1[6-9]|2\d|3[01])\.\d{1,3}\.\d{1,3}$');

/// Loopback, the Android emulator's host alias, private LAN addresses
/// (a physical test phone on the same network) and mDNS `.local` names.
bool isLocalEmulatorHost(String host) {
  final h = host.toLowerCase();
  if (h == 'localhost' || h == '::1' || h == '[::1]' || h.endsWith('.local')) return true;
  if (!_privateIpv4.hasMatch(h)) return false;
  return h.split('.').every((part) => int.parse(part) <= 255);
}

/// For the setup error screen: the defines this build was given (values
/// are addresses and ports, never secrets).
String describeDefines(Map<String, String> defines) =>
    [for (final name in _defineNames) if ((defines[name] ?? '').isNotEmpty) '$name=${defines[name]}'].join(', ');
