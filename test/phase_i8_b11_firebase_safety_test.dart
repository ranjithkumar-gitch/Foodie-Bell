// Phase I.8 Batch 1.1: local builds never reach the real Firebase project
// by accident; release builds are unchanged; secrets stay out of Git and
// the iOS sources needed for a clean checkout are trackable.
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/firebase_core_platform_interface.dart';
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodiebell/core/dev/firebase_emulators.dart';
import 'package:foodiebell/core/dev/firebase_setup_error_app.dart';
import 'package:foodiebell/core/dev/firebase_target.dart';
import 'package:foodiebell/firebase_options.dart';

const _realProject = 'quickmandi-3b017';
const _realSender = '427004408627';

/// A fake native side for `firebase_core`: [nativeApps] are the apps the
/// platform already created before Dart ran; [requests] records every
/// `initializeApp` Dart asks for.
class _FakeCoreHost implements TestFirebaseCoreHostApi {
  _FakeCoreHost({this.nativeApps = const [], this.answerWith});

  final List<CoreInitializeResponse> nativeApps;

  /// Options the "platform" reports back (defaults to what was asked).
  final CoreFirebaseOptions? answerWith;
  final requests = <CoreFirebaseOptions>[];

  @override
  Future<List<CoreInitializeResponse>> initializeCore() async => nativeApps;

  @override
  Future<CoreInitializeResponse> initializeApp(String appName, CoreFirebaseOptions request) async {
    requests.add(request);
    return CoreInitializeResponse(name: appName, options: answerWith ?? request, pluginConstants: {});
  }

  @override
  Future<CoreFirebaseOptions> optionsFromResource() async => throw UnimplementedError('never read natively');
}

CoreFirebaseOptions _core(FirebaseOptions o) => CoreFirebaseOptions(
      apiKey: o.apiKey,
      appId: o.appId,
      messagingSenderId: o.messagingSenderId,
      projectId: o.projectId,
      storageBucket: o.storageBucket,
    );

/// A fresh `firebase_core` (no apps) backed by [host].
void _useHost(_FakeCoreHost host) {
  TestWidgetsFlutterBinding.ensureInitialized();
  TestFirebaseCoreHostApi.setUp(host);
  FirebasePlatform.instance = MethodChannelFirebase();
  MethodChannelFirebase.appInstances.clear();
  MethodChannelFirebase.isCoreInitialized = false;
}

FirebaseTarget _debug([Map<String, String> defines = const {}]) => resolveFirebaseTarget(isRelease: false, defines: defines);

bool _ignored(String path) => Process.runSync('git', ['check-ignore', '--no-index', '-q', path]).exitCode == 0;

String _read(String path) => File(path).readAsStringSync();

