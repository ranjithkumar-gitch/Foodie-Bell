import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

import 'firebase_target.dart';

/// This build's Firebase target (see `firebase_target.dart`): the real
/// project for release builds; the local emulators — or a setup error —
/// for debug and profile builds unless they opt into production.
final FirebaseTarget firebaseTarget = resolveFirebaseTarget(isRelease: kReleaseMode);

bool get usingFirebaseEmulators => firebaseTarget.isEmulator;

/// Thrown when an emulator build would end up on anything but the
/// emulator project — e.g. a native default app configured from
/// `GoogleService-Info.plist` / `google-services.json` before Dart ran.
class FirebaseSetupException implements Exception {
  FirebaseSetupException(this.message);
  final String message;
  @override
  String toString() => 'FirebaseSetupException: $message';
}

/// The options an emulator build initialises Firebase with: the emulator
/// project, a placeholder key and app id of the same platform and format
/// as [real] (the native SDKs validate the format), and no real project
/// number or bucket. Nothing in it identifies `quickmandi-3b017`.
FirebaseOptions emulatorFirebaseOptions(FirebaseOptions real) {
  final parts = real.appId.split(':');
  final platform = parts.length == 4 ? parts[2] : 'web';
  final suffix = parts.length == 4 ? '0' * parts[3].length : '0' * 16;
  return FirebaseOptions(
    apiKey: emulatorPlaceholderApiKey,
    appId: '1:000000000000:$platform:$suffix',
    messagingSenderId: '000000000000',
    projectId: emulatorProjectId,
    storageBucket: '$emulatorProjectId.appspot.com',
    authDomain: real.authDomain == null ? null : '$emulatorProjectId.firebaseapp.com',
    iosBundleId: real.iosBundleId,
  );
}

/// Initialises Firebase for [target]. Release and opted-in production
/// builds behave exactly as before (`Firebase.initializeApp` with the real
/// options). Emulator builds use [emulatorFirebaseOptions], check they
/// really got the emulator project, and point Auth, Firestore, Functions
/// and Storage at the emulators before anything else touches them.
Future<void> initializeFirebaseFor(FirebaseTarget target, FirebaseOptions real) async {
  await initializeFirebaseAppFor(target, real);
  if (target.isEmulator) await _connectEmulators(target);
}

/// The app half of [initializeFirebaseFor]: creates the default app for
/// [target] and verifies it, without connecting any service yet.
Future<void> initializeFirebaseAppFor(FirebaseTarget target, FirebaseOptions real) async {
  switch (target.kind) {
    case FirebaseTargetKind.misconfigured:
      throw FirebaseSetupException(target.problem);
    case FirebaseTargetKind.production:
      if (!kReleaseMode) {
        debugPrint('Firebase: ⚠ this ${kDebugMode ? 'debug' : 'profile'} build uses the REAL project '
            '(${real.projectId}) because FIREBASE_TARGET=production was given.');
      }
      await Firebase.initializeApp(options: real);
    case FirebaseTargetKind.emulator:
      try {
        await Firebase.initializeApp(options: emulatorFirebaseOptions(real));
      } on FirebaseException catch (e) {
        // `duplicate-app`: the platform already created a default app from
        // its bundled config — i.e. the real project.
        throw FirebaseSetupException('Firebase was already initialised natively (${e.code}); '
            'this build bundles the real project\'s config, so it can\'t run against the emulators.');
      }
      final projectId = Firebase.app().options.projectId;
      if (projectId != emulatorProjectId) {
        throw FirebaseSetupException('Expected the emulator project $emulatorProjectId, got $projectId.');
      }
  }
}

Future<void> _connectEmulators(FirebaseTarget target) async {
  await FirebaseAuth.instance.useAuthEmulator(target.host, target.authPort);
  FirebaseFirestore.instance.useFirestoreEmulator(target.host, target.firestorePort);
  FirebaseFunctions.instanceFor(region: 'asia-south1').useFunctionsEmulator(target.host, target.functionsPort);
  await FirebaseStorage.instance.useStorageEmulator(target.host, target.storagePort);
  debugPrint('Firebase: using the local emulators ($emulatorProjectId) at ${target.host}');
}
