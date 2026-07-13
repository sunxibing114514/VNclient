import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/providers/theme_provider.dart';
import '../core/theme/app_backgrounds.dart';

/// Wraps [child] with a background wallpaper image when the user has selected
/// one, otherwise renders [child] as-is. The image is painted behind a
/// semi-transparent scrim whose opacity depends on the theme brightness,
/// ensuring text legibility.
///
/// The wallpaper is wrapped in a [RepaintBoundary] so it stays painted during
/// route transitions, preventing black/white flashes when navigating.
class ThemedBackground extends ConsumerWidget {
  const ThemedBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bg = ref.watch(themeNotifierProvider).background;

    if (bg.id == 'none') return child;

    return Stack(
      children: [
        // Background image, covering the full screen. Kept in a separate
        // repaint boundary so route transitions don't clear it.
        Positioned.fill(
          child: RepaintBoundary(
            child: Image.asset(
              bg.asset,
              fit: BoxFit.cover,
              gaplessPlayback: true,
            ),
          ),
        ),
        // Semi-transparent scrim for text legibility.
        Positioned.fill(
          child: ColoredBox(
            color: bg.isDark
                ? Colors.black.withValues(alpha: 0.35)
                : Colors.white.withValues(alpha: 0.35),
          ),
        ),
        // Foreground content.
        child,
      ],
    );
  }
}
