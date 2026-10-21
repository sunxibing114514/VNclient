import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'freem_download_service.dart';

/// A link source that can be resolved into a direct game-file download.
enum GameDownloadSource {
  /// freem! (freem.ne.jp) freeware hosting, handled by
  /// [FreemDownloadService].
  freem,

  /// NovelGame (novelgame.jp) freeware hosting.
  novelgame,

  /// Vector (vector.co.jp) freeware archive. Appears mostly inside release
  /// 备注 (notes), e.g. the link of v14244's release notes.
  vector,

  /// An Internet Archive item page (archive.org/details/{id}): files are
  /// listed by the metadata API and served from archive.org/download, e.g.
  /// the "Archived download" link of v28439's English release.
  archiveOrg,

  /// A Wayback Machine snapshot (web.archive.org/web/{ts}/{url}) of a
  /// dead site's game file; the `id_` suffix makes the Wayback serve the
  /// original unmodified bytes. Page snapshots are not resolvable to a
  /// file and open in the browser instead.
  wayback,

  /// itch.io game pages with free direct downloads. The page exposes
  /// upload ids; `POST /file/{upload_id}` answers a short-lived signed
  /// CDN URL. Pages behind a price/registration wall or blocked by an
  /// administrator cannot be resolved.
  itch,

  booth,

  /// A plain direct archive URL (…/game.zip etc.), commonly linked from
  /// official websites and notes.
  directFile,
}

/// Result of a completed game download.
class GameDownloadResult {
  const GameDownloadResult({required this.file, required this.filename});

  /// The downloaded archive (still in a temporary location; the caller
  /// moves it to its final destination).
  final File file;

  /// Suggested file name derived from the resolved download URL.
  final String filename;
}

/// Thrown when a download cannot be resolved or transferred.
class GameDownloadException implements Exception {
  GameDownloadException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Resolves and downloads free/freeware games from sites that VNDB release
/// extlinks and 备注 (notes) commonly link to.
///
/// Supported sources:
///
///  - **freem!** (`https://www.freem.ne.jp/(win|sp)/game/{id}`) — delegated
///    to [FreemDownloadService] (session-bound landing-page flow).
///  - **NovelGame** (`https://novelgame.jp/games/show/{id}`) — the game
///    page's per-platform download page
///    (`/games/download/win|mac/{id}`) embeds a direct file link on
///    `https://{id}.svNN.novelgame.jp/game/{id}/…`. Verified against the
///    live site; no referer or cookies are required for the file itself.
///  - **Vector** (`https://www.vector.co.jp/soft/dl/…`) — the soft page
///    links to a `/download/file/…` page which in turn links the archive
///    on `https://ftp.vector.co.jp/…` (e.g. Ame no Koe, v14244).
///  - **Internet Archive** (`https://archive.org/details/{id}`) — the
///    item's files are listed by `archive.org/metadata/{id}` and the best
///    game file is downloaded from `archive.org/download/{id}/…`
///    (e.g. the "Archived download" link of v28439's English release).
///  - **Wayback Machine** (`https://web.archive.org/web/{ts}/{url}`) —
///    snapshots of dead official sites whose original URL is itself a game
///    file (the dead site's zip); the `{ts}id_/{url}` form serves the
///    original unmodified bytes. Page snapshots are not guaranteed to
///    resolve to a file, so they open in the browser instead.
///  - **itch.io** (`https://{user}.itch.io/{slug}`) — free direct-download
///    games: the page exposes upload ids and `POST /file/{upload_id}`
///    answers a short-lived signed CDN URL. Price-gated, registration
///    walled or blocked pages cannot be resolved.
///  - **Direct file URLs** — any http(s) URL whose path ends in a game
///    archive/executable extension (.zip/.rar/.7z/.lzh/.exe/…).
///
/// Commercial stores (DLsite, Steam, Getchu, …) are intentionally not
/// supported — those need accounts/payment and are opened in the browser
/// instead.
class GameDownloadService {
  GameDownloadService()
      : _dio = Dio(
          BaseOptions(
            connectTimeout: const Duration(seconds: 20),
            receiveTimeout: const Duration(minutes: 10),
            headers: {
              'User-Agent':
                  'Mozilla/5.0 (Linux; Android 13; Pixel 7) '
                  'AppleWebKit/537.36 (KHTML, like Gecko) '
                  'Chrome/131.0.0.0 Mobile Safari/537.36',
              'Accept':
                  'text/html,application/xhtml+xml,application/zip,*/*;q=0.8',
              'Accept-Language': 'ja,en;q=0.8',
            },
            // 3xx on manual resolution steps is handled per-request; the
            // plain transfers let dio follow redirects.
            validateStatus: (code) => code != null && code < 400,
          ),
        );

