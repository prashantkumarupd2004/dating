import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../constants/app_constants.dart';
import '../storage/secure_storage.dart';

/// Production-grade socket service.
///
/// Key guarantees:
/// * All [addListener] registrations are stored in [_handlers]; on every
///   reconnect they are replayed onto the new socket instance automatically.
/// * [removeListener] removes **only** the specific handler, never the whole
///   event — safe to call from multiple widgets independently.
/// * [emit] / [goOnline] / [goOffline] are no-ops when not connected and log
///   a debug warning instead of silently dropping data.
class SocketService {
  static final SocketService _instance = SocketService._internal();
  factory SocketService() => _instance;
  SocketService._internal();

  io.Socket? _socket;
  String? _listenerId;
  bool _isReconnecting = false;

  /// Per-event list of registered handlers.
  /// These survive across socket reconnects — they are re-registered whenever
  /// a new socket instance is created.
  final Map<String, List<Function(dynamic)>> _handlers = {};

  // ── Public connection API ────────────────────────────────────────────────

  Future<void> connect() async {
    if (_socket?.connected == true) return;
    final token = await SecureStorage.getAccessToken();
    if (token == null) return;

    _socket?.dispose();

    _socket = io.io(
      socketUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .setAuth({'token': token})
          .enableAutoConnect()
          .disableReconnection()
          .build(),
    );

    _socket!.onConnect((_) {
      debugPrint('✅ Socket connected');
      _isReconnecting = false;
      // Replay all registered listeners onto this new socket instance.
      _replayHandlers();
      // Re-emit presence if listener was online.
      if (_listenerId != null) {
        emit('presence:online', {'listenerId': _listenerId});
      }
    });

    _socket!.onDisconnect((_) => debugPrint('⚠️ Socket disconnected'));

    _socket!.onConnectError((e) {
      debugPrint('❌ Socket connect error: $e');
      if (!_isReconnecting) _reconnectWithFreshToken();
    });

    _socket!.on('error', (data) {
      debugPrint('❌ Socket error: $data');
      if (data.toString().contains('authentication') ||
          data.toString().contains('token')) {
        _reconnectWithFreshToken();
      }
    });

    // Register any handlers that were added before the socket was created.
    _replayHandlers();
  }

  Future<void> _reconnectWithFreshToken() async {
    if (_isReconnecting) return;
    _isReconnecting = true;
    try {
      await Future.delayed(const Duration(seconds: 1));
      final token = await SecureStorage.getAccessToken();
      if (token == null) {
        debugPrint('⚠️ No token for socket reconnection');
        return;
      }
      _socket?.disconnect();
      _socket?.dispose();
      await connect();
    } catch (e) {
      debugPrint('❌ Socket reconnection failed: $e');
    } finally {
      _isReconnecting = false;
    }
  }

  void disconnect() => _socket?.disconnect();

  // ── Listener management ──────────────────────────────────────────────────

  /// Register [handler] for [event].
  ///
  /// The handler is stored in [_handlers] so it survives reconnects and is
  /// immediately registered on the live socket (if connected).
  void addListener(String event, Function(dynamic) handler) {
    _handlers.putIfAbsent(event, () => []).add(handler);
    _socket?.on(event, handler);
    debugPrint('🔌 [Socket] addListener: $event (total: ${_handlers[event]!.length})');
  }

  /// Remove exactly [handler] from [event] — does NOT affect other handlers.
  void removeListener(String event, Function(dynamic) handler) {
    _handlers[event]?.remove(handler);
    if (_handlers[event]?.isEmpty ?? false) _handlers.remove(event);
    _socket?.off(event, handler);
    debugPrint('🔌 [Socket] removeListener: $event');
  }

  /// Re-registers all stored handlers on the current socket instance.
  /// Called after every successful socket (re)connect.
  void _replayHandlers() {
    final socket = _socket;
    if (socket == null) return;
    for (final entry in _handlers.entries) {
      for (final handler in entry.value) {
        socket.on(entry.key, handler);
      }
    }
    debugPrint('🔄 [Socket] Replayed ${_handlers.length} event(s) onto new socket');
  }

  // ── Emit helpers ─────────────────────────────────────────────────────────

  void emit(String event, [dynamic data]) {
    if (_socket?.connected != true) {
      debugPrint('⚠️ [Socket] emit("$event") skipped — not connected');
      return;
    }
    _socket!.emit(event, data);
  }

  bool get isConnected => _socket?.connected ?? false;

  // ── Presence ──────────────────────────────────────────────────────────────

  Future<void> goOnline(String listenerId) async {
    _listenerId = listenerId;
    if (!isConnected) {
      debugPrint('🔌 [Socket] Not connected — connecting before goOnline');
      await connect();
      // onConnect callback will emit presence:online after connect.
      return;
    }
    emit('presence:online', {'listenerId': listenerId});
    debugPrint('🟢 [Socket] presence:online emitted for $listenerId');
  }

  void goOffline() {
    _listenerId = null;
    emit('presence:offline');
    debugPrint('🔴 [Socket] presence:offline emitted');
  }

  void heartbeat() => emit('presence:heartbeat');

  // ── Legacy compatibility (kept for any callers that still use on/off) ─────

  /// Prefer [addListener] — this signature is kept for backward compatibility.
  void on(String event, Function(dynamic) handler) =>
      addListener(event, handler);

  /// Prefer [removeListener]. Passing no handler still works for callers that
  /// clear a single-handler event, but it removes ONLY the handlers stored in
  /// our registry for that event (not all socket.io listeners).
  void off(String event, [Function(dynamic)? handler]) {
    if (handler != null) {
      removeListener(event, handler);
    } else {
      // Remove all handlers registered through this service for this event.
      final stored = List<Function(dynamic)>.from(_handlers[event] ?? []);
      for (final h in stored) {
        _socket?.off(event, h);
      }
      _handlers.remove(event);
      debugPrint('🔌 [Socket] off (all): $event');
    }
  }
}

final socketService = SocketService();
