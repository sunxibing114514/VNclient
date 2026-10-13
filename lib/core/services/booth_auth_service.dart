import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class BoothAuthState {
  const BoothAuthState({this.cookieHeader, this.checking = false});

  final String? cookieHeader;

  final bool checking;

  bool get isLoggedIn => cookieHeader?.isNotEmpty ?? false;
}

class BoothAuthNotifier extends StateNotifier<BoothAuthState> {
  BoothAuthNotifier() : super(const BoothAuthState()) {
    _load();
  }

  static const _storage = FlutterSecureStorage();
  static const _cookieKey = 'booth_session_cookies';

  static const String _desktopUserAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
      'AppleWebKit/537.36 (KHTML, like Gecko) '
      'Chrome/131.0.0.0 Safari/537.36';

  late final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 30),
      headers: {
        'User-Agent': _desktopUserAgent,
        'Accept': 'text/html,application/xhtml+xml,*/*;q=0.8',
        'Accept-Language': 'ja,en;q=0.8',
      },
      validateStatus: (code) => code != null && code < 400,
    ),
  );

  Future<void> _load() async {
    try {
      final raw = await _storage.read(key: _cookieKey);
      if (raw == null || raw.isEmpty) return;
      state = BoothAuthState(cookieHeader: raw);
    } catch (_) {
    }
  }

  Future<void> _persist(String? raw) async {
    try {
      if (raw == null || raw.isEmpty) {
        await _storage.delete(key: _cookieKey);
      } else {
        await _storage.write(key: _cookieKey, value: raw);
      }
    } catch (_) {
    }
  }

  String? cookieHeader() => state.cookieHeader;

  Future<bool> checkSession() async {
    if (!state.isLoggedIn) return false;
    state = BoothAuthState(
      cookieHeader: state.cookieHeader,
      checking: true,
    );
    final ok = await _isLoggedIn(state.cookieHeader!);
    if (!ok) {
      await logout();
      return false;
    }
    state = BoothAuthState(cookieHeader: state.cookieHeader);
    return true;
  }

  Future<bool> adoptWebviewCookies(
    List<String> nameValuePairs, {
    bool pageSaysLoggedIn = false,
  }) async {
    final useful = nameValuePairs
        .where((c) => c.contains('='))
        .where((c) => !_isNoiseCookie(c))
        .toList();
    final raw = useful.join('; ');
    final sessionPresent =
        useful.any((c) => c.startsWith('_plaza_session'));
    if (raw.isEmpty) return false;
    if (pageSaysLoggedIn && sessionPresent) {
      await _persist(raw);
      state = BoothAuthState(cookieHeader: raw);
      return true;
    }
    final valid = await _isLoggedIn(raw);
    if (!valid) return false;
    await _persist(raw);
    state = BoothAuthState(cookieHeader: raw);
    return true;
  }

  static bool _isNoiseCookie(String pair) {
    final name = pair.substring(0, pair.indexOf('=')).trim();
    return name.startsWith('__cf') ||
        name.startsWith('_ga') ||
        name.startsWith('_gid') ||
        name.startsWith('_hj') ||
        name.startsWith('_fbp') ||
        name.startsWith('_gcl') ||
        name.startsWith('_sc') ||
        name.startsWith('cf_');
  }

  Future<String?> loginWithPassword(String email, String password) async {
    final normalized = email.trim();
    if (normalized.isEmpty || password.isEmpty) {
      return '请输入邮箱与密码';
    }
    try {
      final page = await _dio.get<String>(
        'https://booth.pm/users/sign_in_by_password',
        options: Options(responseType: ResponseType.plain),
      );
      final getCookies = _mergeSetCookies(page);
      final token = RegExp(
        r'name="authenticity_token"[^>]*value="([^"]+)"',
      ).firstMatch(page.data ?? '')?.group(1);
      if (token == null) return '无法获取 BOOTH 登录表单 (页面结构可能已变化)';

      final response = await _dio.post<String>(
        'https://booth.pm/users/sign_in',
        data: {
          'authenticity_token': token,
          'user[email]': normalized,
          'user[password]': password,
        },
        options: Options(
          responseType: ResponseType.plain,
          followRedirects: false,
          validateStatus: (code) => code != null && code < 500,
          headers: {
            'Content-Type': 'application/x-www-form-urlencoded',
            'Origin': 'https://booth.pm',
            'Referer': 'https://booth.pm/users/sign_in_by_password',
            if (getCookies.isNotEmpty) 'Cookie': getCookies,
          },
        ),
      );

      final status = response.statusCode ?? 0;
      final merged = _mergeCookies(getCookies, response);
      final freshSession = _setCookiePairs(response)
          .any((pair) => pair.startsWith('_plaza_session'));

      if (status == 302 && freshSession) {
        await _persist(merged);
        state = BoothAuthState(cookieHeader: merged);
        return null; // signed in
      }
      if (status == 200) {
        final body = response.data ?? '';
        final invalid = RegExp(
          r'(正しくありません|メールアドレスまたはパスワード|invalid|incorrect|wrong)',
          caseSensitive: false,
        ).hasMatch(body);
        final blocked = RegExp(
          r'(確認してください|verify|captcha|エラーが発生)',
          caseSensitive: false,
        ).hasMatch(body);
        if (invalid) return '邮箱或密码不正确';
        if (blocked) {
          return '登录被拦截或需要验证, 建议改用 Pixiv 登录';
        }
        return '登录失败 (HTTP $status), 请改用 Pixiv 登录';
      }
      if (status == 302 && !freshSession) {
        return '登录失败: 服务器未建立会话, 请改用 Pixiv 登录';
      }
      return '登录失败 (HTTP $status), 请稍后再试';
    } on DioException catch (e) {
      final code = e.response?.statusCode;
      if (code == 429) return '尝试过于频繁, 请稍后再试';
      if (code == 403) return '请求被拦截 (403), 建议改用 Pixiv 登录';
      return '网络错误, 登录失败 (${e.type.name})';
    }
  }

  Future<void> logout() async {
    await _persist(null);
    state = const BoothAuthState();
  }

  Future<bool> _isLoggedIn(String cookieHeader) async {
    try {
      final response = await _dio.get<String>(
        'https://accounts.booth.pm/library',
        options: Options(
          responseType: ResponseType.plain,
          headers: {'Cookie': cookieHeader},
        ),
      );
      final finalUrl = response.realUri.toString();
      if (finalUrl.contains('sign_in') || finalUrl.contains('login')) {
        return false;
      }
      if (finalUrl.contains('/library') || finalUrl.contains('/dashboard')) {
        return true;
      }
      return !((response.data ?? '').contains('users/sign_in'));
    } on DioException {
      return false;
    }
  }

  static List<String> _setCookiePairs(Response response) {
    final result = <String>[];
    final values = response.headers['set-cookie'] ?? const [];
    for (final raw in values) {
      for (final chunk in raw.split(RegExp(r',(?=[^;]+?=)'))) {
        final pair = chunk.split(';').first.trim();
        if (pair.contains('=') && !pair.contains('expires=')) {
          result.add(pair);
        }
      }
    }
    return result;
  }

  static String _mergeSetCookies(Response response) =>
      _mergePairs(_setCookiePairs(response));

  static String _mergeCookies(String base, Response response) =>
      _mergePairs([...base.split('; '), ..._setCookiePairs(response)]);

  static String _mergePairs(List<String> pairs) {
    final map = <String, String>{};
    for (final pair in pairs) {
      final eq = pair.indexOf('=');
      if (eq <= 0) continue;
      map[pair.substring(0, eq).trim()] = pair.substring(eq + 1).trim();
    }
    return map.entries.map((e) => '${e.key}=${e.value}').join('; ');
  }
}

final boothAuthProvider =
    StateNotifierProvider<BoothAuthNotifier, BoothAuthState>((ref) {
  return BoothAuthNotifier();
});
