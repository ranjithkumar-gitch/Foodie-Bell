import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/personal_notification.dart';

/// Written by the `onOrderStatusChange` Cloud Function — this app only ever
/// reads and deletes from it, never writes a new one itself.
const personalNotificationsCollectionPath = 'personal_notifications';

CollectionReference<Map<String, dynamic>> get personalNotificationsCollection =>
    FirebaseFirestore.instance.collection(personalNotificationsCollectionPath);

PersonalNotification? _fromDoc(
  QueryDocumentSnapshot<Map<String, dynamic>> doc,
) {
  final data = doc.data();
  final recipientId = data['recipientId'] as String?;
  final title = data['title'] as String?;
  if (recipientId == null || title == null) return null;
  return PersonalNotification(
    id: doc.id,
    recipientId: recipientId,
    title: title,
    body: data['body'] as String? ?? '',
    orderId: data['orderId'] as String?,
    type: data['type'] as String?,
    createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
  );
}

/// Every personal notification for [accountId], newest first — feeds every
/// role's Notifications screen (`notification_wall.dart`). A `family`
/// provider since each role watches their own account's id, not a fixed one.
final firestorePersonalNotificationsProvider =
    StreamProvider.family<List<PersonalNotification>, String>((ref, accountId) {
      return personalNotificationsCollection
          .where('recipientId', isEqualTo: accountId)
          .orderBy('createdAt', descending: true)
          .limit(100)
          .snapshots()
          .map(
            (snap) => snap.docs
                .map(_fromDoc)
                .whereType<PersonalNotification>()
                .toList(),
          );
    });

/// Deletes one recipient's own notification (`notification_wall.dart`'s
/// delete button) — only ever their own doc, so this can never remove
/// anyone else's copy of the same event.
Future<void> deletePersonalNotification(String id) =>
    personalNotificationsCollection.doc(id).delete();
