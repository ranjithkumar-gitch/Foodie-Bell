import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/notifications/fcm_topics.dart';
import '../models/notification_broadcast.dart';

/// Written by the `sendPushNotification` Cloud Function (QuickyAdmin's
/// `push_notification_screen.dart`) — this app only ever reads it.
const notificationBroadcastsCollectionPath = 'notification_broadcasts';

CollectionReference<Map<String, dynamic>> get notificationBroadcastsCollection =>
    FirebaseFirestore.instance.collection(notificationBroadcastsCollectionPath);

NotificationBroadcast? _fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
  final data = doc.data();
  final title = data['title'] as String?;
  final topic = data['topic'] as String?;
  if (title == null || topic == null) return null;
  return NotificationBroadcast(
    id: doc.id,
    title: title,
    body: data['body'] as String? ?? '',
    topic: topic,
    targetLabel: data['targetLabel'] as String? ?? topic,
    sentAt: (data['sentAt'] as Timestamp?)?.toDate(),
  );
}

/// Every push this device was actually subscribed to receive, newest first
/// — [kAllUsersTopic] plus the currently-subscribed territory's topic
/// (`currentTopicTerritoryProvider`, `fcm_topics.dart`), so switching
/// territory also changes what shows here, matching what this device is
/// really getting pushes for right now (past broadcasts to a
/// since-abandoned territory drop off, same as unsubscribing does on the
/// FCM side). Feeds `notifications_screen.dart`.
final firestoreNotificationsProvider = StreamProvider<List<NotificationBroadcast>>((ref) {
  final territory = ref.watch(currentTopicTerritoryProvider);
  final topics = territory == null ? [kAllUsersTopic] : [kAllUsersTopic, topicForTerritory(territory.id)];
  return notificationBroadcastsCollection
      .where('topic', whereIn: topics)
      .orderBy('sentAt', descending: true)
      .limit(50)
      .snapshots()
      .map((snap) => snap.docs.map(_fromDoc).whereType<NotificationBroadcast>().toList());
});
