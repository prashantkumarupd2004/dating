import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../constants/app_constants.dart';
import '../storage/secure_storage.dart';


class SocketService {
  static final SocketService _instance = SocketService._internal();
  factory SocketService() => _instance;
  SocketService._internal();

  io.Socket? _socket;
  String? _listenerId;
  bool _isReconnecting = false;

  Future<void> connect() async {
    if (_socket?.connected == true) return; // already connected — skip
    final token = await SecureStorage.getAccessToken();
    if (token == null) return;
    // Disconnect any existing (disconnected) socket before creating a new one
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
      if (_listenerId != null) emit('presence:online', {'listenerId': _listenerId});
    });

    _socket!.onDisconnect((_) => debugPrint('⚠️ Socket disconnected'));

    _socket!.onConnectError((e) {
      debugPrint('❌ Socket connect error: $e');
      // Try reconnecting with fresh token
      if (!_isReconnecting) {
        _reconnectWithFreshToken();
      }
    });

    _socket!.on('error', (data) {
      debugPrint('❌ Socket error: $data');
      if (data.toString().contains('authentication') || data.toString().contains('token')) {
        _reconnectWithFreshToken();
      }
    });
  }

  Future<void> _reconnectWithFreshToken() async {
    if (_isReconnecting) return;

    _isReconnecting = true;
    try {
      await Future.delayed(const Duration(seconds: 1));
      final token = await SecureStorage.getAccessToken();
      if (token == null) {
        debugPrint('⚠️ No token available for socket reconnection');
        return;
      }

      // Disconnect old socket
      _socket?.disconnect();
      _socket?.dispose();

      // Create new connection with fresh token
      await connect();
    } catch (e) {
      debugPrint('❌ Socket reconnection failed: $e');
    } finally {
      _isReconnecting = false;
    }
  }

  void disconnect() => _socket?.disconnect();

  void emit(String event, [dynamic data]) => _socket?.emit(event, data);

  void on(String event, Function(dynamic) handler) => _socket?.on(event, handler);

  void off(String event, [Function(dynamic)? handler]) {
    if (handler != null) {
      _socket?.off(event, handler);
    } else {
      _socket?.off(event);
    }
  }

  bool get isConnected => _socket?.connected ?? false;

  void goOnline(String listenerId) {
    _listenerId = listenerId;
    emit('presence:online', {'listenerId': listenerId});
  }

  void goOffline() {
    _listenerId = null;
    emit('presence:offline');
  }

  void heartbeat() => emit('presence:heartbeat');
}

final socketService = SocketService();
