import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodiebell/data/providers/earnings_provider.dart';
import 'package:foodiebell/data/providers/settlement_provider.dart';
import 'package:foodiebell/features/manager/settlement/cancellation_settlement_section.dart';
import 'package:foodiebell/l10n/generated/app_localizations.dart';
import 'package:foodiebell/shared/widgets/cancellation_money_cards.dart';
import 'package:foodiebell/shared/widgets/currency_text.dart';

/// Phase I.4.2: the shop's figures are the server's sums over its
/// collectors, with an unconfirmed refund shown apart; the Manager sees
/// what's recorded and awaiting confirmation on each obligation, and can
/// only record the rest.
final en = lookupAppLocalizations(const Locale('en'));

Widget _app(Widget home) => ProviderScope(
  child: MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: SingleChildScrollView(child: home)),
  ),
);

String rs(int paise) => AppFormat.currency(paise / 100);

/// The value on the card's row labelled [label].
String _row(WidgetTester tester, String label) => tester
    .widgetList<Text>(find.descendant(of: find.ancestor(of: find.text(label), matching: find.byType(Row)).first, matching: find.byType(Text)))
    .map((t) => t.data)
    .where((d) => d != label)
    .join();

void main() {
  group("the shop's card", () {
    testWidgets('two Managers and Quicky: the sums, never netted; every figure shown', (tester) async {
      // A: ₹20 reversed, ₹8 paid → ₹8 refund due. B: ₹20, ₹5 paid → ₹15 owed. Quicky: ₹10 owed.
      await tester.pumpWidget(_app(const VendorCancellationChargesCard(
        totals: AsyncData(EarningsFigures({
          'cancellationCharges': 3,
          'cancellationChargesPaise': 5000,
          'cancellationChargesCollectedPaise': 1300,
          'cancellationChargesReversedPaise': 2000,
          'cancellationChargesWaivedPaise': 1200,
          'cancellationChargesOutstandingPaise': 2500,
          'cancellationRefundDuePaise': 800,
          'cancellationRefundPendingPaise': 0,
          'cancellationRefundedPaise': 0,
        })),
      )));
      expect(_row(tester, en.cancelChargesCharged), rs(5000));
      expect(_row(tester, en.cancelChargesPaid), rs(1300));
      expect(_row(tester, en.cancelChargesWaived), rs(1200));
      expect(_row(tester, en.cancelChargesOwed), rs(2500));
      expect(_row(tester, en.cancelRefundDue), rs(800));
      expect(_row(tester, en.cancelRefunded), rs(0));
      expect(find.text(en.cancelRefundPending), findsNothing);
    });

    testWidgets('a recorded refund is shown as awaiting confirmation, not as refunded', (tester) async {
      await tester.pumpWidget(_app(const VendorCancellationChargesCard(
        totals: AsyncData(EarningsFigures({
          'cancellationCharges': 1, 'cancellationChargesPaise': 2000, 'cancellationChargesCollectedPaise': 800, 'cancellationChargesReversedPaise': 2000,
          'cancellationChargesWaivedPaise': 1200, 'cancellationRefundDuePaise': 800, 'cancellationRefundPendingPaise': 800, 'cancellationRefundedPaise': 0,
        })),
      )));
      expect(_row(tester, en.cancelRefundPending), rs(800));
      expect(_row(tester, en.cancelRefunded), rs(0));
      expect(_row(tester, en.cancelRefundDue), rs(800));
    });
  });

  group("the Manager's settlement: what's recorded is reserved", () {
    const manager = 'manager:m1';
    SettlementStatement statement({required int pendingPaise}) => SettlementStatement({
      'settlementDay': '2026-10-31',
      'remainingBalances': <String, int>{},
      'obligations': [
        {'from': manager, 'to': 'vendor:v1', 'purpose': 'cancellationRefund', 'openingPaise': 0, 'assessedPaise': 2000, 'settledPaise': 0, 'disputedPaise': 0, 'outstandingPaise': 2000},
      ],
      'paymentsAwaitingAcknowledgement': [
        if (pendingPaise > 0) {'transferId': 'r1', 'from': manager, 'to': 'vendor:v1', 'amountPaise': pendingPaise, 'status': 'pendingAck', 'purpose': 'cancellationRefund'},
        // A pending payment of another purpose isn't counted against it.
        {'transferId': 'g1', 'from': manager, 'to': 'vendor:v1', 'amountPaise': 999, 'status': 'pendingAck', 'purpose': 'general'},
      ],
      'cancellationFinance': {'reversedPaise': 2000, 'outstandingRefundPaise': 2000},
    });

    Widget section(SettlementStatement s, {required void Function(int suggested) onPick}) => CancellationSettlementSection(
      statement: s,
      territoryId: 't1',
      managerKey: manager,
      partyName: (p) => p,
      onRecorded: () async {},
      record: ({required idempotencyKey, required territoryId, required day, required fromParty, required toParty, required amountPaise, required upi, reference, purpose}) async {},
      pickPayment: (context, title, suggested) async {
        onPick(suggested);
        return null;
      },
    );

    testWidgets('part of the refund recorded: shown as awaiting confirmation; only the rest is suggested', (tester) async {
      int? suggested;
      await tester.pumpWidget(_app(section(statement(pendingPaise: 1200), onPick: (v) => suggested = v)));
      expect(find.text('Awaiting confirmation ${rs(1200)}'), findsOneWidget);
      expect(find.text('Outstanding ${rs(2000)}'), findsOneWidget, reason: 'still owed until the shop confirms');
      await tester.tap(find.text('Paid'));
      await tester.pumpAndSettle();
      expect(suggested, 800);
    });

    testWidgets('all of it recorded: nothing more to record until it is confirmed or disputed', (tester) async {
      await tester.pumpWidget(_app(section(statement(pendingPaise: 2000), onPick: (_) {})));
      expect(find.text('Awaiting confirmation ${rs(2000)}'), findsOneWidget);
      expect(find.text('Paid'), findsNothing);
    });
  });
}
