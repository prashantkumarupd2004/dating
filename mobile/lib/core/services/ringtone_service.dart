import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';

/// Singleton wrapper around flutter_ringtone_player.
/// Call [playIncoming] on the listener side, [playRingback] on the caller side,
/// and [stop] in both places when the call is answered, declined, or ended.
class RingtoneService {
  RingtoneService._();

  static final _player = FlutterRingtonePlayer();
  static bool _playing = false;

  /// Plays the device ringtone on loop — used by the LISTENER when an
  /// incoming call arrives.
  static Future<void> playIncoming() async {
    if (_playing) return;
    _playing = true;
    await _player.playRingtone(looping: true, volume: 1.0);
  }

  /// Plays the device ringtone on loop at a slightly lower volume — used by
  /// the CALLER while waiting for the listener to answer (ringback tone).
  static Future<void> playRingback() async {
    if (_playing) return;
    _playing = true;
    await _player.playRingtone(looping: true, volume: 0.7);
  }

  /// Stops any currently playing ringtone/ringback.
  static Future<void> stop() async {
    if (!_playing) return;
    _playing = false;
    await _player.stop();
  }
}
