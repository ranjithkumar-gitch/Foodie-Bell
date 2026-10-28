import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

/// Points the app at the local Firebase Emulator Suite instead of the real
/// project — for end-to-end tests on an Android emulator, so no test
/// account, order or payment ever reaches `quickmandi-3b017`.
///
/// Off unless a **debug or profile** (test) build is started with
/// `--dart-define=USE_FIREBASE_EMULATORS=true`; release builds always
/// ignore it and use the real project.
/// The Android emulator reaches the host PC at 10.0.2.2. Ports default to
/// the emulators' standard ones and can be overridden with
/// `--dart-define=EMU_AUTH_PORT=…` (and `EMU_FS_PORT`, `EMU_FN_PORT`,
/// `EMU_ST_PORT`).
const _useEmulators = bool.fromEnvironment('USE_FIREBASE_EMULATORS');
const _host = String.fromEnvironment('EMU_HOST', defaultValue: '10.0.2.2');
const _authPort = int.fromEnvironment('EMU_AUTH_PORT', defaultValue: 9099);
const _firestorePort = int.fromEnvironment('EMU_FS_PORT', defaultValue: 8080);
const _functionsPort = int.fromEnvironment('EMU_FN_PORT', defaultValue: 5001);
const _storagePort = int.fromEnvironment('EMU_ST_PORT', defaultValue: 9199);

bool get usingFirebaseEmulators => !kReleaseMode && _useEmulators;

Future<void> useFirebaseEmulatorsIfAsked() async {
  if (!usingFirebaseEmulators) return;
  await FirebaseAuth.instance.useAuthEmulator(_host, _authPort);
  FirebaseFirestore.instance.useFirestoreEmulator(_host, _firestorePort);
  FirebaseFunctions.instanceFor(region: 'asia-south1').useFunctionsEmulator(_host, _functionsPort);
  await FirebaseStorage.instance.useStorageEmulator(_host, _storagePort);
  debugPrint('Firebase: using the local emulators at $_host');
}
