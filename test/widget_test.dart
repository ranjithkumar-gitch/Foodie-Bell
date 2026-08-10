import 'package:flutter_test/flutter_test.dart';

import 'package:foodiebell/main.dart';

void main() {
  testWidgets('App boots to splash screen', (WidgetTester tester) async {
    await tester.pumpWidget(const FoodieBellApp());

    expect(find.text('FoodieBell'), findsOneWidget);

    // Let the splash screen's auto-navigation timer and transition finish so
    // no pending timers leak past the end of the test.
    await tester.pump(const Duration(milliseconds: 1900));
    await tester.pump(const Duration(milliseconds: 600));
  });
}
