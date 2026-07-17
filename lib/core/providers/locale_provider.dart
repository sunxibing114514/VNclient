import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persisted locale preference.
class LocaleNotifier extends StateNotifier<Locale> {
  LocaleNotifier() : super(const Locale('zh')) {
    _load();
  }

  static const _key = 'app_locale';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_key) ?? 'zh';
    state = Locale(code);
  }

  Future<void> setLocale(Locale locale) async {
    state = locale;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, locale.languageCode);
  }
}

final localeNotifierProvider =
    StateNotifierProvider<LocaleNotifier, Locale>((ref) {
  return LocaleNotifier();
});

/// Supported app languages.
const supportedLocales = <Locale>[
  Locale('zh'),
  Locale('en'),
];
