import '../models/vn.dart';
import '../providers/theme_provider.dart';

/// Resolves which title string to display for a VN based on the user's
/// [TitleDisplayMode] preference.
///
/// - [TitleDisplayMode.romanized]: the API `title` field (romanized/main).
/// - [TitleDisplayMode.japanese]: the API `alttitle` field (original script),
///   falling back to `title` when no alttitle is available.
class TitleResolver {
  const TitleResolver._();

  /// Resolves the display title for a [Vn] given the user's preference.
  static String resolve(Vn vn, TitleDisplayMode mode) {
    switch (mode) {
      case TitleDisplayMode.romanized:
        return vn.title;
      case TitleDisplayMode.japanese:
        if (vn.alttitle != null && vn.alttitle!.isNotEmpty) {
          return vn.alttitle!;
        }
        // Fall back to the main title's original-script form from the titles
        // array when alttitle is not present (e.g. list fields).
        for (final t in vn.titles) {
          if (t.main) return t.title;
        }
        return vn.title;
    }
  }

  /// Resolves the "secondary" title (the one not chosen as primary) so it can
  /// be shown as a subtitle. Returns null when there's nothing to show.
  static String? secondary(Vn vn, TitleDisplayMode mode) {
    switch (mode) {
      case TitleDisplayMode.romanized:
        if (vn.alttitle != null && vn.alttitle!.isNotEmpty) {
          return vn.alttitle;
        }
        return null;
      case TitleDisplayMode.japanese:
        return vn.title;
    }
  }

  /// Convenience for list views that only have `title` and `alttitle`.
  static String resolveSimple(
    String title,
    String? alttitle,
    TitleDisplayMode mode,
  ) {
    switch (mode) {
      case TitleDisplayMode.romanized:
        return title;
      case TitleDisplayMode.japanese:
        return (alttitle != null && alttitle.isNotEmpty) ? alttitle : title;
    }
  }
}
