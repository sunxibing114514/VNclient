import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/releases/game_download_sheet.dart';

/// One prepared piece of the rendered text: either a plain chunk or a
/// link with its resolved tap recognizer.
class _SpanData {
  const _SpanData.plain(this.text)
      : link = null,
        recognizer = null;

  const _SpanData.link({
    required _NoteLink link,
    required this.recognizer,
  })  : text = null,
        link = link;

  /// Non-null for plain chunks.
  final String? text;

  /// Non-null for links.
  final _NoteLink? link;
  final GestureRecognizer? recognizer;
}

/// A link inside a note, with its range in the *rendered* text.
class _NoteLink {
  const _NoteLink({
    required this.url,
    required this.text,
    required this.start,
    required this.end,
  });

  final String url;
  final String text;

  /// Half-open range [start, end) of the link label in the rendered
  /// string, used to resolve which link a long-press landed on.
  final int start;
  final int end;
}

/// Renders VNDB BBCode text (release 备注 / VN 简介) with clickable links.
///
/// The Kana API returns notes and descriptions in BBCode, e.g. v14244's
/// release notes contain:
///
///     [url=http://www.vector.co.jp/soft/dl/win95/amuse/se452030.html]Vector[/url]
///
/// This widget parses the `[url=…]label[/url]` form, the bare
/// `[url]https://…[/url]` form and plain URLs, and renders them as tappable
/// link spans:
///
///  - **Tap**: goes through [handleGameLinkTap] — links that can be
///    resolved to a game file (freem!, NovelGame, Vector, direct archives)
///    offer the download sheet on Android; anything else opens the in-app
///    WebView.
///  - **Long-press**: copies the URL under the finger to the clipboard
///    (does nothing when the press is not on a link).
///
/// Everything else is rendered as plain text (content unchanged).
class BbcodeLinkText extends ConsumerStatefulWidget {
  const BbcodeLinkText({
    super.key,
    required this.text,
    this.style,
  });

  final String text;
  final TextStyle? style;

  @override
  ConsumerState<BbcodeLinkText> createState() => _BbcodeLinkTextState();
}

class _BbcodeLinkTextState extends ConsumerState<BbcodeLinkText> {
  /// Matches, in order (first alternative that hits wins per position):
  ///  1. `[url=https://…]label[/url]`   → group 1 = url, group 2 = label
  ///  2. `[url]https://…[/url]`         → group 3 = url (label = url)
  ///  3. bare `https://…`               → group 4 = url
  static final RegExp _linkPattern = RegExp(
    r'\[url=([^\]\s]+)\](.*?)\[/url\]'
    r'|\[url\]([^\[]+?)\[/url\]'
    // Triple-quoted raw string so both quote types can appear unescaped.
    r'''|(https?://[^\s\]\[<>"']+)''',
    caseSensitive: false,
    multiLine: true,
    dotAll: true,
  );

  final GlobalKey _textKey = GlobalKey();
  final List<GestureRecognizer> _recognizers = [];
  List<_SpanData> _spans = const [];

  @override
  void initState() {
    super.initState();
    _parse(widget.text);
  }

  @override
  void didUpdateWidget(covariant BbcodeLinkText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      for (final r in _recognizers) {
        r.dispose();
      }
      _recognizers.clear();
      _parse(widget.text);
    }
  }

  @override
  void dispose() {
    for (final r in _recognizers) {
      r.dispose();
    }
    super.dispose();
  }

  /// Parses [source] once per text change: builds the span list, the link
  /// ranges in the rendered string, and the tap recognizers.
  void _parse(String source) {
    final spans = <_SpanData>[];
    final links = <_NoteLink>[];
    var sourceCursor = 0;
    var renderedLength = 0;

    void addPlain(String chunk) {
      if (chunk.isEmpty) return;
      spans.add(_SpanData.plain(chunk));
      renderedLength += chunk.length;
    }

    for (final match in _linkPattern.allMatches(source)) {
      addPlain(source.substring(sourceCursor, match.start));
      final url = match.group(1) ?? match.group(3) ?? match.group(4) ?? '';
      final label = match.group(2) ?? match.group(3) ?? match.group(4) ?? url;
      if (url.isEmpty) {
        // Defensive: cannot happen given the pattern, but never lose text.
        addPlain(match.group(0)!);
      } else {
        final link = _NoteLink(
          url: url,
          text: label,
          start: renderedLength,
          end: renderedLength + label.length,
        );
        links.add(link);
        final recognizer = TapGestureRecognizer()
          ..onTap = () {
            if (mounted) {
              handleGameLinkTap(context, ref, link.url, label: link.text);
            }
          };
        _recognizers.add(recognizer);
        spans.add(_SpanData.link(link: link, recognizer: recognizer));
        renderedLength += label.length;
      }
      sourceCursor = match.end;
    }
    addPlain(source.substring(sourceCursor));

    _spans = spans;
    _links = links;
  }

  List<_NoteLink> _links = const [];

  /// Resolves the link under [localPosition] inside the rendered paragraph
  /// and copies it. Positions snap to the nearest character, which is
  /// good enough for a long-press target.
  void _copyLinkAt(Offset localPosition) {
    final renderObject = _textKey.currentContext?.findRenderObject();
    if (renderObject is! RenderParagraph) return;
    final position = renderObject.getPositionForOffset(localPosition);
    for (final link in _links) {
      if (position.offset >= link.start && position.offset < link.end) {
        copyLinkToClipboard(context, link.url);
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // TextTheme fields are nullable in current Flutter; make sure the base
    // style is never null so copyWith is safe.
    final baseStyle = widget.style ??
        Theme.of(context).textTheme.bodyMedium ??
        const TextStyle();
    final linkColor = Theme.of(context).colorScheme.primary;

    final children = _spans.map((span) {
      if (span.link != null) {
        return TextSpan(
          text: span.link!.text,
          recognizer: span.recognizer,
          style: baseStyle.copyWith(
            color: linkColor,
            decoration: TextDecoration.underline,
            decorationColor: linkColor,
          ),
        );
      }
      return TextSpan(text: span.text, style: baseStyle);
    }).toList();

    // The outer GestureDetector participates in the gesture arena together
    // with the per-span TapRecognizers: quick taps are won by the span
    // recognizer (tap deadline ~100ms), held presses (~500ms) are won here —
    // so both gestures work on the same link.
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onLongPressStart: (details) => _copyLinkAt(details.localPosition),
      child: Text.rich(
        TextSpan(children: children),
        key: _textKey,
      ),
    );
  }
}
