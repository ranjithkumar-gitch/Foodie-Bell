import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'notification_routes.dart';
import 'order_buzzer.dart';

/// Posts a real system-tray notification for a push that arrives while the
/// app is open — FCM's `notification` payload only auto-displays in the
/// tray while the app is backgrounded/terminated (`fcm_topics.dart`'s
/// pushes rely on that default for those two states); this covers the
/// third state so a push looks the same regardless of what the User was
/// doing when it arrived, matching what a "push notification" is expected
/// to do.
final _plugin = FlutterLocalNotificationsPlugin();

const _channel = AndroidNotificationChannel(
  // Versioned suffix: Android notification channels are immutable once
  // created on-device — bumping the id (rather than editing this one in
  // place) is the only way to guarantee a device that saw an earlier build
  // of this channel actually picks up sound/vibration here, instead of
  // silently keeping whatever settings its first-ever version had.
  'push_default_v2',
  'QuickMandi notifications',
  description: 'Offers, announcements, and updates from QuickMandi.',
  importance: Importance.high,
  playSound: true,
  enableVibration: true,
);

/// New-order buzzer (2026-11-17, `order_buzzer.dart`): its own channel,
/// since an Android channel's sound can't change once created.
const _buzzerChannel = AndroidNotificationChannel(
  kOrderBuzzerChannelId,
  'New orders',
  description: 'Rings when a new order or delivery comes in.',
  importance: Importance.max,
  playSound: true,
  sound: RawResourceAndroidNotificationSound('order_buzzer'),
  enableVibration: true,
);

Future<void> initLocalNotifications() async {
  const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
  const iosInit = DarwinInitializationSettings();
  await _plugin.initialize(
    const InitializationSettings(android: androidInit, iOS: iosInit),
    // Tapping one opens its page (2026-11-17, `notification_routes.dart`).
    onDidReceiveNotificationResponse: (r) => handleLocalNotificationTap(r.payload),
  );
  // A tap on one of these that launched the app from closed.
  try {
    final launch = await _plugin.getNotificationAppLaunchDetails();
    if (launch?.didNotificationLaunchApp ?? false) {
      handleLocalNotificationTap(launch!.notificationResponse?.payload);
    }
  } catch (_) {}
  final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
  await android?.createNotificationChannel(_channel);
  await android?.createNotificationChannel(_buzzerChannel);
}

/// [buzzer]: rings the new-order buzzer instead of the usual sound.
Future<void> showLocalNotification({required String title, required String body, String? payload, bool buzzer = false}) {
  // Millisecond-based id: any two pushes landing in the same millisecond
  // would collide and one would silently replace the other in the tray —
  // acceptable here since a human can't trigger two real pushes that close
  // together, and it avoids needing a persisted counter for something this
  // low-stakes (a duplicate/replaced tray entry, not lost data — the bell
  // screen's own history, `firestore_notifications_provider.dart`, is the
  // source of truth regardless).
  final id = DateTime.now().millisecondsSinceEpoch.remainder(1 << 31);
  return _plugin.show(
    id,
    title,
    body,
    NotificationDetails(
      android: buzzer
          ? AndroidNotificationDetails(
              _buzzerChannel.id,
              _buzzerChannel.name,
              channelDescription: _buzzerChannel.description,
              importance: Importance.max,
              priority: Priority.max,
              playSound: true,
              sound: const RawResourceAndroidNotificationSound('order_buzzer'),
              enableVibration: true,
            )
          : AndroidNotificationDetails(
              _channel.id,
              _channel.name,
              channelDescription: _channel.description,
              importance: Importance.high,
              priority: Priority.high,
              playSound: true,
              enableVibration: true,
            ),
      iOS: DarwinNotificationDetails(sound: buzzer ? 'order_buzzer.wav' : null),
    ),
    payload: payload,
  );
}
