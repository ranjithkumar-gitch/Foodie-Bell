import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodiebell/core/session/access_scope.dart';
import 'package:foodiebell/data/models/account.dart';
import 'package:foodiebell/data/providers/earnings_provider.dart';
import 'package:foodiebell/data/providers/order_actions.dart';
import 'package:foodiebell/data/providers/settlement_provider.dart';
import 'package:foodiebell/data/providers/vendor_incidents_provider.dart';
import 'package:foodiebell/features/manager/incidents/reversal_proposal_sheet.dart';
import 'package:foodiebell/features/manager/settlement/cancellation_settlement_section.dart';
import 'package:foodiebell/l10n/generated/app_localizations.dart';
import 'package:foodiebell/shared/settlement_payments_screen.dart';
import 'package:foodiebell/shared/settlement/settlement_report.dart';
import 'package:foodiebell/shared/widgets/cancellation_money_cards.dart';
import 'package:foodiebell/shared/widgets/currency_text.dart';

/// Phase I.4.1: reversing a shop's cancellation charge — the Manager's
/// proposal with the server's figures, the reversal's refund and Quicky's
/// funding in the daily settlement, the shop's refund on its card and
/// payments. Every figure is the server's.
final en = lookupAppLocalizations(const Locale('en'));

Widget _app(Widget home, {List<Override> overrides = const []}) => ProviderScope(
  overrides: overrides,
  child: MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: home),
  ),
);

String rs(int paise) => AppFormat.currency(paise / 100);

final _incident = VendorIncident('O1_postAcceptanceCancellation', {
  'orderId': 'O1',
  'vendorId': 'v1',
  'kind': 'postAcceptanceCancellation',
  'reasonCode': 'equipmentFailure',
  'penalty': {'scenario': 'B', 'chargePaise': 2000, 'driverSharePaise': 1000},
});

/// Case 2 of the approved examples: ₹20 charge, ₹8 confirmed, ₹12 recorded but not confirmed.
const _plan = CancellationReversalPlan({
  'chargePaise': 2000,
  'collectedPaise': 800,
  'pendingPaise': 1200,
  'disputedPaise': 0,
  'otherChargesPaise': 0,
  'unpaidPaise': 1200,
  'waivedPaise': 1200,
  'refundPaise': 800,
  'driverCompPreservedPaise': 1000,
  'compFundingPaise': 1000,
  'remittanceReturnPaise': 0,
  'quickyCostPaise': 2000,
  'quickyNetPaise': -1000,
});

