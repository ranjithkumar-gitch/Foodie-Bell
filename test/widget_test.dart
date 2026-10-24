import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:foodiebell/features/user/splash/splash_screen.dart';

void main() {
  testWidgets('Splash screen shows branding then navigates to login', (
    WidgetTester tester,
  ) async {
    // splash_screen.dart falls back to a cached session phone via
    // SharedPreferences when Firebase isn't initialized (as here) — needs a
    // mocked backing store or the plugin channel throws.
    SharedPreferences.setMockInitialValues({});

    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(path: '/', builder: (context, state) => const SplashScreen()),
        GoRoute(
          path: '/auth/login',
          builder: (context, state) => const Placeholder(),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(child: MaterialApp.router(routerConfig: router)),
    );

    expect(find.byType(SplashScreen), findsOneWidget);
    expect(find.text('Your neighbourhood, delivered fast'), findsOneWidget);

    // Let the splash screen's auto-navigation timer and transition finish so
    // no pending timers leak past the end of the test.
    await tester.pump(const Duration(milliseconds: 1900));
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.byType(Placeholder), findsOneWidget);
  });
}