  /// Desktop-browser UA used when fetching HTML pages to parse.
  ///
  /// Some sites (vector.co.jp) serve a stripped mobile page to phone UAs
  /// that omits the download links, so page resolution must identify as a
  /// desktop browser. The actual file transfer keeps the default UA.
  static const String _desktopUserAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
      'AppleWebKit/537.36 (KHTML, like Gecko) '
      'Chrome/131.0.0.0 Safari/537.36';

  /// Upgrades `http://` to `https://`.
  ///
  /// Android blocks cleartext HTTP (`usesCleartextTraffic="false"`), so an
  /// `http://` source page (vector.co.jp links are often http) would fail
  /// with a socket error before any request is made. All supported hosts
  /// also serve https.
  static String _httpsUrl(String url) => url.startsWith('http://')
      ? 'https://${url.substring(7)}'
      : url;

  final Dio _dio;

  /// `https://novelgame.jp/games/show/2434`
  static final RegExp _novelgameGamePage = RegExp(
    r'^https?://(?:www\.|m\.)?novelgame\.jp/games/show/(\d+)/?$',
    caseSensitive: false,
  );

  /// Direct file link embedded in a NovelGame download page, e.g.
  /// `https://2434.sv02.novelgame.jp/game/2434/KawaiiBukkoro_win.zip?v=0`.
  static final RegExp _novelgameDirectLink = RegExp(
    r'''https://[a-z0-9.-]*novelgame\.jp/game/\d+/[^\s"'<>]+''',
    caseSensitive: false,
  );

  /// Vector "software" page, e.g.
  /// `http://www.vector.co.jp/soft/dl/win95/amuse/se452030.html`.
  static final RegExp _vectorSoftPage = RegExp(
    r'^https?://(?:www\.)?vector\.co\.jp/soft/dl/.+\.html?$',
    caseSensitive: false,
  );

  /// Vector "file" page, e.g.
  /// `https://www.vector.co.jp/download/file/win95/amuse/fh511479.html`.
  static final RegExp _vectorFilePage = RegExp(
    r'^https?://(?:www\.)?vector\.co\.jp/download/file/.+\.html?$',
    caseSensitive: false,
  );

  /// The href of the file page embedded in a Vector soft page.
  static final RegExp _vectorFileHref = RegExp(
    r'''href=["'](/download/file/[^"']+?\.html)["']''',
    caseSensitive: false,
  );

  /// Direct archive link on `ftp.vector.co.jp` embedded in the file page.
  static final RegExp _vectorDirectLink = RegExp(
    r'''https?://ftp\.vector\.co\.jp/[^\s"'<>]+''',
    caseSensitive: false,
  );

  /// Internet Archive item page, e.g. `https://archive.org/details/watashi-kawaii`.
  static final RegExp _archiveOrgItem = RegExp(
    r'^https?://(?:www\.)?archive\.org/details/([a-zA-Z0-9._\-]+)/?$',
    caseSensitive: false,
  );

  /// Wayback Machine snapshot, e.g.
  /// `https://web.archive.org/web/20140405070955id_/http://…` — captures
  /// the (optional) timestamp plus modifier and the original URL.
  static final RegExp _waybackUrl = RegExp(
    r'^https?://(?:www\.)?web\.archive\.org/web/(?:([0-9*]+)[a-z_]*/)?(.+)$',
    caseSensitive: false,
  );

  /// itch.io game page, e.g. `https://teatime.itch.io/cute`.
  static final RegExp _itchGamePage = RegExp(
    r'^https?://([a-z0-9\-]+)\.itch\.io/([a-z0-9\-]+)/?$',
    caseSensitive: false,
  );

  /// itch.io upload button: exposes the upload id; the file name follows in
  /// the same upload block (`<strong title="…zip" class="name">`).
  static final RegExp _itchUpload = RegExp(
    r'data-upload_id="(\d+)"[\s\S]{0,600}?title="([^"]+)"',
    caseSensitive: false,
  );

  static final RegExp _boothItem = RegExp(
    r'^https?://(?:[a-z0-9-]+\.)*booth\.pm/(?:(?:ja|en|zh-cn|zh-tw|ko)/)?items/(\d+)(?:[/?#].*)?$',
    caseSensitive: false,
  );

