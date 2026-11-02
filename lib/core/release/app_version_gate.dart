import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import 'app_build.dart';

/// The minimum-supported-build policy, `app_config/app_version`, written
/// only by the server (Super Admin callable `updateAppVersionPolicy`):
///
///   { minimumBuild: { android: 2, ios: 2 }, storeUrl: { android: …, ios: … }, message: … }
class AppVersionPolicy {
  const AppVersionPolicy({this.minimumBuild = const {}, this.storeUrl = const {}, this.message});

  factory AppVersionPolicy.fromMap(Map<String, dynamic>? d) {
    if (d == null) return const AppVersionPolicy();
    Map<String, T> typed<T>(Object? v) => {
          if (v is Map)
            for (final e in v.entries)
              if (e.key is String && e.value is T) e.key as String: e.value as T,
        };
    return AppVersionPolicy(
      minimumBuild: typed<int>(d['minimumBuild']),
      storeUrl: typed<String>(d['storeUrl']),
      message: d['message'] is String ? d['message'] as String : null,
    );
  }

  final Map<String, int> minimumBuild;
  final Map<String, String> storeUrl;
  final String? message;

  /// Whether [build] on [platform] is below the minimum. A platform with no
  /// minimum is supported.
  bool blocks(String platform, int build) => build < (minimumBuild[platform] ?? 0);
}

String currentPlatformKey() => kIsWeb
    ? 'web'
    : switch (defaultTargetPlatform) {
        TargetPlatform.android => 'android',
        TargetPlatform.iOS => 'ios',
        _ => 'other',
      };

/// The live policy. Errors and a missing document are NOT treated as
/// "blocked": the gate fails open, because the server's rules — not this
/// screen — are what stop an unsupported build from writing.
final appVersionPolicyProvider = StreamProvider<AppVersionPolicy>((ref) {
  return FirebaseFirestore.instance.doc('app_config/app_version').snapshots().map((d) => AppVersionPolicy.fromMap(d.data()));
});

/// Shows [child], or a blocking update screen when this build is below the
/// server's minimum. While the policy loads, or if it can't be read, the
/// app runs normally (fail open).
class AppVersionGate extends ConsumerWidget {
  const AppVersionGate({super.key, required this.child, this.buildNumber = appBuildNumber, this.platform});

  final Widget child;
  final int buildNumber;

  /// For tests; defaults to the running platform.
  final String? platform;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final policy = ref.watch(appVersionPolicyProvider).valueOrNull;
    final p = platform ?? currentPlatformKey();
    if (policy == null || !policy.blocks(p, buildNumber)) return child;
    return UpdateRequiredScreen(storeUrl: policy.storeUrl[p], message: policy.message);
  }
}

class UpdateRequiredScreen extends StatelessWidget {
  const UpdateRequiredScreen({super.key, this.storeUrl, this.message});

  final String? storeUrl;
  final String? message;

  @override
  Widget build(BuildContext context) => PopScope(
        canPop: false,
        child: Scaffold(
          body: SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.system_update_rounded, size: 56),
                    const SizedBox(height: 16),
                    Text('Update required', style: Theme.of(context).textTheme.headlineSmall, textAlign: TextAlign.center),
                    const SizedBox(height: 8),
                    Text(
                      message ?? 'This version of Quicky is no longer supported. Please update to keep ordering and delivering.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    if (storeUrl != null)
                      FilledButton(
                        key: const Key('updateNow'),
                        onPressed: () => launchUrl(Uri.parse(storeUrl!), mode: LaunchMode.externalApplication),
                        child: const Text('Update now'),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
}
