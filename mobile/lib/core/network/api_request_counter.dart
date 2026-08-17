import 'package:flutter/foundation.dart';

/// Tracks API request patterns to identify flooding issues
class ApiRequestCounter {
  static final ApiRequestCounter _instance = ApiRequestCounter._internal();
  factory ApiRequestCounter() => _instance;
  ApiRequestCounter._internal();

  final Map<String, List<DateTime>> _requests = {};
  int _totalRequests = 0;

  /// Record a request
  void record(String endpoint) {
    _totalRequests++;

    if (!_requests.containsKey(endpoint)) {
      _requests[endpoint] = [];
    }

    _requests[endpoint]!.add(DateTime.now());

    // Clean up old requests (older than 5 minutes)
    _cleanupOldRequests();

    // Log warning if too many requests
    _checkForFlood(endpoint);
  }

  /// Clean up requests older than 5 minutes
  void _cleanupOldRequests() {
    final cutoff = DateTime.now().subtract(const Duration(minutes: 5));
    _requests.forEach((endpoint, times) {
      times.removeWhere((time) => time.isBefore(cutoff));
    });
  }

  /// Check if an endpoint is being flooded
  void _checkForFlood(String endpoint) {
    final now = DateTime.now();
    final lastMinute = now.subtract(const Duration(minutes: 1));

    final recentRequests = _requests[endpoint]
        ?.where((time) => time.isAfter(lastMinute))
        .length ?? 0;

    if (recentRequests > 10) {
      debugPrint('🚨 [API FLOOD WARNING] $endpoint: $recentRequests requests in last minute!');
    }
  }

  /// Get request count for an endpoint in last N minutes
  int getCount(String endpoint, {int minutes = 1}) {
    final cutoff = DateTime.now().subtract(Duration(minutes: minutes));
    return _requests[endpoint]
        ?.where((time) => time.isAfter(cutoff))
        .length ?? 0;
  }

  /// Get total requests in last N minutes
  int getTotalCount({int minutes = 1}) {
    final cutoff = DateTime.now().subtract(Duration(minutes: minutes));
    int total = 0;
    _requests.forEach((endpoint, times) {
      total += times.where((time) => time.isAfter(cutoff)).length;
    });
    return total;
  }

  /// Print summary of requests
  void printSummary() {
    debugPrint('📊 [API Request Summary]');
    debugPrint('   Total requests: $_totalRequests');
    debugPrint('   Last 1 min: ${getTotalCount(minutes: 1)} requests');
    debugPrint('   Last 5 min: ${getTotalCount(minutes: 5)} requests');

    if (_requests.isNotEmpty) {
      debugPrint('   By endpoint (last 5 min):');
      _requests.forEach((endpoint, times) {
        final count = times.where((t) => t.isAfter(DateTime.now().subtract(const Duration(minutes: 5)))).length;
        if (count > 0) {
          debugPrint('     $endpoint: $count requests');
        }
      });
    }
  }

  /// Reset all counters
  void reset() {
    _requests.clear();
    _totalRequests = 0;
  }
}

final apiRequestCounter = ApiRequestCounter();
