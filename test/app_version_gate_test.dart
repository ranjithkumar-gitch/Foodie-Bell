import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodiebell/core/release/app_build.dart';
import 'package:foodiebell/core/release/app_version_gate.dart';

Future<void> _pump(WidgetTester tester, Stream<AppVersionPolicy> policy, {int build = 2, String platform = 'android'}) async {
  await tester.pumpWidget(ProviderScope(
    key: UniqueKey(),
    overrides: [appVersionPolicyProvider.overrideWith((ref) => policy)],
    child: MaterialApp(home: AppVersionGate(buildNumber: build, platform: platform, child: const Text('APP'))),
  ));
  await tester.pump();
}

void main() {
  test('the build constant matches pubspec.yaml', () {
    final version = RegExp(r'^version:\s*\S+\+(\d+)\s*$', multiLine: true).firstMatch(File('pubspec.yaml').readAsStringSync())!;
    expect(int.parse(version.group(1)!), appBuildNumber);
  });

  test('policy parsing and comparison', () {
    final p = AppVersionPolicy.fromMap({'minimumBuild': {'android': 3, 'ios': 2, 'bad': 'x'}, 'storeUrl': {'android': 'https://play'}, 'message': 'Hi'});
    expect(p.blocks('android', 2), isTrue);
    expect(p.blocks('android', 3), isFalse);
    expect(p.blocks('ios', 2), isFalse);
    expect(p.blocks('web', 1), isFalse, reason: 'no minimum for a platform = supported');
    expect(p.minimumBuild.containsKey('bad'), isFalse);
    expect(AppVersionPolicy.fromMap(null).blocks('android', 1), isFalse);
  });

  testWidgets('a build below the minimum sees the blocking update screen', (tester) async {
    await _pump(tester, Stream.value(AppVersionPolicy.fromMap({'minimumBuild': {'android': 3}, 'storeUrl': {'android': 'https://play.google.com/store/apps/details?id=x'}})));
    expect(find.text('Update required'), findsOneWidget);
    expect(find.byKey(const Key('updateNow')), findsOneWidget);
    expect(find.text('APP'), findsNothing);
  });

  testWidgets('a supported build runs normally', (tester) async {
    await _pump(tester, Stream.value(AppVersionPolicy.fromMap({'minimumBuild': {'android': 2}})));
    expect(find.text('APP'), findsOneWidget);
  });

  testWidgets('fails open: missing policy, read error, or still loading never blocks', (tester) async {
    await _pump(tester, Stream.value(AppVersionPolicy.fromMap(null)));
    expect(find.text('APP'), findsOneWidget);
    await _pump(tester, Stream.error(Exception('offline')));
    expect(find.text('APP'), findsOneWidget);
    final never = StreamController<AppVersionPolicy>();
    addTearDown(never.close);
    await _pump(tester, never.stream);
    expect(find.text('APP'), findsOneWidget);
  });
}
