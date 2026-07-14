import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/app_backgrounds.dart';

/// Persisted theme settings: seed color, brightness mode, background theme,
/// and whether to blur sexual/violent images.
class ThemeSettings {
  const ThemeSettings({
    this.seedColor = const Color(0xFF325064),
    this.mode = ThemeMode.dark,
    this.backgroundId = 'angel',
    this.blurNsfw = true,
  });

  final Color seedColor;
  final ThemeMode mode;

  /// The persisted background id (see [AppBackgrounds.byId]).
  final String backgroundId;

  /// Whether sexual/violent cover images are blurred by default.
  final bool blurNsfw;

  /// Resolved background descriptor.
  AppBackground get background => AppBackgrounds.byId(backgroundId);

  /// The effective seed color: when a background theme is active, follows the
  /// background's seed color so the theme color matches the wallpaper.
  Color get effectiveSeedColor =>
      backgroundId == 'none' ? seedColor : background.seedColor;

  ThemeSettings copyWith({
    Color? seedColor,
    ThemeMode? mode,
    String? backgroundId,
    bool? blurNsfw,
  }) {
    return ThemeSettings(
      seedColor: seedColor ?? this.seedColor,
      mode: mode ?? this.mode,
      backgroundId: backgroundId ?? this.backgroundId,
      blurNsfw: blurNsfw ?? this.blurNsfw,
    );
  }
}

/// State notifier that persists theme settings via [SharedPreferences].
class ThemeNotifier extends StateNotifier<ThemeSettings> {
  ThemeNotifier() : super(const ThemeSettings()) {
    _load();
  }

  static const _keySeed = 'theme_seed_color';
  static const _keyMode = 'theme_mode';
  static const _keyBg = 'theme_background';
  static const _keyBlur = 'theme_blur_nsfw';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final seed = prefs.getInt(_keySeed);
    final modeStr = prefs.getString(_keyMode);
    final bgId = prefs.getString(_keyBg);
    final blur = prefs.getBool(_keyBlur);
    state = ThemeSettings(
      seedColor: seed == null
          ? const Color(0xFF325064)
          : Color(seed).withValues(alpha: 1.0),
      mode: switch (modeStr) {
        'light' => ThemeMode.light,
        'system' => ThemeMode.system,
        _ => ThemeMode.dark,
      },
      backgroundId: bgId ?? 'angel',
      blurNsfw: blur ?? true,
    );
  }

  Future<void> setSeedColor(Color color) async {
    state = state.copyWith(seedColor: color);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keySeed, color.toARGB32());
  }

  Future<void> setMode(ThemeMode mode) async {
    state = state.copyWith(mode: mode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _keyMode,
      switch (mode) {
        ThemeMode.light => 'light',
        ThemeMode.system => 'system',
        ThemeMode.dark => 'dark',
      },
    );
  }

  Future<void> setBackground(String backgroundId) async {
    final bg = AppBackgrounds.byId(backgroundId);
    state = state.copyWith(
      backgroundId: backgroundId,
      seedColor: bg.seedColor,
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyBg, backgroundId);
    await prefs.setInt(_keySeed, bg.seedColor.toARGB32());
  }

  Future<void> setBlurNsfw(bool value) async {
    state = state.copyWith(blurNsfw: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyBlur, value);
  }
}

final themeNotifierProvider =
    StateNotifierProvider<ThemeNotifier, ThemeSettings>((ref) {
  return ThemeNotifier();
});
