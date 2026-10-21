import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// One entry in a user's edit (contribution) history, parsed from
/// `https://vndb.org/<uid>/hist`.
class UserEditEntry {
  const UserEditEntry({
    required this.revId,
    required this.entryId,
    required this.date,
    required this.title,
    this.comment,
  });

  /// Full revision id, e.g. `v62951.4`.
  final String revId;

  /// Base entry id, e.g. `v62951`.
  final String entryId;

  /// Edit date as displayed on the site, e.g. `2026-03-08 at 22:40`.
  final String date;

  /// Title of the edited page.
  final String title;

  /// Optional edit summary / comment.
  final String? comment;

  /// The entry-type prefix, e.g. `v`, `r`, `s`.
  String get prefix {
    final m = RegExp(r'^([a-z]+)').firstMatch(entryId);
    return m?.group(1) ?? '';
  }

  /// In-app route for the edited entry, or null when the type is not
  /// represented inside the app (e.g. docs `d*`).
  String? get route {
    switch (prefix) {
      case 'v':
        return '/vn/$entryId';
      case 'r':
        return '/release/$entryId';
      case 'c':
        return '/character/$entryId';
      case 'p':
        return '/producer/$entryId';
      case 's':
        return '/staff/$entryId';
      case 'g':
        return '/tag/$entryId';
      case 'i':
        return '/trait/$entryId';
      default:
        return null;
    }
  }
}

/// Fetches and parses a VNDB user's public edit history.
///
/// The Kana API does not expose contribution history, so this scrapes the
/// website's `/u<id>/hist` pages instead. VNDB fronts that page with a
/// lightweight bot check: the first request returns HTTP 503 with an HTML
/// page referencing a `/totally-innocent-logo-image.svg?<token>` URL whose
/// response sets the `xbotcheck` cookie. This service resolves that
/// challenge once and reuses the cookie for subsequent pages.
class UserHistService {
  UserHistService()
      : _dio = Dio(
          BaseOptions(
            baseUrl: 'https://vndb.org',
            connectTimeout: const Duration(seconds: 15),
            receiveTimeout: const Duration(seconds: 30),
            headers: {
              'User-Agent':
                  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) VNclient/1.4.0',
              'Accept': 'text/html,application/xhtml+xml',
            },
          ),
        );

  final Dio _dio;

  /// The resolved bot-check cookie (`xbotcheck=<value>`), shared across
  /// requests once obtained.
  String? _botCookie;

  /// Entries per page on the website (keep in sync with the parser).
  static const int perPage = 50;

  /// Fetches one page of a user's edit history ([page] starts at 1).
  Future<List<UserEditEntry>> fetch(String userId, {int page = 1}) async {
    final html = await _fetchHtml('/$userId/hist?p=$page');
    return _parse(html);
  }

  Future<String> _fetchHtml(String path) async {
    final first = await _get(path);
    if (_isChallenge(first)) {
      await _solveChallenge(first);
      final second = await _get(path);
      if (_isChallenge(second)) {
        throw Exception('无法通过网站人机验证, 请稍后重试');
      }
      return second.data as String;
    }
    if (first.statusCode == 404) {
      throw Exception('用户不存在或没有编辑记录');
    }
    return first.data as String;
  }

  bool _isChallenge(Response<dynamic> response) {
    if (response.statusCode == 503) return true;
    final body = response.data?.toString() ?? '';
    return body.contains('totally-innocent-logo-image');
  }

  Future<Response<dynamic>> _get(String path) async {
    return _dio.get<dynamic>(
      path,
      options: Options(
        // The challenge itself is served with 503; accept it so we can
        // inspect the body instead of throwing.
        validateStatus: (status) => status != null && status < 600,
        headers: {
          if (_botCookie != null) 'Cookie': _botCookie,
        },
        responseType: ResponseType.plain,
      ),
    );
  }

  /// Solves the browser check: requests the challenge image (which makes
  /// the server set the `xbotcheck` cookie) and stores the cookie value.
  Future<void> _solveChallenge(Response<dynamic> challenge) async {
    final body = challenge.data?.toString() ?? '';
    final m =
        RegExp(r'/totally-innocent-logo-image\.svg\?[A-Za-z0-9_-]+')
            .firstMatch(body);
    if (m == null) {
      throw Exception('无法解析网站人机验证');
    }
    final response = await _dio.get<dynamic>(
      m.group(0)!,
      options: Options(
        validateStatus: (status) => status != null && status < 600,
        responseType: ResponseType.bytes,
      ),
    );
    final setCookie = response.headers.map['set-cookie'];
    if (setCookie != null) {
      for (final raw in setCookie) {
        final cookie = raw.split(';').first.trim();
        if (cookie.startsWith('xbotcheck=')) {
          _botCookie = cookie;
          return;
        }
      }
    }
    throw Exception('网站人机验证未返回有效 Cookie');
  }

  /// Parses the history table rows out of the page HTML.
  List<UserEditEntry> _parse(String html) {
    final entries = <UserEditEntry>[];
    final rowRegexp = RegExp(
      r'<td class="tc1_1"><a href="/([a-z]+\d+(?:\.\d+)?)">[^<]*</a></td>'
      r'<td class="tc1_2">(?:<a href="[^"]*">[^<]*</a>)?</td>'
      r'<td class="tc2">([^<]*)</td>'
      r'<td class="tc4">(.*?)</td>',
      dotAll: true,
    );
    for (final match in rowRegexp.allMatches(html)) {
      final revId = match.group(1)!;
      final date = match.group(2) ?? '';
      final tc4 = match.group(3) ?? '';

      // Page title: the first <a> inside the tc4 cell.
      final titleMatch = RegExp(r'<a [^>]*>(.*?)</a>').firstMatch(tc4);
      final title = titleMatch != null
          ? _stripTags(titleMatch.group(1) ?? '')
          : _stripTags(tc4.split('<small>').first);

      // Edit comment: the <small> element, if present.
      final smallMatch = RegExp(r'<small>(.*?)</small>').firstMatch(tc4);
      final comment = smallMatch != null
          ? _stripTags(smallMatch.group(1) ?? '')
          : null;

      entries.add(UserEditEntry(
        revId: revId,
        entryId: revId.split('.').first,
        date: date,
        title: title,
        comment: (comment == null || comment.isEmpty) ? null : comment,
      ));
    }
    return entries;
  }

  /// Removes HTML tags, decodes common entities and collapses whitespace.
  ///
  /// The entity literals are written with explicit `\u0026` escapes so the
  /// source stays unambiguous.
  String _stripTags(String s) {
    var out = s.replaceAll(RegExp(r'<[^>]*>'), ' ');
    const amp = '\u0026amp;';
    const lt = '\u0026lt;';
    const gt = '\u0026gt;';
    const quot = '\u0026quot;';
    const apos = '\u0026#39;';
    const nbsp = '\u0026nbsp;';
    out = out
        .replaceAll(apos, "'")
        .replaceAll(quot, '"')
        .replaceAll(nbsp, ' ')
        .replaceAll(lt, '<')
        .replaceAll(gt, '>')
        .replaceAll(amp, '&');
    return out.replaceAll(RegExp(r'\s+'), ' ').trim();
  }
}

/// Provider for [UserHistService].
final userHistServiceProvider = Provider<UserHistService>((ref) {
  return UserHistService();
});