  static final RegExp _boothDownloadable = RegExp(
    r'<a\s[^>]*\bhref="(https://booth\.pm/downloadables/[^"]+)"[^>]*>',
    caseSensitive: false,
  );

  static final RegExp _boothAgeForm = RegExp(
    r'<form[^>]*action="([^"]*age_check[^"]*)"[^>]*>([\s\S]*?)</form>',
    caseSensitive: false,
  );

  static final RegExp _hiddenInput = RegExp(
    r'<input[^>]*type="hidden"[^>]*>',
    caseSensitive: false,
  );

  static final RegExp _titleAttr = RegExp(
    r'title="([^"]+)"',
    caseSensitive: false,
  );

  /// Archive / executable extensions treated as direct game files.
  static final RegExp _archiveExt = RegExp(
    r'\.(zip|rar|7z|lzh|lha|exe|sit|sitx|apk)$',
    caseSensitive: false,
  );

  /// Classifies [url] (optionally an extlink with [name]) into a
  /// downloadable source, or null when the link cannot be resolved to a
  /// game file (in which case the caller should just open it in a browser).
  static GameDownloadSource? detectSource(String url, {String? name}) {
    final clean = url.trim();
    if (clean.isEmpty) return null;
    if (FreemDownloadService.isFreemUrl(clean, name: name)) {
      return GameDownloadSource.freem;
    }
    if (_novelgameGamePage.hasMatch(clean)) return GameDownloadSource.novelgame;
    if (_vectorSoftPage.hasMatch(clean) ||
        _vectorFilePage.hasMatch(clean)) {
      return GameDownloadSource.vector;
    }
    if (_archiveOrgItem.hasMatch(clean)) return GameDownloadSource.archiveOrg;
    // Wayback — but only snapshots whose original URL is itself a game
    // file (e.g. a dead site's zip). Page snapshots (promo pages, store
    // listings, …) are not guaranteed to resolve to a file, so they are
    // opened in the browser instead of promising a download.
    // Checked before directFile: the snapshot URL's path ends in ".zip"
    // and would otherwise be mistaken for a plain direct link.
    final waybackMatch = _waybackUrl.firstMatch(clean);
    if (waybackMatch != null &&
        isDirectFileUrl(waybackMatch.group(2) ?? '')) {
      return GameDownloadSource.wayback;
    }
    if (_itchGamePage.hasMatch(clean)) return GameDownloadSource.itch;
    if (_boothItem.hasMatch(clean)) return GameDownloadSource.booth;
    if (isDirectFileUrl(clean)) return GameDownloadSource.directFile;
    return null;
  }

  /// True when the URL's path ends in a known archive/executable
  /// extension, ignoring any query string.
  static bool isDirectFileUrl(String url) {
    final path = Uri.tryParse(url.trim())?.path ?? '';
    if (path.isEmpty) return false;
    return _archiveExt.hasMatch(path);
  }

  /// Human-readable site name for sheets and subtitles.
  static String sourceLabel(GameDownloadSource source) {
    switch (source) {
      case GameDownloadSource.freem:
        return 'Freem!';
      case GameDownloadSource.novelgame:
        return 'NovelGame';
      case GameDownloadSource.vector:
        return 'Vector';
      case GameDownloadSource.archiveOrg:
        return 'Internet Archive';
      case GameDownloadSource.wayback:
        return 'Wayback Machine';
      case GameDownloadSource.itch:
        return 'itch.io';
      case GameDownloadSource.booth:
        return 'BOOTH';
      case GameDownloadSource.directFile:
        return '直链文件';
    }
  }