void main() {
  group('target selection', () {
    test('a plain run (no defines) uses live data (owner decision 2026-11-03)', () {
      expect(_debug().isProduction, isTrue);
      expect(_debug({'USE_FIREBASE_EMULATORS': 'false'}).isProduction, isTrue);
    });

    test('an emulator request without its host is refused, never silently live', () {
      final t = _debug({'FIREBASE_TARGET': 'emulator'});
      expect(t.isMisconfigured, isTrue);
      expect(t.problem, contains('EMU_HOST'));
    });

    test('missing or invalid emulator configuration fails closed', () {
      for (final defines in [
        {'FIREBASE_TARGET': 'emulator'},
        {'FIREBASE_TARGET': 'staging'},
        {'FIREBASE_TARGET': 'emulator', 'EMU_HOST': 'firestore.googleapis.com'},
        {'FIREBASE_TARGET': 'emulator', 'EMU_HOST': '8.8.8.8'},
        {'FIREBASE_TARGET': 'emulator', 'EMU_HOST': '127.0.0.1', 'EMU_FS_PORT': 'abc'},
        {'FIREBASE_TARGET': 'emulator', 'EMU_HOST': '127.0.0.1', 'EMU_AUTH_PORT': '70000'},
        {'FIREBASE_TARGET': 'production', 'USE_FIREBASE_EMULATORS': 'true'},
        {'USE_FIREBASE_EMULATORS': 'yes'},
      ]) {
        final t = _debug(defines);
        expect(t.isMisconfigured, isTrue, reason: '$defines');
        expect(t.problem, isNotEmpty);
      }
    });

    test('explicit emulator configuration is honoured (host and every port)', () {
      final t = _debug({
        'FIREBASE_TARGET': 'Emulator',
        'EMU_HOST': '192.168.1.20',
        'EMU_AUTH_PORT': '19099',
        'EMU_FS_PORT': '18080',
        'EMU_FN_PORT': '15001',
        'EMU_ST_PORT': '19199',
      });
      expect(t.isEmulator, isTrue);
      expect([t.host, t.authPort, t.firestorePort, t.functionsPort, t.storagePort], ['192.168.1.20', 19099, 18080, 15001, 19199]);
      final simulator = _debug({'FIREBASE_TARGET': 'emulator', 'EMU_HOST': '127.0.0.1'});
      expect([simulator.authPort, simulator.firestorePort, simulator.functionsPort, simulator.storagePort], [9099, 8080, 5001, 9199]);
    });

    test('the legacy USE_FIREBASE_EMULATORS=true keeps its documented 10.0.2.2 default', () {
      final t = _debug({'USE_FIREBASE_EMULATORS': 'true'});
      expect(t.isEmulator, isTrue);
      expect(t.host, '10.0.2.2');
    });

    test('the emulators are used only when asked for', () {
      expect(_debug({'FIREBASE_TARGET': 'production'}).isProduction, isTrue);
      expect(_debug({'FIREBASE_TARGET': 'emulator', 'EMU_HOST': '127.0.0.1'}).isEmulator, isTrue);
      expect(_debug({'USE_FIREBASE_EMULATORS': 'true'}).isEmulator, isTrue);
    });

    test('release builds are unchanged: always the real project, whatever was defined', () {
      for (final defines in [
        const <String, String>{},
        {'FIREBASE_TARGET': 'emulator', 'EMU_HOST': '127.0.0.1'},
        {'USE_FIREBASE_EMULATORS': 'true'},
        {'FIREBASE_TARGET': 'garbage'},
      ]) {
        expect(resolveFirebaseTarget(isRelease: true, defines: defines).isProduction, isTrue, reason: '$defines');
      }
    });

    test('local hosts only', () {
      for (final h in ['localhost', '127.0.0.1', '10.0.2.2', '10.0.3.2', '192.168.0.5', '172.16.4.1', '172.31.255.255', '::1', 'macbook.local']) {
        expect(isLocalEmulatorHost(h), isTrue, reason: h);
      }
      for (final h in ['8.8.8.8', '172.32.0.1', 'example.com', 'quickmandi-3b017.firebaseapp.com', '10.0.0.999', '']) {
        expect(isLocalEmulatorHost(h), isFalse, reason: h);
      }
    });
  });

  group('emulator options carry nothing of the real project', () {
    for (final entry in {'android': DefaultFirebaseOptions.android, 'ios': DefaultFirebaseOptions.ios}.entries) {
      test(entry.key, () {
        final o = emulatorFirebaseOptions(entry.value);
        expect(o.projectId, emulatorProjectId);
        expect(o.storageBucket, '$emulatorProjectId.appspot.com');
        expect('${o.asMap}', isNot(contains(_realProject)));
        expect('${o.asMap}', isNot(contains(_realSender)));
        expect(o.apiKey, isNot(entry.value.apiKey));
        // The format the native SDKs validate (FIRInstallations raises otherwise).
        expect(o.apiKey, matches(RegExp(r'^A[A-Za-z0-9_-]{38}$')));
        expect(o.appId, matches(RegExp('^1:0+:${entry.key}:0+\$')));
      });
    }
  });

  group('initialisation', () {
    test('a misconfigured build throws before Firebase is touched', () async {
      final host = _FakeCoreHost();
      _useHost(host);
      await expectLater(
        initializeFirebaseFor(const FirebaseTarget.misconfigured('no target'), DefaultFirebaseOptions.android),
        throwsA(isA<FirebaseSetupException>()),
      );
      expect(host.requests, isEmpty);
      expect(Firebase.apps, isEmpty);
    });

    test('production (release, or opted in) initialises with the real options, as before', () async {
      final host = _FakeCoreHost();
      _useHost(host);
      await initializeFirebaseFor(const FirebaseTarget.production(), DefaultFirebaseOptions.android);
      expect(host.requests.single.projectId, _realProject);
      expect(host.requests.single.apiKey, DefaultFirebaseOptions.android.apiKey);
      expect(Firebase.app().options.projectId, _realProject);
    });

    test('an emulator build asks only for the demo project', () async {
      final host = _FakeCoreHost();
      _useHost(host);
      await initializeFirebaseAppFor(const FirebaseTarget.emulator(host: '127.0.0.1'), DefaultFirebaseOptions.ios);
      expect(host.requests.single.projectId, emulatorProjectId);
      expect(host.requests.single.apiKey, emulatorPlaceholderApiKey);
      expect(Firebase.app().options.projectId, emulatorProjectId);
    });

    test('a native default app from bundled real config makes an emulator build fail closed', () async {
      final host = _FakeCoreHost(nativeApps: [
        CoreInitializeResponse(name: defaultFirebaseAppName, options: _core(DefaultFirebaseOptions.ios), pluginConstants: {}),
      ]);
      _useHost(host);
      await expectLater(
        initializeFirebaseFor(const FirebaseTarget.emulator(host: '127.0.0.1'), DefaultFirebaseOptions.ios),
        throwsA(isA<FirebaseSetupException>().having((e) => e.message, 'message', contains('real project'))),
      );
      expect(host.requests, isEmpty);
    });

    test('an emulator build that somehow got another project fails closed', () async {
      final host = _FakeCoreHost(answerWith: _core(DefaultFirebaseOptions.android));
      _useHost(host);
      await expectLater(
        initializeFirebaseAppFor(const FirebaseTarget.emulator(host: '127.0.0.1'), DefaultFirebaseOptions.android),
        throwsA(isA<FirebaseSetupException>()),
      );
    });

    testWidgets('the setup error screen explains what to do', (tester) async {
      await tester.pumpWidget(const FirebaseSetupErrorApp(message: 'EMU_HOST was not given'));
      expect(find.byKey(const Key('firebaseSetupError')), findsOneWidget);
      expect(find.text('EMU_HOST was not given'), findsOneWidget);
      expect(find.textContaining('FIREBASE_TARGET=emulator'), findsOneWidget);
    });
  });

  group('start-up wiring (debug simulator start-up can\'t reach production)', () {
    final main = _read('lib/main.dart');

    test('main initialises Firebase only through the target, and stops on a setup error', () {
      expect(main, isNot(contains('Firebase.initializeApp')));
      final init = main.indexOf('initializeFirebaseFor(firebaseTarget, DefaultFirebaseOptions.currentPlatform)');
      expect(init, greaterThan(0));
      final stop = main.indexOf('runApp(FirebaseSetupErrorApp', init);
      expect(stop, greaterThan(init));
      expect(main.indexOf('return;', stop), greaterThan(stop));
      // Nothing Firebase runs before the target is applied.
      for (final call in ['activateAppCheck()', 'FirebaseAuth.instance', 'FirebaseMessaging.instance']) {
        expect(main.indexOf(call), greaterThan(init), reason: call);
      }
    });

    test('App Check is never activated against the emulators', () {
      expect(main, contains('if (!usingFirebaseEmulators) await activateAppCheck();'));
    });

    test('FCM: no topic or token calls in emulator builds', () {
      final fcm = _read('lib/core/notifications/fcm_topics.dart');
      for (final fn in ['Future<void> subscribeToTopic(', 'Future<void> unsubscribeFromTopic(', 'void listenForDeviceTokenSync(']) {
        final start = fcm.indexOf(fn);
        expect(start, greaterThan(-1), reason: fn);
        final guard = fcm.indexOf('if (usingFirebaseEmulators) return;', start);
        final firstFcmCall = fcm.indexOf('FirebaseMessaging.instance', start);
        expect(guard, greaterThan(start), reason: fn);
        expect(guard, lessThan(firstFcmCall), reason: fn);
      }
    });

    test('Android debug/profile: no native default app from google-services.json, no FCM auto-init; release untouched', () {
      for (final variant in ['debug', 'profile']) {
        final m = _read('android/app/src/$variant/AndroidManifest.xml');
        expect(m, contains('android:name="com.google.firebase.provider.FirebaseInitProvider"'), reason: variant);
        expect(m, contains('tools:node="remove"'), reason: variant);
        expect(m, contains('<meta-data android:name="firebase_messaging_auto_init_enabled" android:value="false"/>'), reason: variant);
      }
      final release = _read('android/app/src/main/AndroidManifest.xml');
      expect(release, isNot(contains('FirebaseInitProvider')));
      expect(release, isNot(contains('firebase_messaging_auto_init_enabled')));
    });

    test('iOS Debug/Profile: GoogleService-Info.plist not bundled, FCM auto-init off; Release keeps both', () {
      final debug = _read('ios/Flutter/Debug.xcconfig');
      expect(debug, contains('EXCLUDED_SOURCE_FILE_NAMES = \$(inherited) GoogleService-Info.plist'));
      expect(debug, contains('FIREBASE_MESSAGING_AUTO_INIT_ENABLED = NO'));
      final release = _read('ios/Flutter/Release.xcconfig');
      // Only the Profile configuration is affected; nothing is set for Release.
      expect(release, contains('EXCLUDED_SOURCE_FILE_NAMES_Profile = GoogleService-Info.plist'));
      expect(release, contains('FIREBASE_MESSAGING_AUTO_INIT_ENABLED_Profile = NO'));
      expect(release, isNot(contains('_Release')));
      expect(release, isNot(contains('EXCLUDED_SOURCE_FILE_NAMES = GoogleService-Info.plist')));
      // An unset value means on — the release behaviour.
      expect(_read('ios/Runner/Info.plist'), contains('<string>\$(FIREBASE_MESSAGING_AUTO_INIT_ENABLED:default=YES)</string>'));
    });

    test('the e2e test reads the emulator project the app now uses', () {
      expect(_read('integration_test/e2e_test.dart'), contains("String.fromEnvironment('EMU_PROJECT', defaultValue: emulatorProjectId)"));
    });
  });

  group('source control', () {
    test('secret and signing files stay ignored', () {
      for (final p in [
        'ios/Flutter/Secrets.xcconfig',
        'ios/AuthKey_TEST.p8',
        'ios/dist.p12',
        'ios/dist.cer',
        'ios/Runner/dist.mobileprovision',
        'ios/ExportOptions.plist',
        'ios/Runner.ipa',
        'android/key.properties',
        'android/app/upload-keystore.jks',
        'upload-keystore.jks',
        'release.keystore',
        'AuthKey_TEST.p8',
        'quickmandi-service-account.json',
        'quickmandi-3b017-firebase-adminsdk-abcde.json',
        '.env',
        'functions/.env',
      ]) {
        expect(_ignored(p), isTrue, reason: p);
      }
    });

    test('generated and per-machine iOS files stay ignored', () {
      for (final p in [
        'ios/Pods/Manifest.lock',
        'ios/.symlinks/plugins/x',
        'ios/Flutter/ephemeral/flutter_lldbinit',
        'ios/Flutter/Generated.xcconfig',
        'ios/Flutter/flutter_export_environment.sh',
        'ios/Flutter/Flutter.podspec',
        'ios/Runner/GeneratedPluginRegistrant.m',
        'ios/build/Runner.app',
        'ios/Runner.xcworkspace/xcuserdata/me.xcuserdatad/UserInterfaceState.xcuserstate',
        'ios/Runner/.DS_Store',
      ]) {
        expect(_ignored(p), isTrue, reason: p);
      }
    });

    test('the iOS sources a clean checkout needs are not ignored', () {
      for (final p in [
        'ios/.gitignore',
        'ios/Podfile',
        'ios/Podfile.lock',
        'ios/Runner/AppDelegate.swift',
        'ios/Runner/SceneDelegate.swift',
        'ios/Runner/Info.plist',
        'ios/Runner/Runner.entitlements',
        'ios/Runner/Runner-Bridging-Header.h',
        'ios/Runner/GoogleService-Info.plist',
        'ios/Runner.xcodeproj/project.pbxproj',
        'ios/Runner.xcodeproj/xcshareddata/xcschemes/Runner.xcscheme',
        'ios/Runner.xcworkspace/contents.xcworkspacedata',
        'ios/Runner/Assets.xcassets/AppIcon.appiconset/Contents.json',
        'ios/Runner/Assets.xcassets/AppIcon.appiconset/1024.png',
        'ios/Runner/Base.lproj/LaunchScreen.storyboard',
        'ios/Runner/Base.lproj/Main.storyboard',
        'ios/Flutter/AppFrameworkInfo.plist',
        'ios/Flutter/Debug.xcconfig',
        'ios/Flutter/Release.xcconfig',
        'ios/Flutter/Secrets.xcconfig.example',
        'ios/RunnerTests/RunnerTests.swift',
      ]) {
        expect(_ignored(p), isFalse, reason: p);
        expect(File(p).existsSync(), isTrue, reason: '$p exists');
      }
    });

    test('every file the Xcode project references by path exists and is trackable', () {
      final pbx = _read('ios/Runner.xcodeproj/project.pbxproj');
      final refs = RegExp(r'path = "?([^";]+)"?; sourceTree = "<group>"').allMatches(pbx).map((m) => m.group(1)!).toSet();
      expect(refs, containsAll(['Runner/GoogleService-Info.plist', 'Runner.entitlements', 'AppDelegate.swift', 'Info.plist']));
      for (final f in ['Runner/GoogleService-Info.plist', 'Runner/Runner.entitlements', 'Runner/AppDelegate.swift', 'Runner/Info.plist', 'Runner/SceneDelegate.swift']) {
        expect(_ignored('ios/$f'), isFalse, reason: f);
      }
    });

    test('a missing Maps key stays safe: optional include, empty template, no real key on disk', () {
      expect(_read('ios/Flutter/Debug.xcconfig'), contains('#include? "Secrets.xcconfig"'));
      expect(_read('ios/Flutter/Release.xcconfig'), contains('#include? "Secrets.xcconfig"'));
      expect(RegExp(r'^GMS_API_KEY\s*=\s*$', multiLine: true).hasMatch(_read('ios/Flutter/Secrets.xcconfig.example')), isTrue);
    });
  });
}
