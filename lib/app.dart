import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/providers/auth_provider.dart';
import 'core/providers/locale_provider.dart';
import 'core/providers/theme_provider.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_backgrounds.dart';
import 'core/theme/app_theme.dart';
import 'widgets/themed_background.dart';

/// The root widget of the application.
class VndbApp extends ConsumerWidget {
  const VndbApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final auth = ref.watch(authNotifierProvider);
    final theme = ref.watch(themeNotifierProvider);
    final locale = ref.watch(localeNotifierProvider);

    final hasBg = theme.backgroundId != 'none';
    final bg = theme.background;
    final darkTheme = hasBg
        ? AppTheme.forBackground(bg)
        : AppTheme.dark(seedColor: theme.effectiveSeedColor);
    final lightTheme = hasBg
        ? AppTheme.forBackground(bg)
        : AppTheme.light(seedColor: theme.effectiveSeedColor);
    // When a background is active, force the theme mode to match the
    // background's brightness so text colors are correct.
    final effectiveMode = hasBg
        ? (bg.isDark ? ThemeMode.dark : ThemeMode.light)
        : theme.mode;

    // While the persisted token is being validated, show a splash.
    if (auth.status == AuthStatus.unknown ||
        auth.status == AuthStatus.loading) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: darkTheme,
        darkTheme: darkTheme,
        themeMode: effectiveMode,
        locale: locale,
        supportedLocales: supportedLocales,
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        builder: (context, child) {
          return ThemedBackground(child: child ?? const SizedBox.shrink());
        },
        home: const Scaffold(
          backgroundColor: Colors.transparent,
          body: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'VNDB Client',
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: effectiveMode,
      locale: locale,
      supportedLocales: supportedLocales,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: router,
      builder: (context, child) {
        return ThemedBackground(child: child ?? const SizedBox.shrink());
      },
    );
  }
}
