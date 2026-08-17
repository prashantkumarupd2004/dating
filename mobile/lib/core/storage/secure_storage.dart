import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorage {
  static const _storage = FlutterSecureStorage();
  static const _accessKey = 'access_token';
  static const _refreshKey = 'refresh_token';
  static const _userIdKey = 'user_id';
  static const _profileCompleteKey = 'profile_complete';

  // In-memory cache to avoid EncryptedSharedPreferences race in GoRouter redirect
  static String? _cachedAccessToken;
  static bool? _cachedProfileComplete;

  static Future<void> saveTokens(String access, String refresh) async {
    _cachedAccessToken = access;
    await Future.wait([
      _storage.write(key: _accessKey, value: access),
      _storage.write(key: _refreshKey, value: refresh),
    ]);
  }

  static Future<String?> getAccessToken() async {
    if (_cachedAccessToken != null) return _cachedAccessToken;
    final token = await _storage.read(key: _accessKey);
    _cachedAccessToken = token;
    return token;
  }

  static Future<String?> getRefreshToken() => _storage.read(key: _refreshKey);

  static Future<void> saveUserId(String id) => _storage.write(key: _userIdKey, value: id);
  static Future<String?> getUserId() => _storage.read(key: _userIdKey);

  static Future<void> setProfileComplete(bool complete) async {
    _cachedProfileComplete = complete;
    await _storage.write(key: _profileCompleteKey, value: complete ? 'true' : 'false');
  }

  static Future<bool> isProfileComplete() async {
    if (_cachedProfileComplete != null) return _cachedProfileComplete!;
    final val = await _storage.read(key: _profileCompleteKey);
    _cachedProfileComplete = val == 'true';
    return _cachedProfileComplete!;
  }

  static Future<void> clear() async {
    _cachedAccessToken = null;
    _cachedProfileComplete = null;
    await Future.wait([
      _storage.delete(key: _accessKey),
      _storage.delete(key: _refreshKey),
      _storage.delete(key: _userIdKey),
      _storage.delete(key: _profileCompleteKey),
    ]);
  }

  static Future<bool> isLoggedIn() async {
    if (_cachedAccessToken != null && _cachedAccessToken!.isNotEmpty) return true;
    final token = await _storage.read(key: _accessKey);
    _cachedAccessToken = token;
    return token != null && token.isNotEmpty;
  }
}
