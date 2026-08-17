import 'dart:async';
import 'package:flutter/foundation.dart';
import '../network/api_client.dart';
import '../storage/secure_storage.dart';
import '../socket/socket_service.dart';

/// Manages user session persistence and token refresh
class SessionManager {
  static final SessionManager _instance = SessionManager._internal();
  factory SessionManager() => _instance;
  SessionManager._internal();

  Timer? _refreshTimer;
  DateTime? _lastRefreshTime;
  bool _isRefreshing = false;

  /// Initialize session manager - call this after user login
  Future<void> initialize() async {
    final isLoggedIn = await SecureStorage.isLoggedIn();
    if (isLoggedIn) {
      _startPeriodicRefresh();
    }
  }

  /// Start periodic token refresh (every 6 days to ensure 7-day tokens stay fresh)
  void _startPeriodicRefresh() {
    _refreshTimer?.cancel();

    // Refresh token every 6 days
    const refreshInterval = Duration(days: 6);

    _refreshTimer = Timer.periodic(refreshInterval, (timer) {
      _performTokenRefresh();
    });

    debugPrint('✅ Session manager initialized - periodic refresh enabled');
  }

  /// Perform token refresh
  Future<void> _performTokenRefresh() async {
    if (_isRefreshing) return;

    _isRefreshing = true;
    try {
      final success = await api.refreshTokenIfNeeded();
      if (success) {
        _lastRefreshTime = DateTime.now();
        debugPrint('✅ Token refreshed successfully');

        // Reconnect socket with fresh token
        if (socketService.isConnected) {
          socketService.disconnect();
          await Future.delayed(const Duration(milliseconds: 500));
          await socketService.connect();
        }
      }
    } catch (e) {
      debugPrint('❌ Token refresh failed: $e');
    } finally {
      _isRefreshing = false;
    }
  }

  /// Manually refresh token (call on app resume from background)
  Future<bool> refreshSession() async {
    try {
      final success = await api.refreshTokenIfNeeded();
      if (success) {
        _lastRefreshTime = DateTime.now();

        // Reconnect socket if needed
        if (socketService.isConnected) {
          socketService.disconnect();
          await Future.delayed(const Duration(milliseconds: 500));
          await socketService.connect();
        }
      }
      return success;
    } catch (e) {
      debugPrint('❌ Session refresh failed: $e');
      return false;
    }
  }

  /// Check if session is still valid
  Future<bool> isSessionValid() async {
    return await SecureStorage.isLoggedIn();
  }

  /// Clear session and stop refresh timer
  Future<void> clearSession() async {
    _refreshTimer?.cancel();
    _refreshTimer = null;
    _lastRefreshTime = null;
    await SecureStorage.clear();
    socketService.disconnect();
    debugPrint('✅ Session cleared');
  }

  /// Get last refresh time
  DateTime? get lastRefreshTime => _lastRefreshTime;
}

final sessionManager = SessionManager();
