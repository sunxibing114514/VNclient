import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A freem! (freem.ne.jp) game reference parsed from a VNDB extlink.
class FreemGameRef {
  const FreemGameRef({required this.section, required this.id});

  /// URL section of the game page: `win` (PC) or `sp` (smartphone).
  final String section;

  /// Numeric game id, e.g. `585`.
  final String id;

  /// The game page, e.g. `https://www.freem.ne.jp/win/game/585`.
  String get gameUrl => 'https://www.freem.ne.jp/$section/game/$id';

  /// The download landing page, e.g. `https://www.freem.ne.jp/dl/win/585`.
  String get landingUrl => 'https://www.freem.ne.jp/dl/$section/$id';
}

/// Result of a completed freem! game download.
class FreemDownloadResult {
  const FreemDownloadResult({required this.file, required this.filename});

  /// The downloaded archive (still in a temporary location; the caller
  /// moves it to its final destination).
  final File file;

  /// Suggested file name derived from the download URL.
  final String filename;
}

/// Downloads free games hosted on freem! (freem.ne.jp).
///
/// VNDB release extlinks can point at a freem! game page, e.g.
/// `https://www.freem.ne.jp/win/game/585` (extlink name `freem`, label
/// `Freem!`). freem! only hosts freeware games, so downloading through the
/// client is equivalent to pressing the site's own download button:
///
///  1. `GET /dl/{section}/{id}` — the download landing page. Its HTML embeds
///     a fresh, session-bound href of the form `/dl/download/{s}/{id}/{hash}`
///     and the response sets a `freem_tid` cookie.
///  2. `GET /dl/download/{s}/{id}/{hash}` with that cookie + referer —
///     replies `302` to the actual archive on `dl.fgamearchives.com`
///     (or serves the file directly).
///
/// The hash is regenerated on every landing-page visit, so it must be
/// resolved fresh for each download — it cannot be cached.
class FreemDownloadService {
  FreemDownloadService()
      : _dio = Dio(
          BaseOptions(
            baseUrl: 'https://www.freem.ne.jp',
            connectTimeout: const Duration(seconds: 20),
            receiveTimeout: const Duration(minutes: 10),
            headers: {
              'User-Agent':
                  'Mozilla/5.0 (Linux; Android 13; Pixel 7) '
                  'AppleWebKit/537.36 (KHTML, like Gecko) '
                  'Chrome/131.0.0.0 Mobile Safari/537.36',
              'Accept': 'text/html,application/xhtml+xml,*/*;q=0.8',
              'Accept-Language': 'ja,en;q=0.8',
            },
            // 3xx responses are handled manually to capture the redirect.
            validateStatus: (code) => code != null && code < 400,
          ),
        );

  final Dio _dio;

  static final RegExp _gamePagePattern = RegExp(
    r'^https?://(?:www\.|m\.)?freem\.ne\.jp/(win|sp)/game/(\d+)/?$',
    caseSensitive: false,
  );

  /// Matches the session-bound download href embedded in the landing page.
  static final RegExp _downloadHrefPattern = RegExp(
    r'''href=["'](/dl/download/(?:win|sp)/\d+/[0-9a-fA-F]+)["']''',
  );

  /// True when [url] (or an extlink with [name]) points to a freem! game.
  static bool isFreemUrl(String url, {String? name}) {
    if (name != null && name.toLowerCase() == 'freem') return true;
    final clean = url.trim();
    if (clean.isEmpty) return false;
    return _gamePagePattern.hasMatch(clean);
  }

  /// Parses a freem! game URL into its section + id, or null.
  static FreemGameRef? parseFreemUrl(String url) {
    final match = _gamePagePattern.firstMatch(url.trim());
    if (match == null) return null;
    return FreemGameRef(section: match.group(1)!, id: match.group(2)!);
  }

