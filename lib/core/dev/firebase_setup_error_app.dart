import 'package:flutter/material.dart';

import 'firebase_target.dart';

/// Shown instead of the app when a debug/profile build has no valid
/// Firebase target (see `firebase_target.dart`). Firebase is never
/// initialised behind it, so nothing reaches any project. Release builds
/// can't get here — they always use the real project.
class FirebaseSetupErrorApp extends StatelessWidget {
  const FirebaseSetupErrorApp({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final given = describeDefines(compiledFirebaseDefines);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        key: const Key('firebaseSetupError'),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.cloud_off_outlined, size: 40),
                const SizedBox(height: 16),
                Text('Firebase is not configured for this build', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 12),
                Text(message),
                const SizedBox(height: 16),
                const SelectableText(setupHint, style: TextStyle(fontFamily: 'monospace', fontSize: 12)),
                if (given.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text('Given: $given', style: Theme.of(context).textTheme.bodySmall),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
