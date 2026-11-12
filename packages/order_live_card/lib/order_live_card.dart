import 'package:flutter/services.dart';

/// The live order card in the Android notification bar (native layout,
/// `android/src/main/res/layout/olc_*.xml`). Works from any isolate the
/// plugin is registered in, including FCM's background one. Android only.
class OrderLiveCardNative {
  static const _channel = MethodChannel('order_live_card');

  /// Draws or replaces the card [id]/[tag]. [stage] and [hash] are kept on
  /// the notification so [active] can tell what is showing.
  static Future<void> show({
    required int id,
    required String tag,
    required String stage,
    required String hash,
    required String title,
    required String subtitle,
    required String emoji,
    required int step,
    required int steps,
    required String footerTitle,
    required String footerText,
    String? otp,
    String? otpLabel,
    required bool ongoing,
    required bool alert,
    required String route,
    required int color,
  }) => _channel.invokeMethod('show', {
    'id': id,
    'tag': tag,
    'stage': stage,
    'hash': hash,
    'title': title,
    'subtitle': subtitle,
    'emoji': emoji,
    'step': step,
    'steps': steps,
    'footerTitle': footerTitle,
    'footerText': footerText,
    'otp': otp,
    'otpLabel': otpLabel,
    'ongoing': ongoing,
    'alert': alert,
    'route': route,
    'color': color,
  });

  static Future<void> cancel(int id, String tag) => _channel.invokeMethod('cancel', {'id': id, 'tag': tag});

  /// `{stage, hash}` of the card showing as [id]/[tag], or null.
  static Future<({String? stage, String? hash})?> active(int id, String tag) async {
    final r = await _channel.invokeMapMethod<String, Object?>('active', {'id': id, 'tag': tag});
    return r == null ? null : (stage: r['stage'] as String?, hash: r['hash'] as String?);
  }

  /// The route of the card that launched the app (once), if one did.
  static Future<String?> takeLaunchRoute() => _channel.invokeMethod<String>('takeLaunchRoute');

  /// Called when a card is tapped while the app is running.
  static void onTap(void Function(String route) callback) {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'tap' && call.arguments is String) callback(call.arguments as String);
    });
  }
}