  /// Downloads the game behind [url] into [savePath] (a temporary file the
  /// caller chooses) and returns it together with a suggested file name.
  ///
  /// [onStatus] receives short human-readable phase updates, [onProgress]
  /// receives (receivedBytes, totalBytes) of the actual file transfer, and
  /// [cancelToken] cancels the transfer.
  Future<GameDownloadResult> download(
    String url,
    String savePath, {
    void Function(String message)? onStatus,
    void Function(int received, int total)? onProgress,
    CancelToken? cancelToken,
    String? cookieHeader,
  }) async {
    // http:// is upgraded to https:// — see [_httpsUrl].
    final target = _httpsUrl(url.trim());
    final source = detectSource(target);
    switch (source) {
      case GameDownloadSource.freem:
        final ref = FreemDownloadService.parseFreemUrl(target);
        if (ref == null) {
          throw GameDownloadException('无法解析 Freem! 游戏链接');
        }
        // The freem flow keeps its own tuned client (manual redirect
        // handling, session cookies); delegate and translate the result.
        final freem = FreemDownloadService();
        try {
          final result = await freem.downloadGame(
            ref,
            savePath,
            onStatus: onStatus,
            onProgress: onProgress,
            cancelToken: cancelToken,
          );
          return GameDownloadResult(
            file: result.file,
            filename: result.filename,
          );
        } finally {
          freem.dispose();
        }

      case GameDownloadSource.novelgame:
        return _downloadNovelgame(
          target,
          savePath,
          onStatus: onStatus,
          onProgress: onProgress,
          cancelToken: cancelToken,
        );

      case GameDownloadSource.vector:
        return _downloadVector(
          target,
          savePath,
          onStatus: onStatus,
          onProgress: onProgress,
          cancelToken: cancelToken,
        );

      case GameDownloadSource.archiveOrg:
        return _downloadArchiveOrg(
          target,
          savePath,
          onStatus: onStatus,
          onProgress: onProgress,
          cancelToken: cancelToken,
        );

      case GameDownloadSource.wayback:
        return _downloadWayback(
          target,
          savePath,
          onStatus: onStatus,
          onProgress: onProgress,
          cancelToken: cancelToken,
        );

      case GameDownloadSource.itch:
        return _downloadItch(
          target,
          savePath,
          onStatus: onStatus,
          onProgress: onProgress,
          cancelToken: cancelToken,
        );

      case GameDownloadSource.booth:
        return _downloadBooth(
          target,
          savePath,
          cookieHeader: cookieHeader,
          onStatus: onStatus,
          onProgress: onProgress,
          cancelToken: cancelToken,
        );

      case GameDownloadSource.directFile:
        return _downloadDirect(
          target,
          savePath,
          onStatus: onStatus,
          onProgress: onProgress,
          cancelToken: cancelToken,
        );

      case null:
        throw GameDownloadException('该链接暂不支持直接下载');
    }
  }

  /// NovelGame: `/games/download/win|mac/{id}` embeds a direct file link
  /// on `https://{id}.svNN.novelgame.jp/game/{id}/…`.
  Future<GameDownloadResult> _downloadNovelgame(
    String gameUrl,
    String savePath, {
    void Function(String message)? onStatus,
    void Function(int received, int total)? onProgress,
    CancelToken? cancelToken,
  }) async {
    final id = _novelgameGamePage.firstMatch(gameUrl)?.group(1);
    if (id == null) {
      throw GameDownloadException('无法解析 NovelGame 游戏链接');
    }
    onStatus?.call('正在解析 NovelGame 下载链接…');

    String? fileUrl;
    // The win build is preferred; some games only ship a mac build. The
    // browser build is a web version and is not offered for download.
    for (final platform in ['win', 'mac']) {
      final html = await _fetchHtml(
        'https://novelgame.jp/games/download/$platform/$id',
        cancelToken: cancelToken,
      );
      final match = _novelgameDirectLink.firstMatch(html);
      if (match != null) {
        fileUrl = match.group(0)!;
        break;
      }
    }
    if (fileUrl == null) {
      throw GameDownloadException(
        '该游戏在 NovelGame 上暂不提供直接下载 (可能仅提供浏览器版或需要登录)',
      );
    }

    final filename = fileNameFromUrl(fileUrl, 'novelgame-$id.zip');
    onStatus?.call('正在下载 $filename…');
    await _transfer(
      fileUrl,
      savePath,
      onProgress: onProgress,
      cancelToken: cancelToken,
    );
    return GameDownloadResult(file: File(savePath), filename: filename);
  }

  /// Vector: soft page → `/download/file/…` page → ftp.vector.co.jp link.
  Future<GameDownloadResult> _downloadVector(
    String url,
    String savePath, {
    void Function(String message)? onStatus,
    void Function(int received, int total)? onProgress,
    CancelToken? cancelToken,
  }) async {
    onStatus?.call('正在解析 Vector 下载链接…');

    // Step 1: a soft page needs to be resolved to its file page first.
    var filePageUrl = url;
    if (!_vectorFilePage.hasMatch(url)) {
      final softHtml = await _fetchHtml(url, cancelToken: cancelToken);
      final href = _vectorFileHref.firstMatch(softHtml)?.group(1);
      if (href == null) {
        throw GameDownloadException('未在 Vector 页面找到下载入口');
      }
      filePageUrl = 'https://www.vector.co.jp$href';
    }

    // Step 2: the file page embeds the archive URL on ftp.vector.co.jp.
    final fileHtml = await _fetchHtml(
      filePageUrl,
      cancelToken: cancelToken,
    );
    final match = _vectorDirectLink.firstMatch(fileHtml);
    if (match == null) {
      throw GameDownloadException('未在 Vector 页面找到文件下载链接');
    }
    final fileUrl = match.group(0)!;

    final filename = fileNameFromUrl(fileUrl, 'vector_game.zip');
    onStatus?.call('正在下载 $filename…');
    await _transfer(
      fileUrl,
      savePath,
      referer: filePageUrl,
      onProgress: onProgress,
      cancelToken: cancelToken,
    );
    return GameDownloadResult(file: File(savePath), filename: filename);
  }

