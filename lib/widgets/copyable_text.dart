import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/providers/theme_provider.dart';

/// A [Text] that supports two display conveniences:
///
///  - **Long-press to copy**: long-pressing the text copies it to the
///    clipboard and shows a snackbar confirmation.
///  - **Optional v-number suffix**: when the "在标题后显示 v 编号" setting is
///    enabled and an [vnId] is provided, the id is appended to the displayed
///    text as `title (v17)`. The plain title (without the suffix) is copied
///    to the clipboard.
///
/// Use this for VN titles / character & staff names everywhere so the
/// interactions stay consistent across the app.
class CopyableText extends ConsumerWidget {
  const CopyableText({
    super.key,
    required this.text,
    this.vnId,
    this.style,
    this.maxLines,
    this.overflow,
    this.textAlign,
    this.softWrap = true,
    this.copyHint = '已复制到剪贴板',
  });

  /// The already-resolved display text (title / name).
  final String text;

  /// Optional database id (e.g. `v17`). When non-null and the show-id
  /// setting is on, `' ($vnId)'` is appended to the displayed text.
  final String? vnId;

  final TextStyle? style;
  final int? maxLines;
  final TextOverflow? overflow;
  final TextAlign? textAlign;
  final bool softWrap;

  /// Snackbar text shown after copying.
  final String copyHint;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final showId = vnId != null &&
        ref.watch(themeNotifierProvider.select((s) => s.showVnId));
    final display = showId ? '$text ($vnId)' : text;

    void copy() {
      Clipboard.setData(ClipboardData(text: text));
      final messenger = ScaffoldMessenger.maybeOf(context);
      messenger?.showSnackBar(
        SnackBar(
          content: Text(copyHint),
          duration: const Duration(seconds: 2),
        ),
      );
    }

    return GestureDetector(
      onLongPress: text.isEmpty ? null : copy,
      child: Text(
        display,
        style: style,
        maxLines: maxLines,
        overflow: overflow,
        textAlign: textAlign,
        softWrap: softWrap,
      ),
    );
  }
}
