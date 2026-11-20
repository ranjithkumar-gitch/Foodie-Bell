import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/session/access_scope.dart';
import '../models/account.dart';

/// Vendor cancellation accountability (Phase I.4, QuickyAdmin
/// `functions/orders.js` + `functions/accountability.js`). Everything here
/// is written only by the server; the app reads it.

/// A shop cancelling an accepted order (`vendor_incidents/{orderId}_{kind}`).
/// [remark] is the shop's internal note — for the Manager and Super Admin,
/// never the customer.
class VendorIncident {
  const VendorIncident(this.id, this.data);
  final String id;
  final Map<String, dynamic> data;

  String get orderId => data['orderId'] as String? ?? '';
  String get vendorId => data['vendorId'] as String? ?? '';
  String get kind => data['kind'] as String? ?? '';
  String get reasonCode => data['reasonCode'] as String? ?? '';
  String? get remark => data['remark'] as String?;
  String? get previousStatus => data['previousStatus'] as String?;
  String? get paymentMethod => data['paymentMethod'] as String?;
  String get settlementDay => data['settlementDay'] as String? ?? '';
  DateTime? get at => (data['at'] as Timestamp?)?.toDate();
  bool get driverAssigned => data['driverAssigned'] == true;

  /// `recentDriverRelease` / `recentDriverReassignment` (`functions/orders.js`):
  /// the driver changed just before — the case needs a closer look.
  List<String> get reviewFlags => [for (final f in (data['reviewFlags'] as List? ?? const [])) '$f'];

  Map<String, dynamic>? get _penalty => (data['penalty'] as Map?)?.cast<String, dynamic>();

  /// The charge the server assessed (paise) — 0 for a legacy order.
  int get chargePaise => (_penalty?['chargePaise'] as num?)?.toInt() ?? 0;
  int get driverSharePaise => (_penalty?['driverSharePaise'] as num?)?.toInt() ?? 0;

  /// `A` (no driver) or `B` (driver assigned).
  String? get scenario => _penalty?['scenario'] as String?;

  /// Why nothing was charged (e.g. `legacyOrderNoMoneySnapshot`).
  String? get noChargeReason => _penalty?['noChargeReason'] as String?;

  /// `manager` or `quicky` — who collects the charge.
  String? get collector => _penalty?['collector'] as String?;
}

/// A Manager or Super Admin review of an incident
/// (`vendor_incidents/{id}/reviews`). Excusing never moves money.
class IncidentReview {
  const IncidentReview(this.id, this.data);
  final String id;
  final Map<String, dynamic> data;

  /// `acknowledged`, `excused`, `warned` or `escalated`.
  String get outcome => data['outcome'] as String? ?? '';
  String? get note => data['note'] as String?;
  String get byRole => data['byRole'] as String? ?? '';
  DateTime? get at => (data['at'] as Timestamp?)?.toDate();
}

/// A review flag, in words.
String incidentFlagLabel(String flag) => switch (flag) {
  'recentDriverRelease' => 'Driver released just before',
  'recentDriverReassignment' => 'Driver reassigned just before',
  _ => flag,
};

const incidentReviewOutcomes = ['acknowledged', 'warned', 'excused', 'escalated'];

String incidentOutcomeLabel(String outcome) => switch (outcome) {
  'acknowledged' => 'Acknowledged',
  'warned' => 'Warned',
  'excused' => 'Excused',
  'escalated' => 'Escalated to QuickMandi',
  _ => outcome,
};

/// The latest cancellations on the signed-in Manager's own orders, newest
/// first (Phase I.5: `attributedManagerId` — the order's Manager — must be
/// theirs, by the query and by the rules).
final territoryIncidentsProvider = StreamProvider.autoDispose<List<VendorIncident>>((ref) {
  final scope = ref.watch(accessScopeProvider);
  final territoryId = scope?.role == AppRole.manager ? scope?.territoryId : null;
  if (scope == null || territoryId == null) return Stream.value(const []);
  return FirebaseFirestore.instance
      .collection('vendor_incidents')
      .where('territoryId', isEqualTo: territoryId)
      .where('attributedManagerId', isEqualTo: scope.accountId)
      .where('kind', isEqualTo: 'postAcceptanceCancellation')
      .orderBy('at', descending: true)
      .limit(50)
      .snapshots()
      .map((s) => [for (final d in s.docs) VendorIncident(d.id, d.data())]);
});

/// An incident's reviews, newest first.
final incidentReviewsProvider = StreamProvider.autoDispose.family<List<IncidentReview>, String>((ref, incidentId) {
  return FirebaseFirestore.instance
      .collection('vendor_incidents')
      .doc(incidentId)
      .collection('reviews')
      .orderBy('at', descending: true)
      .snapshots()
      .map((s) => [for (final d in s.docs) IncidentReview(d.id, d.data())]);
});

/// A vendor's reliability (`vendor_accountability/{vendorId}`): rolling
/// 7/30-day figures and informational flags. Null until the vendor's first
/// incident.
class VendorReliability {
  const VendorReliability(this.data);
  final Map<String, dynamic> data;

  Map<String, dynamic> _map(String k) => (data[k] as Map?)?.cast<String, dynamic>() ?? const {};
  int _int(Map<String, dynamic> m, String k) => (m[k] as num?)?.toInt() ?? 0;

  Map<String, dynamic> get _r7 => _map('rolling7');
  Map<String, dynamic> get _r30 => _map('rolling30');
  Map<String, dynamic> get _flags => _map('flags');

  int get accepted7 => _int(_r7, 'accepted');
  int get cancellations7 => _int(_r7, 'cancellations');
  int get rejections7 => _int(_r7, 'rejections');
  int get accepted30 => _int(_r30, 'accepted');
  int get cancellations30 => _int(_r30, 'cancellations');
  int get rejections30 => _int(_r30, 'rejections');
  int get excused30 => _int(_r30, 'excused');

  /// Counted cancellations ÷ accepted orders over 30 days (0–1), the server's.
  double get rate30 => (_r30['rate'] as num?)?.toDouble() ?? 0;

  bool get warning => _flags['warning'] == true;
  bool get reviewRequired => _flags['reviewRequired'] == true;
  bool get escalation => _flags['escalation'] == true;
  List<String> get rules => [for (final r in (_flags['rules'] as List? ?? const [])) '$r'];

  /// Older docs (before the beta thresholds were approved) say true.
  bool get provisionalThresholds => _flags['provisionalThresholds'] == true;

  /// Review required as of today, 7 and 14 days ago (newest first).
  List<bool> get reviewRequiredWeeks => [for (final w in (_flags['reviewRequiredWeeks'] as List? ?? const [])) w == true];
  String? get asOfDay => data['asOfDay'] as String?;
}

final vendorReliabilityProvider = StreamProvider.autoDispose.family<VendorReliability?, String>((ref, vendorId) {
  return FirebaseFirestore.instance
      .doc('vendor_accountability/$vendorId')
      .snapshots()
      .map((d) => d.exists ? VendorReliability(d.data()!) : null);
});