  /// Internet Archive: `archive.org/details/{id}` → metadata API lists the
  /// item's files; the best game file is downloaded from
  /// `archive.org/download/{id}/{name}`.
  Future<GameDownloadResult> _downloadArchiveOrg(
    String url,
    String savePath, {
    void Function(String message)? onStatus,
    void Function(int received, int total)? onProgress,
    CancelToken? cancelToken,
  }) async {
    final id = _archiveOrgItem.firstMatch(url)?.group(1);
    if (id == null) {
      throw GameDownloadException('无法解析 Internet Archive 条目链接');
    }
    onStatus?.call('正在查询 Internet Archive 条目…');

    final metaJson = await _fetchHtml(
      'https://archive.org/metadata/$id',
      cancelToken: cancelToken,
    );
    final dynamic meta;
    try {
      meta = json.decode(metaJson);
    } catch (_) {
      throw GameDownloadException('Internet Archive 条目信息解析失败');
    }
    final files = (meta['files'] as List?)?.cast<Map<String, dynamic>>() ??
        const <Map<String, dynamic>>[];
    if (files.isEmpty) {
      throw GameDownloadException('该 Internet Archive 条目没有文件');
    }

    // Filters out archive.org's own derivatives: thumbnails, item tiles,
    // metadata dumps and torrents.
    bool isUtilityFile(Map<String, dynamic> f) {
      final name = (f['name'] as String?) ?? '';
      final format = ((f['format'] as String?) ?? '').toLowerCase();
      return name.startsWith('__ia_thumb') ||
          name.endsWith('_archive.torrent') ||
          name.endsWith('_files.xml') ||
          name.endsWith('_meta.sqlite') ||
          name.endsWith('_meta.xml') ||
          name.endsWith('_meta.json') ||
          format.contains('thumb') ||
          format.contains('tile') ||
          format.contains('metadata') ||
          format.contains('torrent') ||
          format.contains('jpeg') ||
          format.contains('png') ||
          format.contains('image');
    }

    int sizeOf(Map<String, dynamic> f) =>
        int.tryParse('${f['size']}') ?? 0;

    final archives = files
        .where((f) {
          final name = (f['name'] as String?) ?? '';
          return !isUtilityFile(f) && _archiveExt.hasMatch(name);
        })
        .toList()
      ..sort((a, b) => sizeOf(b).compareTo(sizeOf(a)));
    final fallback = files.where((f) => !isUtilityFile(f)).toList()
      ..sort((a, b) => sizeOf(b).compareTo(sizeOf(a)));
    // Items like watashi-kawaii only hold a patch plus images; fall back
    // to the largest remaining non-utility file in that case.
    final pick = archives.isNotEmpty ? archives.first : fallback.firstOrNull;
    if (pick == null) {
      throw GameDownloadException('未在 Internet Archive 条目中找到游戏文件');
    }

    final name = (pick['name'] as String?) ?? '';
    // IA file names may live in subdirectories ("source/game.zip"); each
    // path segment must be encoded separately.
    final encoded = name
        .split('/')
        .map(Uri.encodeComponent)
        .join('/');
    final fileUrl = 'https://archive.org/download/$id/$encoded';
    final filename = sanitizeFileName(name.split('/').last);
    onStatus?.call('正在下载 $filename…');
    await _transfer(
      fileUrl,
      savePath,
      onProgress: onProgress,
      cancelToken: cancelToken,
    );
    return GameDownloadResult(file: File(savePath), filename: filename);
  }

