import 'package:flutter/material.dart';

import 'app_backgrounds.dart';

/// Application theme definitions.
///
/// Uses Material 3 with a configurable seed color. Defaults to the VNDB
/// website accent orange (`#f59e0b`).
class AppTheme {
  AppTheme._();

  /// Default seed color mirroring the VNDB website accent.
  static const Color defaultSeed = Color(0xFFf59e0b);

  /// Legacy fixed accent, kept for widgets that reference [AppTheme.accent].
  static const Color accent = defaultSeed;
  static const Color cardBackground = Color(0xFF16213e);
  static const Color background = Color(0xFF1a1a2e);
  static const Color textMuted = Color(0xFF94a3b8);

  /// Builds a dark theme from [seedColor] using M3 [ColorScheme.fromSeed].
  static ThemeData dark({Color? seedColor}) {
    final seed = seedColor ?? defaultSeed;
    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: Brightness.dark,
    );
    return _base(scheme, brightness: Brightness.dark);
  }

  /// Builds a light theme from [seedColor] using M3 [ColorScheme.fromSeed].
  static ThemeData light({Color? seedColor}) {
    final seed = seedColor ?? defaultSeed;
    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: Brightness.light,
    );
    return _base(scheme, brightness: Brightness.light);
  }

  /// Builds a theme tuned for a background wallpaper: transparent scaffold,
  /// semi-transparent cards/app bars, and text colors derived from the
  /// background's [brightness].
  static ThemeData forBackground(AppBackground bg) {
    final scheme = ColorScheme.fromSeed(
      seedColor: bg.seedColor,
      brightness: bg.brightness,
    );
    return _base(
      scheme,
      brightness: bg.brightness,
      hasBackground: true,
    );
  }

  static ThemeData _base(
    ColorScheme scheme, {
    required Brightness brightness,
    bool hasBackground = false,
  }) {
    final isDark = brightness == Brightness.dark;

    // Semi-transparent surface colors when a background wallpaper is active.
    final cardColor = hasBackground
        ? (isDark ? Colors.white.withValues(alpha: 0.12) : Colors.black.withValues(alpha: 0.06))
        : scheme.surfaceContainerHighest;
    final surfaceColor = hasBackground ? Colors.transparent : scheme.surface;
    final appbarBg = hasBackground
        ? (isDark ? Colors.black.withValues(alpha: 0.35) : Colors.white.withValues(alpha: 0.35))
        : scheme.surface;
    final navBarBg = hasBackground
        ? (isDark ? Colors.black.withValues(alpha: 0.4) : Colors.white.withValues(alpha: 0.4))
        : scheme.surface;
    final inputFill = hasBackground
        ? (isDark ? Colors.white.withValues(alpha: 0.10) : Colors.black.withValues(alpha: 0.05))
        : scheme.surfaceContainerHighest;
    final chipBg = hasBackground
        ? (isDark ? Colors.white.withValues(alpha: 0.15) : Colors.black.withValues(alpha: 0.08))
        : scheme.secondaryContainer;

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: surfaceColor,
      canvasColor: surfaceColor,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      appBarTheme: AppBarTheme(
        backgroundColor: appbarBg,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        centerTitle: false,
        scrolledUnderElevation: 0,
      ),
      cardTheme: CardThemeData(
        color: cardColor,
        elevation: hasBackground ? 0 : 1,
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: chipBg,
        labelStyle: TextStyle(color: scheme.onSecondaryContainer),
        selectedColor: scheme.primary,
        side: BorderSide.none,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      listTileTheme: ListTileThemeData(
        textColor: scheme.onSurface,
        iconColor: scheme.primary,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: inputFill,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: scheme.primary),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: navBarBg,
        indicatorColor: scheme.primaryContainer,
        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(color: scheme.onSurface),
        ),
        iconTheme: WidgetStateProperty.resolveWith<IconThemeData?>((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(color: scheme.onPrimaryContainer);
          }
          return IconThemeData(color: scheme.onSurfaceVariant);
        }),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: navBarBg,
        selectedItemColor: scheme.primary,
        unselectedItemColor: scheme.onSurfaceVariant,
        type: BottomNavigationBarType.fixed,
      ),
      dividerColor: scheme.outlineVariant,
      textTheme: TextTheme(
        titleLarge: TextStyle(
          color: scheme.onSurface,
          fontWeight: FontWeight.w600,
        ),
        titleMedium: TextStyle(color: scheme.onSurface),
        bodyMedium: TextStyle(color: scheme.onSurface),
        bodySmall: TextStyle(color: scheme.onSurfaceVariant),
      ),
    );
  }
}
