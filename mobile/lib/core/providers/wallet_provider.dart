import 'package:flutter/foundation.dart';
import '../network/api_client.dart';
import '../network/api_endpoints.dart';
import '../socket/socket_service.dart';

/// Centralized wallet balance state management
/// Ensures all screens display the same up-to-date balance
class WalletProvider extends ChangeNotifier {
  static final WalletProvider _instance = WalletProvider._internal();
  factory WalletProvider() => _instance;
  WalletProvider._internal() {
    _setupSocketListener();
  }

  double _balance = 0;
  bool _isLoading = false;
  DateTime? _lastFetch;
  bool _hasFetchedOnce = false;
  Future<void>? _pendingRequest; // Track in-flight request for deduplication

  double get balance => _balance;
  bool get isLoading => _isLoading;
  bool get hasFetchedOnce => _hasFetchedOnce;

  /// Fetch balance from server with request deduplication
  Future<void> fetchBalance({bool force = false}) async {
    // Avoid duplicate requests within 30 seconds unless forced
    if (!force &&
        _lastFetch != null &&
        DateTime.now().difference(_lastFetch!) < const Duration(seconds: 30)) {
      debugPrint('[WalletProvider] Skipping fetch — cached (${DateTime.now().difference(_lastFetch!).inSeconds}s ago)');
      return;
    }

    // Request deduplication: if a request is already in progress, reuse it
    if (_pendingRequest != null) {
      debugPrint('[WalletProvider] Request already in progress, reusing...');
      return _pendingRequest;
    }

    if (_isLoading) {
      debugPrint('[WalletProvider] Already loading, skipping...');
      return;
    }

    _isLoading = true;
    notifyListeners();

    // Create and track the pending request
    _pendingRequest = _performFetch().whenComplete(() {
      _pendingRequest = null; // Clear after completion
    });

    return _pendingRequest;
  }

  /// Internal method to perform the actual fetch
  Future<void> _performFetch() async {
    try {
      debugPrint('[WalletProvider] Fetching balance from API: ${ApiEndpoints.walletBalance}');
      final resp = await api.get(ApiEndpoints.walletBalance);

      debugPrint('[WalletProvider] Raw response: ${resp.data}');

      // Safely parse the response — backend returns { success, data: { balance, ... } }
      final responseData = resp.data;
      double? parsedBalance;

      if (responseData is Map) {
        // Try data.balance first (standard response)
        final data = responseData['data'];
        if (data is Map) {
          final val = data['balance'];
          // PostgreSQL Decimal type returns as String in JSON (e.g., "1000")
          // Must handle both String and num types
          if (val is num) {
            parsedBalance = val.toDouble();
          } else if (val is String) {
            parsedBalance = double.tryParse(val);
          }
          debugPrint('[WalletProvider] Parsed from data.balance: $parsedBalance (raw=$val, type=${val.runtimeType})');
        }

        // Fallback: try top-level balance
        if (parsedBalance == null) {
          final val = responseData['balance'];
          if (val is num) {
            parsedBalance = val.toDouble();
          } else if (val is String) {
            parsedBalance = double.tryParse(val);
          }
          debugPrint('[WalletProvider] Parsed from top-level balance: $parsedBalance');
        }
      }

      if (parsedBalance != null) {
        _balance = parsedBalance;
        _lastFetch = DateTime.now();
        _hasFetchedOnce = true;
        debugPrint('[WalletProvider] Balance fetched successfully: $_balance');
      } else {
        debugPrint('[WalletProvider] Could not parse balance from: $responseData');
        // DO NOT AUTO-RETRY — let user manually refresh if needed
      }
    } catch (e, stackTrace) {
      debugPrint('[WalletProvider] Error fetching balance: $e');
      debugPrint('[WalletProvider] Stack trace: $stackTrace');
      // DO NOT AUTO-RETRY — exponential retry floods cause 429 errors
      // User can manually pull-to-refresh if needed
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Update balance locally (optimistic update before server confirms)
  void updateBalance(double newBalance) {
    _balance = newBalance;
    _hasFetchedOnce = true;
    notifyListeners();
  }

  /// Add coins to current balance (e.g., after recharge)
  void addCoins(double coins) {
    _balance += coins;
    _hasFetchedOnce = true;
    notifyListeners();
    // DO NOT auto-fetch — let socket update or user manually refresh
    // Old code caused exponential retry floods leading to 429 errors
  }

  /// Deduct coins from current balance (e.g., after call)
  void deductCoins(double coins) {
    _balance = (_balance - coins).clamp(0, double.infinity);
    notifyListeners();
    // DO NOT auto-fetch — let socket update or user manually refresh
    // Old code caused exponential retry floods leading to 429 errors
  }

  /// Reset balance (e.g., on logout)
  void reset() {
    _balance = 0;
    _lastFetch = null;
    _hasFetchedOnce = false;
    notifyListeners();
  }

  /// Setup socket listener for real-time balance updates
  void _setupSocketListener() {
    socketService.on('wallet:balance', (data) {
      if (data is Map && data['balance'] != null) {
        final newBalance = (data['balance'] as num?)?.toDouble() ?? 0;
        debugPrint('[WalletProvider] Socket balance update: $newBalance');
        _balance = newBalance;
        _hasFetchedOnce = true;
        notifyListeners();
      }
    });
  }

  @override
  void dispose() {
    socketService.off('wallet:balance');
    super.dispose();
  }
}

final walletProvider = WalletProvider();

