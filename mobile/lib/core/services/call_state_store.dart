import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

/// Persists the currently active call's metadata to SharedPreferences so it
/// survives process restarts (e.g. after the user swipes the app from Recent
/// Apps and then taps the ongoing-call notification).
///
/// Design constraints:
/// - Does NOT persist Agora tokens long-term — tokens are reused only within
///   the same session (~24h expiry). For very long-lived restoration (> 1h),
///   the app validates with the backend and, if needed, would re-fetch a token.
/// - Clear is idempotent — calling it multiple times is safe.
/// - Save is idempotent — always overwrites the previous state.
class CallStateStore {
  CallStateStore._();
  static final CallStateStore instance = CallStateStore._();

  // ── SharedPreferences keys ────────────────────────────────────────────────
  static const _kCallId       = 'active_call_id';
  static const _kChannelId    = 'active_call_channel_id';
  static const _kAgoraToken   = 'active_call_agora_token';
  static const _kAgoraAppId   = 'active_call_agora_app_id';
  static const _kUid          = 'active_call_uid';
  static const _kCallType     = 'active_call_type';      // 'AUDIO' | 'VIDEO'
  static const _kMode         = 'active_call_mode';      // 'listener' | 'user'
  static const _kListenerName = 'active_call_listener_name';
  static const _kTimestamp    = 'active_call_timestamp'; // epoch millis

  /// Maximum age of a stored call state before it is considered stale.
  /// Agora tokens are valid for ~24h, so 3h is a safe conservative limit.
  static const _maxAgeMs = 3 * 60 * 60 * 1000; // 3 hours

  // ── Save ─────────────────────────────────────────────────────────────────

  /// Persist active call state. Call this when Agora `onJoinChannelSuccess`
  /// fires so that the data is always in sync with the live session.
  Future<void> save({
    required String callId,
    required String channelId,
    required String agoraToken,
    required String agoraAppId,
    required int    uid,
    required String callType,
    required String mode,
    required String listenerName,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kCallId,       callId);
      await prefs.setString(_kChannelId,    channelId);
      await prefs.setString(_kAgoraToken,   agoraToken);
      await prefs.setString(_kAgoraAppId,   agoraAppId);
      await prefs.setInt   (_kUid,          uid);
      await prefs.setString(_kCallType,     callType);
      await prefs.setString(_kMode,         mode);
      await prefs.setString(_kListenerName, listenerName);
      await prefs.setInt   (_kTimestamp,    DateTime.now().millisecondsSinceEpoch);
      debugPrint('[ACTIVE_CALL_SAVED] callId=$callId type=$callType mode=$mode');
    } catch (e) {
      debugPrint('[CallStateStore] save error: $e');
    }
  }

  // ── Clear ─────────────────────────────────────────────────────────────────

  /// Remove all persisted call state. Idempotent — safe to call multiple times.
  Future<void> clear() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await Future.wait([
        prefs.remove(_kCallId),
        prefs.remove(_kChannelId),
        prefs.remove(_kAgoraToken),
        prefs.remove(_kAgoraAppId),
        prefs.remove(_kUid),
        prefs.remove(_kCallType),
        prefs.remove(_kMode),
        prefs.remove(_kListenerName),
        prefs.remove(_kTimestamp),
      ]);
      debugPrint('[ACTIVE_CALL_CLEARED]');
    } catch (e) {
      debugPrint('[CallStateStore] clear error: $e');
    }
  }

  // ── Read ──────────────────────────────────────────────────────────────────

  /// Returns the persisted [ActiveCallState], or null if none exists or it is
  /// stale (> [_maxAgeMs] old).
  Future<ActiveCallState?> read() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final callId = prefs.getString(_kCallId);
      if (callId == null || callId.isEmpty) return null;

      final ts = prefs.getInt(_kTimestamp) ?? 0;
      final age = DateTime.now().millisecondsSinceEpoch - ts;
      if (age > _maxAgeMs) {
        debugPrint('[CallStateStore] Stale call state ($age ms old) — clearing');
        await clear();
        return null;
      }

      return ActiveCallState(
        callId:       callId,
        channelId:    prefs.getString(_kChannelId)    ?? '',
        agoraToken:   prefs.getString(_kAgoraToken)   ?? '',
        agoraAppId:   prefs.getString(_kAgoraAppId)   ?? '',
        uid:          prefs.getInt   (_kUid)          ?? 0,
        callType:     prefs.getString(_kCallType)     ?? 'AUDIO',
        mode:         prefs.getString(_kMode)         ?? 'user',
        listenerName: prefs.getString(_kListenerName) ?? 'Call',
      );
    } catch (e) {
      debugPrint('[CallStateStore] read error: $e');
      return null;
    }
  }

  /// Quick check — true if there is a non-stale active call stored.
  Future<bool> isActive() async => (await read()) != null;
}

// ── Value object ──────────────────────────────────────────────────────────────

class ActiveCallState {
  final String callId;
  final String channelId;
  final String agoraToken;
  final String agoraAppId;
  final int    uid;
  final String callType;    // 'AUDIO' | 'VIDEO'
  final String mode;        // 'listener' | 'user'
  final String listenerName;

  const ActiveCallState({
    required this.callId,
    required this.channelId,
    required this.agoraToken,
    required this.agoraAppId,
    required this.uid,
    required this.callType,
    required this.mode,
    required this.listenerName,
  });

  /// Convert to the `extra` map expected by AudioCallScreen / VideoCallScreen.
  Map<String, dynamic> toRouteExtra() => {
    'mode':         mode,
    'callId':       callId,
    'channelId':    channelId,
    'agoraToken':   agoraToken,
    'agoraAppId':   agoraAppId,
    'uid':          uid,
    'listenerName': listenerName,
    'restored':     true,   // flag so call screen knows it is a restoration
  };

  @override
  String toString() =>
      'ActiveCallState(callId=$callId, type=$callType, mode=$mode)';
}
