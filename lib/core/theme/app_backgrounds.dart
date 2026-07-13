import 'package:flutter/material.dart';

/// A selectable app background theme: an image asset paired with a seed color
/// and a brightness that determines whether text should be dark (light mode)
/// or light (dark mode).
class AppBackground {
  const AppBackground({
    required this.id,
    required this.asset,
    required this.seedColor,
    required this.brightness,
    required this.displayName,
  });

  /// Stable identifier persisted in SharedPreferences.
  final String id;

  /// Asset path, e.g. `assets/images/bg/bgAIR.png`.
  final String asset;

  /// Seed color for the M3 [ColorScheme].
  final Color seedColor;

  /// When [brightness] is [Brightness.light], text is dark (black-ish).
  /// When [brightness] is [Brightness.dark], text is light (white-ish).
  final Brightness brightness;

  /// Human-readable name shown in the settings picker.
  final String displayName;

  /// Whether this background uses a light-on-dark text style.
  bool get isDark => brightness == Brightness.dark;
}

/// All available background themes.
class AppBackgrounds {
  AppBackgrounds._();

  /// Sentinel meaning "no background image" — falls back to a plain
  /// scaffold color with no wallpaper.
  static const AppBackground none = AppBackground(
    id: 'none',
    asset: '',
    seedColor: Color(0xFFf59e0b),
    brightness: Brightness.dark,
    displayName: '默认',
  );

  static const List<AppBackground> all = [
    none,
    AppBackground(
      id: 'angel',
      asset: 'assets/images/bg/bgAngel.png',
      seedColor: Color(0xFF325064),
      brightness: Brightness.dark,
      displayName: 'Angel',
    ),
    AppBackground(
      id: 'air',
      asset: 'assets/images/bg/bgAIR.png',
      seedColor: Color(0xFFB4DCFF),
      brightness: Brightness.dark,
      displayName: 'AIR',
    ),
    AppBackground(
      id: 'ever17',
      asset: 'assets/images/bg/bgEver17.png',
      seedColor: Color(0xFF6EC8D2),
      brightness: Brightness.dark,
      displayName: 'Ever17',
    ),
    AppBackground(
      id: 'fate',
      asset: 'assets/images/bg/bgFate.png',
      seedColor: Color(0xFF463232),
      brightness: Brightness.light,
      displayName: 'Fate',
    ),
    AppBackground(
      id: 'carnevale',
      asset: 'assets/images/bg/bgCarnevale.png',
      seedColor: Color(0xFF141414),
      brightness: Brightness.dark,
      displayName: 'Carnevale',
    ),
    AppBackground(
      id: 'higurashi',
      asset: 'assets/images/bg/bgHigurashi.png',
      seedColor: Color(0xFFF5B4AF),
      brightness: Brightness.dark,
      displayName: 'Higurashi',
    ),
    AppBackground(
      id: 'tsukihime',
      asset: 'assets/images/bg/bgTsukihime.png',
      seedColor: Color(0xFF645050),
      brightness: Brightness.dark,
      displayName: 'Tsukihime',
    ),
    AppBackground(
      id: 'touhou',
      asset: 'assets/images/bg/bgTouhou.png',
      seedColor: Color(0xFFAFAFAF),
      brightness: Brightness.light,
      displayName: 'Touhou',
    ),
    AppBackground(
      id: 'seinaru',
      asset: 'assets/images/bg/bgSeinaru.png',
      seedColor: Color(0xFFFFF0F0),
      brightness: Brightness.dark,
      displayName: 'Seinaru',
    ),
    AppBackground(
      id: 'littlebusters',
      asset: 'assets/images/bg/bgLittleBusters.png',
      seedColor: Color(0xFFFAC8FA),
      brightness: Brightness.dark,
      displayName: 'Little Busters',
    ),
    AppBackground(
      id: 'saya',
      asset: 'assets/images/bg/bgSaya.png',
      seedColor: Color(0xFF326450),
      brightness: Brightness.light,
      displayName: 'Saya',
    ),
  ];

  /// Look up a background by its persisted [id], falling back to [none].
  static AppBackground byId(String? id) {
    if (id == null || id.isEmpty || id == 'none') return none;
    return all.where((b) => b.id == id).firstOrNull ?? none;
  }
}