  /// Wayback Machine. `{ts}id_/{original}` serves the captured bytes of a
  /// file snapshot unmodified; links without a concrete timestamp are
  /// resolved to the nearest snapshot first.
  Future<GameDownloadResult> _downloadWayback(
    String url,
    String savePath, {
    void Function(String message)? onStatus,
    void Function(int received, int total)? onProgress,
    CancelToken? cancelToken,
  }) async {
    var match = _waybackUrl.firstMatch(url);
    if (match == null) {
      throw GameDownloadException('无法解析 Wayback Machine 链接');
    }
    var ts = match.group(1) ?? '';
    var original = match.group(2)!;
    onStatus?.call('正在解析网页存档…');

    // Links without a concrete timestamp ("web/*/url") are resolved by
    // following the Wayback redirect to the nearest snapshot first.
    if (ts.isEmpty || ts == '*') {
      try {
        final response = await _dio.get<String>(
          'https://web.archive.org/web/$original',
          options: Options(responseType: ResponseType.plain),
          cancelToken: cancelToken,
        );
        final resolved = _waybackUrl.firstMatch(response.realUri.toString());
        ts = resolved?.group(1) ?? '';
        if (resolved != null) original = resolved.group(2)!;
      } on DioException catch (e) {
        if (CancelToken.isCancel(e)) rethrow;
        throw GameDownloadException('该链接在 Wayback Machine 中暂无存档');
      }
      if (ts.isEmpty || ts == '*') {
        // The redirect landed on a calendar/"not archived" page instead of
        // a concrete snapshot.
        throw GameDownloadException('该链接在 Wayback Machine 中暂无存档');
      }
    }

    String rawUrl(String target) =>
        'https://web.archive.org/web/${ts}id_/$target';

    // detectSource only classifies snapshots whose original URL is itself a
    // game file, so the file can be fetched straight through `id_` (the
    // original captured bytes, no Wayback rewriting).
    final filename = fileNameFromUrl(original, 'wayback_game.zip');
    onStatus?.call('正在从网页存档下载 $filename…');
    await _transfer(
      rawUrl(original),
      savePath,
      onProgress: onProgress,
      cancelToken: cancelToken,
    );
    return GameDownloadResult(file: File(savePath), filename: filename);
  }

  /// itch.io: the game page exposes upload ids; `POST /file/{upload_id}`
  /// answers a short-lived signed CDN URL for anonymous free downloads.
  Future<GameDownloadResult> _downloadItch(
    String url,
    String savePath, {
    void Function(String message)? onStatus,
    void Function(int received, int total)? onProgress,
    CancelToken? cancelToken,
  }) async {
    final match = _itchGamePage.firstMatch(url);
    if (match == null) {
      throw GameDownloadException('无法解析 itch.io 游戏链接');
    }
    onStatus?.call('正在解析 itch.io 下载链接…');

    final pageUrl = 'https://${match.group(1)}.itch.io/${match.group(2)}';
    final html = await _fetchHtml(pageUrl, cancelToken: cancelToken);

    if (html.contains('blocked by an itch.io administrator')) {
      throw GameDownloadException('该 itch.io 页面已被站点管理员屏蔽, 可前往 Internet Archive 查找备份');
    }

    // Upload buttons with their file names; free direct-download pages
    // carry data-upload_id, priced/registration-walled ones do not.
    final uploads = _itchUpload
        .allMatches(html)
        .map((m) => (id: m.group(1)!, name: _decodeHtmlEntities(m.group(2)!)))
        .toList();
    if (uploads.isEmpty) {
      throw GameDownloadException(
        '该作品在 itch.io 需要先在页面中获取 (可能需要自定义价格或登录)',
      );
    }

    // Prefer Windows/PC builds, then plain archives, then the first.
    int score(String name) {
      final lower = name.toLowerCase();
      var s = 0;
      if (lower.contains('win') || lower.contains('pc')) s += 4;
      if (lower.endsWith('.zip')) s += 2;
      return s;
    }

    uploads.sort((a, b) => score(b.name).compareTo(score(a.name)));
    final pick = uploads.first;

    String fileUrl;
    try {
      final response = await _dio.post<String>(
        '$pageUrl/file/${pick.id}',
        queryParameters: {'source': 'game_download'},
        options: Options(
          responseType: ResponseType.plain,
          headers: {'User-Agent': _desktopUserAgent},
        ),
        cancelToken: cancelToken,
      );
      final data = json.decode(response.data ?? '{}');
      fileUrl = (data['url'] as String?) ?? '';
    } on DioException catch (e) {
      if (CancelToken.isCancel(e)) rethrow;
      throw GameDownloadException('itch.io 下载链接获取失败 (${e.response?.statusCode ?? e.type.name})');
    }
    if (fileUrl.isEmpty) {
      throw GameDownloadException('itch.io 未返回下载链接 (可能需要登录或付费)');
    }

    // The signed CDN URL is short-lived; download it right away.
    final filename = sanitizeFileName(
      _archiveExt.hasMatch(pick.name) ? pick.name : '${pick.name}.zip',
    );
    onStatus?.call('正在下载 $filename…');
    await _transfer(
      fileUrl,
      savePath,
      onProgress: onProgress,
      cancelToken: cancelToken,
    );
    return GameDownloadResult(file: File(savePath), filename: filename);
  }

