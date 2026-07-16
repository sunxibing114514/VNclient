import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

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
    this.customPath,
  });

  /// Stable identifier persisted in SharedPreferences.
  final String id;

  /// Asset path, e.g. `assets/images/bg/angel-bg-stars.jpg`.
  /// Empty when a [customPath] (file on disk) is used instead.
  final String asset;

  /// Seed color for the M3 [ColorScheme].
  final Color seedColor;

  /// When [brightness] is [Brightness.light], text is dark (black-ish).
  /// When [brightness] is [Brightness.dark], text is light (white-ish).
  final Brightness brightness;

  /// Human-readable name shown in the settings picker.
  final String displayName;

  /// Absolute path to a user-picked background image on disk, when [id]
  /// is `custom`. Null otherwise.
  final String? customPath;

  /// Whether this background uses a light-on-dark text style.
  bool get isDark => brightness == Brightness.dark;

  /// Resolves the actual image source: a file path for custom backgrounds,
  /// otherwise the bundled asset.
  String get imageSource => customPath ?? asset;
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

  /// The single bundled background image (angel-bg-stars.jpg).
  static const AppBackground angel = AppBackground(
    id: 'angel',
    asset: 'assets/images/bg/angel-bg-stars.jpg',
    seedColor: Color(0xFF325064),
    brightness: Brightness.dark,
    displayName: 'Angel Stars',
  );

  /// All built-in background themes. Custom (user-picked) backgrounds are
  /// constructed dynamically via [custom].
  static const List<AppBackground> all = [none, angel];

  /// Constructs a custom background descriptor backed by a file on disk.
  static AppBackground custom(String path) => AppBackground(
        id: 'custom',
        asset: '',
        customPath: path,
        seedColor: const Color(0xFF325064),
        brightness: Brightness.dark,
        displayName: '自定义',
      );

  /// Look up a background by its persisted [id], falling back to [none].
  /// When [id] is `custom`, [customPath] must be supplied to resolve the
  /// descriptor.
  static AppBackground byId(String? id, {String? customPath}) {
    if (id == null || id.isEmpty || id == 'none') return none;
    if (id == 'custom') {
      if (customPath == null || customPath.isEmpty) return none;
      return custom(customPath);
    }
    return all.where((b) => b.id == id).firstOrNull ?? none;
  }

  /// Directory where user-picked custom backgrounds are copied so they
  /// persist across app restarts.
  static Future<String> customBackgroundsDir() async {
    final dir = await getApplicationDocumentsDirectory();
    final bgDir = Directory('${dir.path}/backgrounds');
    if (!bgDir.existsSync()) bgDir.createSync(recursive: true);
    return bgDir.path;
  }
}