  /// Downloads the archive for [game] into [savePath] (a temporary file the
  /// caller chooses) and returns it together with a suggested file name.
  ///
  /// [onStatus] receives short human-readable phase updates ("正在解析下载
  /// 链接…"), [onProgress] receives (receivedBytes, totalBytes) of the
  /// actual file transfer, and [cancelToken] cancels the transfer.
  Future<FreemDownloadResult> downloadGame(
    FreemGameRef game,
    String savePath, {
    void Function(String message)? onStatus,
    void Function(int received, int total)? onProgress,
    CancelToken? cancelToken,
  }) async {
    onStatus?.call('正在解析 Freem! 下载链接…');

    // 1. Landing page → session-bound href + session cookie.
    final String html;
    final String cookieHeader;
    try {
      final response = await _dio.get<String>(
        '/dl/${game.section}/${game.id}',
        options: Options(responseType: ResponseType.plain),
        cancelToken: cancelToken,
      );
      html = response.data ?? '';
      cookieHeader = _cookiesFrom(response);
    } on DioException catch (e) {
      // Cancelling is surfaced as a plain cancel so the caller can tell
      // it apart from real failures.
      if (CancelToken.isCancel(e)) rethrow;
      throw FreemDownloadException(
        e.response?.statusCode == 404
            ? 'Freem! 上未找到该游戏的下载页 (${game.id})'
            : '无法访问 Freem! 下载页: ${e.message ?? e.type.name}',
      );
    }

    final hrefMatch = _downloadHrefPattern.firstMatch(html);
    if (hrefMatch == null) {
      throw FreemDownloadException('该游戏在 Freem! 上暂不提供直接下载');
    }
    final href = 'https://www.freem.ne.jp${hrefMatch.group(1)}';
    final referer = game.landingUrl;

    // 2. Download from the session-bound href with redirects disabled so
    //    the (small) redirect hop can be captured. When the server answers
    //    30x, its tiny HTML body is written to savePath first and then
    //    overwritten by the real transfer in step 3.
    final extraHeaders = <String, String>{
      'Referer': referer,
      if (cookieHeader.isNotEmpty) 'Cookie': cookieHeader,
    };

    Response first;
    try {
      first = await _dio.download(
        href,
        savePath,
        options: Options(headers: extraHeaders, followRedirects: false),
        cancelToken: cancelToken,
      );
    } on DioException catch (e) {
      if (CancelToken.isCancel(e)) rethrow;
      throw FreemDownloadException(
        'Freem! 拒绝了下载请求: ${e.response?.statusCode ?? e.message ?? e.type.name}',
      );
    }

    final location = first.headers.value('location');
    final code = first.statusCode ?? 0;
    if (code >= 300 && code < 400 && location != null && location.isNotEmpty) {
      // 3. Real transfer from the redirected archive URL.
      final fileUrl = location.startsWith('http')
          ? location
          : 'https://www.freem.ne.jp$location';
      final filename = fileNameFromUrl(fileUrl, game);
      onStatus?.call('正在下载 $filename…');
      try {
        await _dio.download(
          fileUrl,
          savePath,
          options: Options(headers: {'Referer': 'https://www.freem.ne.jp/'}),
          onReceiveProgress: onProgress,
          cancelToken: cancelToken,
        );
      } on DioException catch (e) {
        if (CancelToken.isCancel(e)) rethrow;
        throw FreemDownloadException(
          '下载失败: ${e.response?.statusCode ?? e.message ?? e.type.name}',
        );
      }
      return FreemDownloadResult(file: File(savePath), filename: filename);
    }

    // No redirect: the href served the archive directly.
    final disposition = first.headers.value('content-disposition') ?? '';
    final inlineName = RegExp(
      r'filename\s*=\s*"?([^";]+)"?',
    ).firstMatch(disposition)?.group(1);
    final filename = (inlineName != null && inlineName.trim().isNotEmpty)
        ? sanitizeFileName(inlineName)
        : fileNameFromUrl(href, game);
    return FreemDownloadResult(file: File(savePath), filename: filename);
  }

  /// Collects Set-Cookie headers into a single Cookie header value so the
  /// download request shares the session that generated the href hash.
  static String _cookiesFrom(Response response) {
    final cookies = <String>[];
    for (final entry in response.headers.map.entries) {
      if (entry.key.toLowerCase() == 'set-cookie') {
        for (final raw in entry.value) {
          final nameValue = raw.split(';').first.trim();
          if (nameValue.isNotEmpty && !cookies.contains(nameValue)) {
            cookies.add(nameValue);
          }
        }
      }
    }
    return cookies.join('; ');
  }

  /// Derives a file name from a URL path, falling back to a freem-styled
  /// generic name.
  static String fileNameFromUrl(String url, FreemGameRef game) {
    final path = Uri.tryParse(url)?.path ?? '';
    final segments = path.split('/').where((s) => s.isNotEmpty).toList();
    final last = segments.isEmpty ? null : segments.last;
    if (last != null && last.contains('.') && last.length <= 120) {
      return sanitizeFileName(last);
    }
    return 'freem-${game.section}-${game.id}.zip';
  }

  static String sanitizeFileName(String name) {
    final cleaned = name
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
        .replaceAll(RegExp(r'\s+'), '_')
        .trim();
    return cleaned.isEmpty ? 'freem_game.zip' : cleaned;
  }

  /// Releases the underlying HTTP resources.
  void dispose() => _dio.close(force: true);
}

class FreemDownloadException implements Exception {
  FreemDownloadException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Provider for [FreemDownloadService].
final freemDownloadServiceProvider = Provider<FreemDownloadService>((ref) {
  final service = FreemDownloadService();
  ref.onDispose(() => service.dispose());
  return service;
});