  Future<GameDownloadResult> _downloadBooth(
    String url,
    String savePath, {
    String? cookieHeader,
    void Function(String message)? onStatus,
    void Function(int received, int total)? onProgress,
    CancelToken? cancelToken,
  }) async {
    if (_boothItem.firstMatch(url) == null) {
      throw GameDownloadException('无法解析 BOOTH 条目链接');
    }
    final cookies = (cookieHeader ?? '').trim();
    if (cookies.isEmpty) {
      throw GameDownloadException('BOOTH 下载需要先登录账号 (设置 → BOOTH 账号)');
    }
    onStatus?.call('正在解析 BOOTH 条目…');

    var pageHtml = await _fetchHtml(url, cancelToken: cancelToken, cookieHeader: cookies);
    final reloaded = await _confirmBoothAgeGate(
      url,
      pageHtml,
      cookies,
      cancelToken: cancelToken,
    );
    if (reloaded != null) pageHtml = reloaded;

    final files = _boothFiles(pageHtml);
    if (files.isEmpty) {
      throw GameDownloadException(
        '未在 BOOTH 条目中找到可下载文件 (可能未购买该作品或登录已过期)',
      );
    }

    int score(String name) {
      final lower = name.toLowerCase();
      var s = 0;
      if (lower.contains('win') || lower.contains('pc')) s += 4;
      if (lower.endsWith('.zip')) s += 2;
      return s;
    }

    files.sort((a, b) => score(b.name).compareTo(score(a.name)));
    final pick = files.first;

    final filename = sanitizeFileName(
      _archiveExt.hasMatch(pick.name) ? pick.name : '$pick.name.zip',
    );
    onStatus?.call('正在下载 $filename…');
    await _transfer(
      pick.href,
      savePath,
      cookieHeader: cookies,
      onProgress: onProgress,
      cancelToken: cancelToken,
    );
    _rejectHtmlPayload(savePath);
    return GameDownloadResult(file: File(savePath), filename: filename);
  }

  static List<({String href, String name})> _boothFiles(String html) {
    final result = <({String href, String name})>[];
    final seen = <String>{};
    for (final match in _boothDownloadable.allMatches(html)) {
      final href = match.group(1)!;
      if (!seen.add(href)) continue;
      var name = _titleAttr.firstMatch(match.group(0)!)?.group(1) ?? '';
      if (name.isEmpty) {
        final tail = html.substring(match.end).split('</a>').first;
        final text = tail
            .replaceAll(RegExp(r'<[^>]+>'), ' ')
            .replaceAll('&nbsp;', ' ')
            .trim();
        if (text.isNotEmpty) name = text.split(RegExp(r'\s')).first;
      }
      if (name.isEmpty) {
        final id = Uri.tryParse(href)?.pathSegments.lastOrNull;
        name = 'booth_${id ?? 'game'}.zip';
      }
      result.add((href: href, name: _decodeHtmlEntities(name)));
    }
    return result;
  }

  Future<String?> _confirmBoothAgeGate(
    String pageUrl,
    String html,
    String cookies, {
    CancelToken? cancelToken,
  }) async {
    final form = _boothAgeForm.firstMatch(html);
    if (form == null) return null;
    final action = Uri.parse(pageUrl).resolve(form.group(1)!).toString();
    final fields = <String, String>{};
    for (final input in _hiddenInput.allMatches(form.group(2)!)) {
      final tag = input.group(0)!;
      final name = RegExp('name="([^"]+)"').firstMatch(tag)?.group(1);
      if (name == null) continue;
      fields[name] = RegExp('value="([^"]*)"').firstMatch(tag)?.group(1) ?? '';
    }
    try {
      await _dio.post<String>(
        action,
        data: fields,
        options: Options(
          responseType: ResponseType.plain,
          contentType: Headers.formUrlEncodedContentType,
          headers: {
            'User-Agent': _desktopUserAgent,
            'Cookie': cookies,
          },
        ),
        cancelToken: cancelToken,
      );
    } on DioException catch (e) {
      if (CancelToken.isCancel(e)) rethrow;
      return null;
    }
    return _fetchHtml(pageUrl, cancelToken: cancelToken, cookieHeader: cookies);
  }

