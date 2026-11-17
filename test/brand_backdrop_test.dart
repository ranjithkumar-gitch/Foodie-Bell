// The home page's background on every page (2026-11-17): each page sits on
// BrandBackdrop (normal background + the brand-green wash), and screens'
// own backgrounds are transparent so it shows through.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodiebell/core/theme/app_theme.dart';
import 'package:foodiebell/core/theme/brand_backdrop.dart';

void main() {
  testWidgets('every page sits on the brand backdrop; scaffolds and app bars are see-through', (tester) async {
    final theme = AppTheme.light();
    expect(theme.scaffoldBackgroundColor, Colors.transparent);
    expect(theme.appBarTheme.backgroundColor, Colors.transparent);

    await tester.pumpWidget(MaterialApp(
      theme: theme,
      home: Builder(
        builder: (context) => Scaffold(
          appBar: AppBar(title: const Text('First')),
          body: TextButton(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => Scaffold(appBar: AppBar(title: const Text('Second'))))),
            child: const Text('Open'),
          ),
        ),
      ),
    ));
    expect(find.byType(BrandBackdrop), findsOneWidget);
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.text('Second'), findsOneWidget);
    expect(find.ancestor(of: find.text('Second'), matching: find.byType(BrandBackdrop)), findsOneWidget);
  });
}
