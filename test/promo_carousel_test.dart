import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodiebell/core/theme/app_theme.dart';
import 'package:foodiebell/features/user/home/promo_carousel.dart';

Widget _host({int count = 3, bool reduceMotion = false}) => MaterialApp(
  theme: AppTheme.light(),
  home: MediaQuery(
    data: MediaQueryData(
      size: const Size(400, 800),
      disableAnimations: reduceMotion,
    ),
    child: Scaffold(
      body: PromoCarousel(
        count: count,
        itemBuilder: (context, i, height) => SizedBox(
          height: height,
          child: Center(child: Text('card $i')),
        ),
      ),
    ),
  ),
);

/// Steps the clock 100 ms a frame until [done], up to [max]; returns the time taken.
Future<Duration> _stepUntil(
  WidgetTester tester,
  bool Function() done, {
  Duration max = const Duration(seconds: 10),
}) async {
  var elapsed = Duration.zero;
  while (!done() && elapsed < max) {
    await tester.pump(const Duration(milliseconds: 100));
    elapsed += const Duration(milliseconds: 100);
  }
  return elapsed;
}

void main() {
  testWidgets(
    'continuous loop: auto-advances every ~5 s, the first card follows the last, dots jump the short way',
    (tester) async {
      await tester.pumpWidget(_host());
      double page() =>
          tester.widget<PageView>(find.byType(PageView)).controller!.page!;
      final start = page();
      expect(start % 3, 0, reason: 'starts on the first card');
      expect(
        start,
        greaterThan(50),
        reason: 'starts mid-list: room to scroll back past the first card (and it recentres near the ends)',
      );
      // Hero centred, both neighbours peeking in (cut at the edges).
      expect(find.text('card 0'), findsOneWidget);
      expect(find.text('card 1'), findsOneWidget);
      expect(find.text('card 2'), findsOneWidget);

      final toNext = await _stepUntil(tester, () => page() >= start + 1);
      expect(page(), start + 1);
      expect(toNext, greaterThanOrEqualTo(const Duration(milliseconds: 4900)));
      expect(toNext, lessThan(const Duration(seconds: 7)));

      // Card 1 → 2 → then card 0 again, still moving forward (no rewind).
      await _stepUntil(
        tester,
        () => page() >= start + 3,
        max: const Duration(seconds: 14),
      );
      expect(page(), start + 3);
      expect(page() % 3, 0);

      // From card 0, card 2 is one step back round the loop.
      await tester.tap(find.byKey(const Key('promoDot_2')));
      await _stepUntil(
        tester,
        () => page() <= start + 2,
        max: const Duration(seconds: 2),
      );
      expect(page(), start + 2);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'one card with reduced motion: renders, no dots, never advances',
    (tester) async {
      await tester.pumpWidget(_host(count: 1, reduceMotion: true));
      await _stepUntil(tester, () => false, max: const Duration(seconds: 7));
      expect(find.text('card 0'), findsOneWidget);
      expect(find.byKey(const Key('promoDot_0')), findsNothing);
      expect(
        tester.widget<PageView>(find.byType(PageView)).controller!.page,
        0,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
