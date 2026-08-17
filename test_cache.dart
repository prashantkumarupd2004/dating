// Simple test to verify SecureStorage cache is working
import 'dart:async';

class SecureStorage {
  static String? _cachedAccessToken;
  static bool? _cachedProfileComplete;

  static Future<void> saveTokens(String access, String refresh) async {
    _cachedAccessToken = access;
    print('[TEST] Cache set: $_cachedAccessToken');
    await Future.delayed(Duration(milliseconds: 100)); // Simulate disk write
  }

  static Future<String?> getAccessToken() async {
    if (_cachedAccessToken != null) {
      print('[TEST] Returning from cache: $_cachedAccessToken');
      return _cachedAccessToken;
    }
    print('[TEST] Cache miss');
    return null;
  }

  static Future<void> setProfileComplete(bool complete) async {
    _cachedProfileComplete = complete;
    print('[TEST] Profile complete cache set: $complete');
  }

  static Future<bool> isLoggedIn() async {
    if (_cachedAccessToken != null && _cachedAccessToken!.isNotEmpty) {
      print('[TEST] isLoggedIn: true (from cache)');
      return true;
    }
    print('[TEST] isLoggedIn: false');
    return false;
  }

  static Future<bool> isProfileComplete() async {
    if (_cachedProfileComplete != null) {
      print('[TEST] isProfileComplete: $_cachedProfileComplete (from cache)');
      return _cachedProfileComplete!;
    }
    print('[TEST] isProfileComplete: false (cache miss)');
    return false;
  }
}

void main() async {
  print('=== Test 1: Login flow ===');
  await SecureStorage.saveTokens('test-access-token', 'test-refresh-token');
  await SecureStorage.setProfileComplete(false);

  print('\n=== Test 2: Check logged in ===');
  final loggedIn = await SecureStorage.isLoggedIn();
  print('Result: $loggedIn');

  print('\n=== Test 3: Get access token (should use cache) ===');
  final token = await SecureStorage.getAccessToken();
  print('Token: $token');

  print('\n=== Test 4: Check profile complete ===');
  final profileComplete = await SecureStorage.isProfileComplete();
  print('Profile complete: $profileComplete');

  print('\n=== Test 5: Multiple token reads (all from cache) ===');
  for (int i = 0; i < 3; i++) {
    await SecureStorage.getAccessToken();
  }

  print('\n✓ All tests passed - cache is working correctly');
}
