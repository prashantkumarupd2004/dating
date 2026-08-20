import 'dart:async';
import 'package:flutter/foundation.dart';
import '../network/api_client.dart';
import '../network/api_endpoints.dart';

/// Sends periodic heartbeat POSTs to the backend while a call is active.
///
/// Purpose:
///   The server-side watchdog reads [callerLastSeen] / [listenerLastSeen]
///   on every IN_PROGRESS call and terminates the call if either participant
///   has been silent for more than [participantTimeoutMs] (default 45s).
///   This protects billing when a participant force-kills their app.
///
/// Usage:
///   // Start when Agora reports onJoinChannelSuccess:
///   CallHeartbeatService.instance.start(callId: id, role: 'user');
///
///   // Stop when call ends (endCall, handleCallEnded, dispose):
///   CallHeartbeatService.instance.stop();
///
/// Design decisions:
///   - Singleton — only one active call at a time.
///   - [start] is idempotent: calling it while already running first stops
///     the previous timer, then starts fresh with the new callId/role.
///   - [stop]  is idempotent: safe to call multiple times.
///   - Heartbeat failures are logged but do NOT crash the call. If the
///     server can't be reached, the watchdog will eventually time out and
///     terminate the call server-side — that is the correct safe behaviour.
class CallHeartbeatService {
  CallHeartbeatService._();
  static final instance = CallHeartbeatService._();

  // ── Configuration ─────────────────────────────────────────────────────────

  /// How often to send a heartbeat.
  /// Must be significantly less than backend's participantTimeoutMs (45s).
  static const Duration _interval = Duration(seconds: 12);

  // ── State ─────────────────────────────────────────────────────────────────

  Timer?  _timer;
  String? _callId;
  String? _role;   // 'user' | 'listener'
  bool    _running = false;

  bool get isRunning => _running;

  // ── Public API ────────────────────────────────────────────────────────────

  /// Start sending heartbeats for [callId] with the given [role].
  ///
  /// Sends the first heartbeat immediately (before the timer fires) so the
  /// server sees a presence signal as soon as the client joins.
  void start({ required String callId, required String role }) {
    if (_running) {
      debugPrint('[CALL_HEARTBEAT] Already running for callId=$_callId — stopping first');
      _stopTimer();
    }
    _callId  = callId;
    _role    = role;
    _running = true;

    debugPrint('[CALL_HEARTBEAT] Starting heartbeat: callId=$callId role=$role interval=${_interval.inSeconds}s');

    // Send immediately on join
    _sendHeartbeat();

    _timer = Timer.periodic(_interval, (_) => _sendHeartbeat());
  }

  /// Stop the heartbeat. Safe to call multiple times.
  void stop() {
    if (!_running) return;
    debugPrint('[CALL_HEARTBEAT] Stopping heartbeat for callId=$_callId');
    _stopTimer();
  }

  // ── Private ───────────────────────────────────────────────────────────────

  void _stopTimer() {
    _timer?.cancel();
    _timer   = null;
    _running = false;
    _callId  = null;
    _role    = null;
  }

  Future<void> _sendHeartbeat() async {
    final callId = _callId;
    final role   = _role;
    if (callId == null || role == null || callId.isEmpty) return;

    try {
      final resp = await api.post(
        ApiEndpoints.callHeartbeat(callId),
        data: { 'role': role },
      );

      final ok = resp.data['data']?['ok'] as bool? ?? false;
      if (!ok) {
        // Backend says call is no longer active (heartbeat returned ok:false).
        // The watchdog or the other participant ended it. Stop the heartbeat
        // timer — the socket 'call:ended' event should arrive shortly and
        // handle the Flutter-side cleanup.
        debugPrint('[CALL_HEARTBEAT] Server returned ok=false for callId=$callId — stopping heartbeat');
        _stopTimer();
      } else {
        debugPrint('[CALL_HEARTBEAT] ✓ callId=$callId role=$role');
      }
    } catch (e) {
      // Network error — log and continue. The watchdog will handle
      // extended absence. Do not stop the timer on a single failure.
      debugPrint('[CALL_HEARTBEAT] ✗ Error sending heartbeat: $e');
    }
  }
}
