import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Per-vendor, per-day "cash reconciled" checkpoint for Manager's Daily
/// Settlement (10 PM Reconciliation, spec §7.9) — replaces the old
/// screen-local `Set<String>` (`manager_daily_settlement_screen.dart`,
/// reset on every navigation away from the screen) with a real, persisted
/// flag. Doc id is deterministic (`{vendorId}_{yyyy-MM-dd}`) so toggling the
/// same vendor/day always hits the same doc rather than piling up
/// duplicates, and "reconciled" for one day never bleeds into another.
const settlementReconciliationsCollectionPath = 'settlement_reconciliations';

CollectionReference<Map<String, dynamic>> get settlementReconciliationsCollection =>
    FirebaseFirestore.instance.collection(settlementReconciliationsCollectionPath);

String _dateKey(DateTime date) => '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

String reconciliationDocId(String vendorId, DateTime date) => '${vendorId}_${_dateKey(date)}';

/// Every reconciliation checkpoint recorded network-wide, live — the screen
/// filters this client-side (`{vendorId}_{today}` membership) the same way
/// other flat collections in this app are filtered by caller-side fields.
final firestoreReconciledSettlementsProvider = StreamProvider<Set<String>>((ref) {
  return settlementReconciliationsCollection.snapshots().map((snapshot) => snapshot.docs.map((d) => d.id).toSet());
});

Future<void> setSettlementReconciled(String vendorId, DateTime date, {required bool reconciled, String? managerId}) {
  final docId = reconciliationDocId(vendorId, date);
  if (reconciled) {
    return settlementReconciliationsCollection.doc(docId).set({
      'vendorId': vendorId,
      'managerId': managerId,
      'date': Timestamp.fromDate(DateTime(date.year, date.month, date.day)),
      'reconciledAt': FieldValue.serverTimestamp(),
    });
  }
  return settlementReconciliationsCollection.doc(docId).delete();
}