void main() {
  group('Manager: propose reversing a charge', () {
    Widget sheet({PreviewReversal? preview, ProposeReversal? propose}) => ReversalProposalSheet(
      incident: _incident,
      preview: preview ?? (_) async => (plan: _plan, status: null),
      propose: propose ?? (id, {required reason, required evidence, required idempotencyKey}) async => (adjustmentId: 'a1', duplicate: false),
    );

    Future<void> fill(WidgetTester tester) async {
      await tester.enterText(find.byKey(const Key('reversalReason')), 'Power cut in the area');
      await tester.enterText(find.byKey(const Key('reversalEvidence')), 'Electricity board notice, photo in ticket 42');
      await tester.pump();
    }

    testWidgets('loading', (tester) async {
      final pending = Completer<ReversalPreview>();
      await tester.pumpWidget(_app(sheet(preview: (_) => pending.future)));
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byKey(const Key('submitReversal')), findsNothing);
      pending.complete((plan: _plan, status: null));
      await tester.pumpAndSettle();
    });

    testWidgets("shows the server's figures before sending: unconfirmed money isn't counted", (tester) async {
      await tester.pumpWidget(_app(sheet()));
      await tester.pumpAndSettle();
      for (final (label, paise) in [
        ('Original charge', 2000),
        ('Confirmed paid by the shop', 800),
        ('Recorded, not yet confirmed (not counted)', 1200),
        ('Still unpaid', 1200),
        ('Waived', 1200),
        ('Refund owed to the shop', 800),
        ('Driver keeps', 1000),
        ('QuickMandi pays for the reversal', 2000),
      ]) {
        expect(find.text(label), findsOneWidget, reason: label);
        expect(find.descendant(of: find.ancestor(of: find.text(label), matching: find.byType(Row)).first, matching: find.text(rs(paise))), findsOneWidget, reason: label);
      }
      expect(find.textContaining('neither gain nor lose'), findsOneWidget);
    });

    testWidgets('needs a reason and evidence; one key, reused on retry', (tester) async {
      final keys = <String>[];
      await tester.pumpWidget(_app(sheet(propose: (id, {required reason, required evidence, required idempotencyKey}) async {
        keys.add(idempotencyKey);
        if (keys.length == 1) throw const OrderActionException('Network timeout');
        return (adjustmentId: 'a1', duplicate: false);
      })));
      await tester.pumpAndSettle();
      final submit = find.byKey(const Key('submitReversal'));
      expect(tester.widget<ElevatedButton>(submit).onPressed, isNull);
      await tester.enterText(find.byKey(const Key('reversalReason')), 'Power cut in the area');
      await tester.pump();
      expect(tester.widget<ElevatedButton>(submit).onPressed, isNull, reason: 'evidence is required');
      await fill(tester);
      await tester.ensureVisible(submit);
      await tester.tap(submit);
      await tester.pumpAndSettle();
      expect(find.text('Network timeout'), findsOneWidget);
      await tester.tap(submit);
      await tester.pumpAndSettle();
      expect(keys, hasLength(2));
      expect(keys[1], keys[0]);
    });

    testWidgets('a duplicate send returns the first', (tester) async {
      String? message;
      await tester.pumpWidget(_app(Builder(builder: (context) => TextButton(
        onPressed: () async => message = await showModalBottomSheet<String>(
          context: context,
          isScrollControlled: true,
          builder: (_) => sheet(propose: (id, {required reason, required evidence, required idempotencyKey}) async => (adjustmentId: 'a1', duplicate: true)),
        ),
        child: const Text('open'),
      ))));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await fill(tester);
      await tester.ensureVisible(find.byKey(const Key('submitReversal')));
      await tester.tap(find.byKey(const Key('submitReversal')));
      await tester.pumpAndSettle();
      expect(message, 'This reversal was already sent.');
    });

    testWidgets('already pending or approved: no second proposal', (tester) async {
      await tester.pumpWidget(_app(sheet(preview: (_) async => (plan: _plan, status: 'pending'))));
      await tester.pumpAndSettle();
      expect(find.text('A reversal is already waiting for the Super Admin.'), findsOneWidget);
      expect(find.byKey(const Key('submitReversal')), findsNothing);
    });

    testWidgets('unauthorized: the refusal is shown, nothing to send', (tester) async {
      await tester.pumpWidget(_app(sheet(preview: (_) async => throw const OrderActionException("That isn't your territory.", code: 'permission-denied'))));
      await tester.pumpAndSettle();
      expect(find.text("That isn't your territory."), findsOneWidget);
      expect(find.byKey(const Key('submitReversal')), findsNothing);
    });

    testWidgets('busy: a second tap sends nothing more', (tester) async {
      var calls = 0;
      final reply = Completer<({String adjustmentId, bool duplicate})>();
      await tester.pumpWidget(_app(sheet(propose: (id, {required reason, required evidence, required idempotencyKey}) {
        calls++;
        return reply.future;
      })));
      await tester.pumpAndSettle();
      await fill(tester);
      final submit = find.byKey(const Key('submitReversal'));
      await tester.ensureVisible(submit);
      await tester.tap(submit);
      await tester.pump();
      expect(tester.widget<ElevatedButton>(submit).onPressed, isNull);
      await tester.tap(submit, warnIfMissed: false);
      expect(calls, 1);
      reply.complete((adjustmentId: 'a1', duplicate: false));
      await tester.pumpAndSettle();
    });
  });

  group('Manager: daily settlement after a reversal', () {
    const manager = 'manager:m1';
    Map<String, dynamic> ob(String from, String to, String purpose, int outstanding) =>
        {'from': from, 'to': to, 'purpose': purpose, 'openingPaise': 0, 'assessedPaise': outstanding, 'settledPaise': 0, 'disputedPaise': 0, 'outstandingPaise': outstanding};
    // Case 3: ₹20 collected, driver paid, share remitted — then reversed.
    final statement = SettlementStatement({
      'settlementDay': '2026-10-30',
      'remainingBalances': {'quicky': 2000, 'vendor:v1': -2000},
      'obligations': [
        ob(manager, 'vendor:v1', 'cancellationRefund', 2000),
        ob('quicky', manager, 'cancellationRemittanceReturn', 1000),
        ob('quicky', manager, 'cancellationCompFunding', 1000),
      ],
      'cancellationFinance': {
        'assessedPaise': 2000, 'collectedPaise': 2000, 'reversedPaise': 2000, 'waivedPaise': 0, 'refundEstablishedPaise': 2000,
        'outstandingRefundPaise': 2000, 'outstandingRemittanceReturnPaise': 1000, 'outstandingCompFundingPaise': 1000, 'refundedPaise': 0,
      },
    });

    testWidgets("refund to the shop and QuickMandi's funding are their own rows; the refund is recorded with its purpose", (tester) async {
      final calls = <Map<String, Object?>>[];
      await tester.pumpWidget(_app(SingleChildScrollView(child: CancellationSettlementSection(
        statement: statement,
        territoryId: 't1',
        managerKey: manager,
        partyName: (p) => p,
        onRecorded: () async {},
        record: ({required idempotencyKey, required territoryId, required day, required fromParty, required toParty, required amountPaise, required upi, reference, purpose}) async =>
            calls.add({'from': fromParty, 'to': toParty, 'amount': amountPaise, 'purpose': purpose}),
        pickPayment: (context, title, suggested) async => (amountPaise: suggested, upi: false, reference: null),
      ))));
      expect(find.text('Reversed by QuickMandi'), findsOneWidget);
      expect(find.text('Refund still owed to shops'), findsOneWidget);
      expect(find.text('Cancellation charge refund to the shop'), findsOneWidget);
      expect(find.text('QuickMandi returning its share (reversal)'), findsOneWidget);
      expect(find.text('QuickMandi funding driver compensation (reversal)'), findsOneWidget);
      // The Manager pays the refund; Quicky's two payments are marked
      // settled by QuickMandi, not the Manager (2026-11-20).
      expect(find.text('Paid'), findsOneWidget);
      expect(find.text('Got paid'), findsNothing);
      expect(find.text('QuickMandi marks this settled.'), findsNWidgets(2));
      await tester.tap(find.text('Paid'));
      await tester.pumpAndSettle();
      expect(calls.single, {'from': manager, 'to': 'vendor:v1', 'amount': 2000, 'purpose': 'cancellationRefund'});
    });

    test("order balances leave the reversal's obligations out", () {
      expect(statement.generalBalances, isEmpty);
    });
  });

  group('the shop', () {
    testWidgets('its card shows the waived part and the refund owed, then refunded', (tester) async {
      await tester.pumpWidget(_app(const VendorCancellationChargesCard(
        totals: AsyncData(EarningsFigures({
          'cancellationCharges': 1, 'cancellationChargesPaise': 2000, 'cancellationChargesCollectedPaise': 800, 'cancellationChargesOutstandingPaise': 0,
          'cancellationChargesReversedPaise': 2000, 'cancellationChargesWaivedPaise': 1200, 'cancellationRefundDuePaise': 800,
        })),
      )));
      expect(find.text(en.cancelChargesReversed), findsOneWidget);
      expect(find.text(en.cancelChargesWaived), findsOneWidget);
      expect(find.text(en.cancelRefundDue), findsOneWidget);
      expect(find.text(rs(1200)), findsOneWidget);
      // Phase I.4.2: refunded is always shown (₹0 until the shop confirms one).
      expect(find.text(en.cancelRefunded), findsOneWidget);
      await tester.pumpWidget(_app(const VendorCancellationChargesCard(
        totals: AsyncData(EarningsFigures({'cancellationCharges': 1, 'cancellationChargesPaise': 2000, 'cancellationChargesReversedPaise': 2000, 'cancellationRefundedPaise': 800})),
      )));
      expect(find.text(en.cancelRefunded), findsOneWidget);
      expect(find.text(rs(800)), findsOneWidget);
    });

    testWidgets('a refund from QuickMandi says QuickMandi and what it is for, and asks the shop to confirm', (tester) async {
      const t = SettlementTransfer(id: 'r1', from: 'quicky', to: 'vendor:v1', amountPaise: 2000, method: 'cash', status: 'pendingAck', counterparty: 'vendor:v1', settlementDay: '2026-10-30', purpose: 'cancellationRefund');
      await tester.pumpWidget(_app(const SettlementPaymentsScreen(), overrides: [
        accessScopeProvider.overrideWithValue(const AccessScope(role: AppRole.vendor, accountId: 'v1', isActive: true)),
        myTransfersProvider.overrideWith((ref) => Stream.value([t])),
        myPartyMoneyLinesProvider.overrideWith((ref) => const []),
      ]));
      await tester.pumpAndSettle();
      expect(find.text('QuickMandi paid you'), findsOneWidget);
      expect(find.text('Cancellation charge refund to the shop'), findsOneWidget);
      expect(find.text('Did you receive this money?'), findsOneWidget);
      expect(find.text('Manager paid you'), findsNothing);
    });
  });
}
