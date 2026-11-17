import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// The new-order buzzer (2026-11-17) for Vendors (an order placed at their
/// shop) and Drivers (a delivery offer in their territory).
///
/// Two halves:
///  - In the app: [OrderBuzzer.start] rings `assets/sounds/order_buzzer.wav`
///    on a loop while the new-order pop-up is open, up to [maxRing], and
///    [OrderBuzzer.stop] ends it when the pop-up is answered.
///  - App in the background or closed: the push itself rings, on the
///    Android channel [kOrderBuzzerChannelId] (`local_notifications.dart`,
///    sound `res/raw/order_buzzer.wav`) and with `order_buzzer.wav` from the
///    iOS app bundle — the server names both for these two pushes
///    (QuickyAdmin `functions/notifications.js`).
class OrderBuzzer {
  OrderBuzzer._();

  static const maxRing = Duration(seconds: 45);

  static AudioPlayer? _player;
  static Timer? _cutoff;
  static int _holders = 0;

  /// Starts ringing (or keeps ringing if already on — each [start] needs
  /// its own [stop]).
  static Future<void> start() async {
    _holders++;
    if (_holders > 1) return;
    try {
      final player = _player ??= AudioPlayer(playerId: 'order_buzzer');
      await player.setAudioContext(
        AudioContext(
          android: const AudioContextAndroid(
            usageType: AndroidUsageType.notificationRingtone,
            contentType: AndroidContentType.sonification,
            audioFocus: AndroidAudioFocus.gainTransientMayDuck,
          ),
          iOS: AudioContextIOS(category: AVAudioSessionCategory.playback, options: const {AVAudioSessionOptions.duckOthers}),
        ),
      );
      await player.setReleaseMode(ReleaseMode.loop);
      await player.play(AssetSource('sounds/order_buzzer.wav'), volume: 1);
      _cutoff?.cancel();
      _cutoff = Timer(maxRing, _silence);
    } catch (e) {
      debugPrint('order_buzzer: play failed: $e');
    }
  }

  /// Stops one [start]; the sound ends when every caller has stopped.
  static Future<void> stop() async {
    if (_holders == 0) return;
    _holders--;
    if (_holders == 0) await _silence();
  }

  static Future<void> _silence() async {
    _holders = 0;
    _cutoff?.cancel();
    _cutoff = null;
    try {
      await _player?.stop();
    } catch (e) {
      debugPrint('order_buzzer: stop failed: $e');
    }
  }
}

/// The Android notification channel that rings the buzzer. Must match
/// `channelId` in QuickyAdmin `functions/notifications.js`.
const kOrderBuzzerChannelId = 'order_buzzer_v1';
