import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Manages app language preference — persists selection in SharedPreferences.
/// Usage:
///   localeService.setLocale('hi');
///   localeService.locale.value → Locale('hi')
class LocaleService {
  LocaleService._();
  static final LocaleService instance = LocaleService._();

  static const _key = 'app_locale';
  static const _supported = ['en', 'hi'];

  final ValueNotifier<Locale> locale = ValueNotifier(const Locale('en'));

  /// Call once at app startup to restore persisted locale.
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_key) ?? 'en';
    locale.value = Locale(_supported.contains(saved) ? saved : 'en');
  }

  /// Persists and applies a new locale.
  Future<void> setLocale(String langCode) async {
    if (!_supported.contains(langCode)) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, langCode);
    locale.value = Locale(langCode);
  }

  String get currentCode => locale.value.languageCode;
  bool get isHindi => currentCode == 'hi';
}

/// Shorthand singleton accessor.
final localeService = LocaleService.instance;
