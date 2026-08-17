import 'dart:async';
import 'package:dio/dio.dart';
import '../constants/app_constants.dart';
import '../storage/secure_storage.dart';
import 'api_request_counter.dart';

class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;
  ApiClient._internal();

  late final Dio _dio;
  late final Dio _refreshDio;
  bool _isRefreshing = false;
  final List<void Function()> _refreshQueue = [];

  void init() {
    _dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      sendTimeout: const Duration(seconds: 30),
      headers: {'Content-Type': 'application/json'},
    ));

    _refreshDio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
    ));

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        // Track request for flood detection
        apiRequestCounter.record('${options.method} ${options.path}');

        // Log every request in debug mode to track request patterns
        debugPrint('🌐 [API Request] ${options.method} ${options.path}');

        final token = await SecureStorage.getAccessToken();
        if (token != null) options.headers['Authorization'] = 'Bearer $token';
        handler.next(options);
      },
      onError: (error, handler) async {
        // Log all errors with details
        debugPrint('❌ [API Error] ${error.response?.statusCode} - ${error.requestOptions.method} ${error.requestOptions.path}');

        // Handle 429 Too Many Requests
        if (error.response?.statusCode == 429) {
          final retryAfter = _parseRetryAfter(error.response?.headers);
          debugPrint('⚠️ Rate limited (429) on ${error.requestOptions.path} — retry after ${retryAfter}s');
          debugPrint('⚠️ Request details: ${error.requestOptions.method} ${error.requestOptions.uri}');

          // Do NOT automatically retry on 429
          // Let the error propagate so the user sees feedback
          // The UI should show a user-friendly message
          handler.next(error);
          return;
        }

        // Handle 401 Unauthorized (token expired)
        if (error.response?.statusCode == 401) {
          debugPrint('🔐 [401] Token expired, attempting refresh...');

          try {
            // If already refreshing, queue until done
            if (_isRefreshing) {
              debugPrint('🔐 [401] Already refreshing, queuing retry...');
              final completer = Completer<void>();
              _refreshQueue.add(() => completer.complete());
              await completer.future;
              final token = await SecureStorage.getAccessToken();
              if (token == null) return handler.next(error);
              error.requestOptions.headers['Authorization'] = 'Bearer $token';
              final response = await _dio.fetch(error.requestOptions);
              return handler.resolve(response);
            }

            // Refresh the token
            await _refreshAccessToken();
            final token = await SecureStorage.getAccessToken();
            error.requestOptions.headers['Authorization'] = 'Bearer $token';
            final response = await _dio.fetch(error.requestOptions);
            debugPrint('✅ [401] Retry after refresh succeeded');
            return handler.resolve(response);
          } catch (e) {
            // Token refresh failed, clear storage and force re-login
            debugPrint('❌ [401] Token refresh failed: $e');
            await SecureStorage.clear();
            handler.next(error);
          }
        } else {
          handler.next(error);
        }
      },
    ));
  }

  Future<void> _refreshAccessToken() async {
    if (_isRefreshing) return;

    _isRefreshing = true;
    try {
      final refresh = await SecureStorage.getRefreshToken();
      if (refresh == null || refresh.isEmpty) {
        throw Exception('No refresh token available');
      }

      final response = await _refreshDio.post(
        '/api/auth/refresh',
        data: {'refreshToken': refresh},
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        final data = response.data['data'];
        await SecureStorage.saveTokens(
          data['accessToken'],
          data['refreshToken'],
        );
      } else {
        throw Exception('Token refresh failed');
      }
    } catch (e) {
      await SecureStorage.clear();
      rethrow;
    } finally {
      _isRefreshing = false;
      for (final cb in _refreshQueue) { cb(); }
      _refreshQueue.clear();
    }
  }

  // Public method to manually refresh token (called on app resume)
  Future<bool> refreshTokenIfNeeded() async {
    try {
      final token = await SecureStorage.getAccessToken();
      if (token == null || token.isEmpty) return false;

      await _refreshAccessToken();
      return true;
    } catch (e) {
      return false;
    }
  }

  Dio get dio => _dio;

  /// Parse Retry-After header (seconds or HTTP date)
  int _parseRetryAfter(Headers? headers) {
    if (headers == null) return 60; // default 60 seconds

    final retryAfter = headers.value('retry-after');
    if (retryAfter == null) return 60;

    // Try parsing as seconds (integer)
    final seconds = int.tryParse(retryAfter);
    if (seconds != null) return seconds;

    // Try parsing as HTTP date (RFC 1123 format)
    try {
      final date = DateTime.parse(retryAfter);
      final diff = date.difference(DateTime.now()).inSeconds;
      return diff > 0 ? diff : 60;
    } catch (_) {
      return 60;
    }
  }

  Future<Response> get(String path, {Map<String, dynamic>? params}) =>
      _dio.get(path, queryParameters: params);

  Future<Response> post(String path, {dynamic data}) => _dio.post(path, data: data);

  Future<Response> patch(String path, {dynamic data}) => _dio.patch(path, data: data);

  Future<Response> delete(String path) => _dio.delete(path);
}

final api = ApiClient();
