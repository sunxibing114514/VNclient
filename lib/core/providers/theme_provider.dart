import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/app_backgrounds.dart';

/// How a VN's title should be displayed in lists and detail pages.
enum TitleDisplayMode {
  /// Romanized / main title (the API `title` field).
  romanized,

  /// Original-script title (the API `alttitle` / main title's `title` field).
  japanese,
}

/// Persisted theme settings: seed color, brightness mode, background theme,
/// whether to blur sexual/violent images, the custom background path, and the
/// preferred title display mode.
class ThemeSettings {
  const ThemeSettings({
    this.seedColor = const Color(0xFF325064),
    this.mode = ThemeMode.dark,
    this.backgroundId = 'angel',
    this.blurNsfw = true,
    this.customBackgroundPath,
    this.titleDisplay = TitleDisplayMode.romanized,
  });

  final Color seedColor;
  final ThemeMode mode;

  /// The persisted background id (see [AppBackgrounds.byId]).
  final String backgroundId;

  /// Whether sexual/violent cover images are blurred by default.
  final bool blurNsfw;

  /// Absolute path to a user-picked background image (only meaningful when
  /// [backgroundId] is `custom`).
  final String? customBackgroundPath;

  /// Whether VN titles are shown romanized or in the original script.
  final TitleDisplayMode titleDisplay;

  /// Resolved background descriptor.
  AppBackground get background =>
      AppBackgrounds.byId(backgroundId, customPath: customBackgroundPath);

  /// The effective seed color: when a background theme is active, follows the
  /// background's seed color so the theme color matches the wallpaper.
  Color get effectiveSeedColor =>
      backgroundId == 'none' ? seedColor : background.seedColor;

  ThemeSettings copyWith({
    Color? seedColor,
    ThemeMode? mode,
    String? backgroundId,
    bool? blurNsfw,
    String? customBackgroundPath,
    TitleDisplayMode? titleDisplay,
  }) {
    return ThemeSettings(
      seedColor: seedColor ?? this.seedColor,
      mode: mode ?? this.mode,
      backgroundId: backgroundId ?? this.backgroundId,
      blurNsfw: blurNsfw ?? this.blurNsfw,
      customBackgroundPath:
          customBackgroundPath ?? this.customBackgroundPath,
      titleDisplay: titleDisplay ?? this.titleDisplay,
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
  static const _keyCustomBg = 'theme_custom_bg_path';
  static const _keyTitleDisplay = 'theme_title_display';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final seed = prefs.getInt(_keySeed);
    final modeStr = prefs.getString(_keyMode);
    final bgId = prefs.getString(_keyBg);
    final blur = prefs.getBool(_keyBlur);
    final customBg = prefs.getString(_keyCustomBg);
    final titleStr = prefs.getString(_keyTitleDisplay);
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
      customBackgroundPath: customBg,
      titleDisplay: switch (titleStr) {
        'japanese' => TitleDisplayMode.japanese,
        _ => TitleDisplayMode.romanized,
      },
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

  /// Sets a user-picked image file as the background. The file is copied into
  /// the app's documents directory so it persists, and the persisted id is set
  /// to `custom`.
  Future<void> setCustomBackground(File sourceFile) async {
    final dir = await AppBackgrounds.customBackgroundsDir();
    final destPath = '$dir/custom_bg${_ext(sourceFile.path)}';
    await sourceFile.copy(destPath);
    state = state.copyWith(
      backgroundId: 'custom',
      customBackgroundPath: destPath,
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyBg, 'custom');
    await prefs.setString(_keyCustomBg, destPath);
  }

  Future<void> setBlurNsfw(bool value) async {
    state = state.copyWith(blurNsfw: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyBlur, value);
  }

  Future<void> setTitleDisplay(TitleDisplayMode mode) async {
    state = state.copyWith(titleDisplay: mode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _keyTitleDisplay,
      switch (mode) {
        TitleDisplayMode.romanized => 'romanized',
        TitleDisplayMode.japanese => 'japanese',
      },
    );
  }

  String _ext(String path) {
    final dot = path.lastIndexOf('.');
    return dot >= 0 ? path.substring(dot) : '.jpg';
  }
}

final themeNotifierProvider =
    StateNotifierProvider<ThemeNotifier, ThemeSettings>((ref) {
  return ThemeNotifier();
});