  static void _rejectHtmlPayload(String savePath) {
    final file = File(savePath);
    if (!file.existsSync()) return;
    final length = file.lengthSync();
    if (length == 0 || length > 512 * 1024) return;
    final handle = file.openSync(mode: FileMode.read);
    final bytes = handle.readSync(length < 2048 ? length : 2048);
    handle.closeSync();
    final text = String.fromCharCodes(bytes).toLowerCase();
    if (text.startsWith('<') ||
        text.contains('<!doctype') ||
        text.contains('<html')) {
      file.deleteSync();
      if (text.contains('sign_in')) {
        throw GameDownloadException('BOOTH 登录已过期, 请在设置中重新登录');
      }
      throw GameDownloadException('BOOTH 返回了页面而非文件 (可能未购买该作品, 可前往页面确认)');
    }
  }

  /// Minimal HTML entity decoding for file names parsed out of pages.
  /// The ampersand entity is decoded last so that sequences like the
  /// quoted-string entity survive as literal text.
  static String _decodeHtmlEntities(String s) => s
      .replaceAll('&quot;', '"')
      .replaceAll('&#039;', "'")
      .replaceAll('&#39;', "'")
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&amp;', '&');

  /// A plain direct file URL.
  Future<GameDownloadResult> _downloadDirect(
    String url,
    String savePath, {
    void Function(String message)? onStatus,
    void Function(int received, int total)? onProgress,
    CancelToken? cancelToken,
  }) async {
    final filename = fileNameFromUrl(url, 'game_download.zip');
    onStatus?.call('正在下载 $filename…');
    await _transfer(
      url,
      savePath,
      onProgress: onProgress,
      cancelToken: cancelToken,
    );
    return GameDownloadResult(file: File(savePath), filename: filename);
  }

  Future<String> _fetchHtml(
    String url, {
    CancelToken? cancelToken,
    String? cookieHeader,
  }) async {
    try {
      final response = await _dio.get<String>(
        url,
        options: Options(
          responseType: ResponseType.plain,
          // Desktop UA: vector.co.jp serves a stripped mobile page without
          // download links to phone user agents.
          headers: {
            'User-Agent': _desktopUserAgent,
            if (cookieHeader != null && cookieHeader.isNotEmpty)
              'Cookie': cookieHeader,
          },
        ),
        cancelToken: cancelToken,
      );
      return response.data ?? '';
    } on DioException catch (e) {
      if (CancelToken.isCancel(e)) rethrow;
      throw GameDownloadException(
        '无法访问 ${Uri.tryParse(url)?.host ?? url}: '
        '${e.response?.statusCode ?? e.message ?? e.type.name}',
      );
    }
  }

  Future<void> _transfer(
    String url,
    String savePath, {
    String? referer,
    String? cookieHeader,
    void Function(int received, int total)? onProgress,
    CancelToken? cancelToken,
  }) async {
    try {
      await _dio.download(
        url,
        savePath,
        options: Options(
          headers: {
            if (referer != null) 'Referer': referer,
            if (cookieHeader != null && cookieHeader.isNotEmpty)
              'Cookie': cookieHeader,
          },
        ),
        onReceiveProgress: onProgress,
        cancelToken: cancelToken,
      );
    } on DioException catch (e) {
      if (CancelToken.isCancel(e)) rethrow;
      throw GameDownloadException(
        '下载失败: ${e.response?.statusCode ?? e.message ?? e.type.name}',
      );
    }
  }

  /// Derives a file name from a URL path, falling back to [fallback].
  static String fileNameFromUrl(String url, String fallback) {
    final path = Uri.tryParse(url)?.path ?? '';
    final segments = path.split('/').where((s) => s.isNotEmpty).toList();
    final last = segments.isEmpty ? null : segments.last;
    if (last != null && last.contains('.') && last.length <= 120) {
      return sanitizeFileName(last);
    }
    return fallback;
  }

  static String sanitizeFileName(String name) {
    final cleaned = name
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
        .replaceAll(RegExp(r'\s+'), '_')
        .trim();
    return cleaned.isEmpty ? 'game.zip' : cleaned;
  }

  /// Releases the underlying HTTP resources.
  void dispose() => _dio.close(force: true);
}

/// Provider for [GameDownloadService].
final gameDownloadServiceProvider = Provider<GameDownloadService>((ref) {
  final service = GameDownloadService();
  ref.onDispose(() => service.dispose());
  return service;
});
