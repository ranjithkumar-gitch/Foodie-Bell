import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

import 'local_notifications.dart';

/// Attached to `MaterialApp.router` (`app.dart`) — kept as general
/// infrastructure for any app-wide `SnackBar` (not used by the push
/// handler below any more, see its doc comment).
final rootScaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

/// A push notification's `notification` payload auto-displays in the
/// system tray only while the app is backgrounded/terminated — FCM
/// deliberately leaves foreground display to the app. Called once from
/// `main()`; posts a real system-tray notification via
/// `local_notifications.dart` so a push looks the same (shows in the
/// notification bar) no matter what the User was doing when it arrived,
/// rather than a transient in-app `SnackBar` only visible while the app
/// happens to be in the foreground at that exact moment.
void registerForegroundNotificationHandler() {
  FirebaseMessaging.onMessage.listen((message) {
    final notification = message.notification;
    if (notification == null) return;
    final title = notification.title;
    final body = notification.body;
    if ((title == null || title.isEmpty) && (body == null || body.isEmpty)) return;
    showLocalNotification(title: title ?? '', body: body ?? '');
  });
}
