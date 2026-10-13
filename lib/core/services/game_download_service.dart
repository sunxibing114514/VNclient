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

  /// A Wayback Machine snapshot (web.archive.org/web/{ts}/{url}). Dead
  /// official sites often still have their game archives captured; the
  /// `id_` suffix makes the Wayback serve the original unmodified bytes.
  wayback,

  /// itch.io game pages with free direct downloads. The page exposes
  /// upload ids; `POST /file/{upload_id}` answers a short-lived signed
  /// CDN URL. Pages behind a price/registration wall or blocked by an
  /// administrator cannot be resolved.
  itch,

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
///    snapshots of dead official sites; the `{ts}id_/{url}` form serves
///    the original unmodified bytes, both for direct file captures and
///    for page snapshots whose original HTML is scanned for archive
///    links.
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

  /// Absolute http(s) URL in a Wayback-captured page.
  static final RegExp _absoluteLink = RegExp(
    r'''https?://[^\s"'<>]+''',
    caseSensitive: false,
  );

  /// Relative href in a Wayback-captured page, e.g. `href="game.zip"`.
  static final RegExp _hrefLink = RegExp(
    r'''href=["']([^"'\s]+)["']''',
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
    // Wayback before directFile: a snapshot URL whose original points at a
    // zip has a path ending in ".zip" and would otherwise be mistaken for
    // a plain direct link.
    if (_waybackUrl.hasMatch(clean)) return GameDownloadSource.wayback;
    if (_itchGamePage.hasMatch(clean)) return GameDownloadSource.itch;
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

  /// Wayback Machine. `{ts}id_/{original}` serves the captured bytes
  /// unmodified; page snapshots are scanned for archive links which are in
  /// turn fetched through the Wayback.
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

    // Case 1: the snapshot is of a direct file (the dead site's zip).
    if (isDirectFileUrl(original)) {
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

    // Case 2: a page snapshot — fetch the ORIGINAL html through `id_`
    // (no Wayback rewriting) and look for game file links.
    final pageHtml = await _fetchHtml(rawUrl(original), cancelToken: cancelToken);

    String? fileUrl;
    for (final candidate in _absoluteLink.allMatches(pageHtml)) {
      final link = candidate.group(0)!;
      if (isDirectFileUrl(link)) {
        fileUrl = link;
        break;
      }
    }
    fileUrl ??= _pickRelativeArchiveLink(pageHtml, original);

    if (fileUrl == null) {
      throw GameDownloadException(
        '未在网页存档中找到游戏文件链接, 可选择访问存档页面手动下载',
      );
    }
    final filename = fileNameFromUrl(fileUrl, 'wayback_game.zip');
    onStatus?.call('正在从网页存档下载 $filename…');
    await _transfer(
      rawUrl(fileUrl),
      savePath,
      onProgress: onProgress,
      cancelToken: cancelToken,
    );
    return GameDownloadResult(file: File(savePath), filename: filename);
  }

  /// Resolves relative hrefs ending in an archive extension against the
  /// snapshot's original URL.
  static String? _pickRelativeArchiveLink(String html, String baseUrl) {
    final base = Uri.tryParse(baseUrl);
    if (base == null) return null;
    for (final candidate in _hrefLink.allMatches(html)) {
      final href = candidate.group(1)!;
      if (!isDirectFileUrl(href)) continue;
      try {
        final resolved = base.resolve(href);
        if (resolved.isScheme('http') || resolved.isScheme('https')) {
          return resolved.toString();
        }
      } catch (_) {
        // ignore malformed hrefs
      }
    }
    return null;
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
  }) async {
    try {
      final response = await _dio.get<String>(
        url,
        options: Options(
          responseType: ResponseType.plain,
          // Desktop UA: vector.co.jp serves a stripped mobile page without
          // download links to phone user agents.
          headers: {'User-Agent': _desktopUserAgent},
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
    void Function(int received, int total)? onProgress,
    CancelToken? cancelToken,
  }) async {
    try {
      await _dio.download(
        url,
        savePath,
        options: Options(
          headers: {if (referer != null) 'Referer': referer},
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
