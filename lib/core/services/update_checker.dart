import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/app_constants.dart';

/// Result of an update check.
class UpdateResult {
  const UpdateResult({
    required this.hasUpdate,
    required this.latestVersion,
    required this.currentVersion,
    this.releaseUrl,
    this.releaseNotes,
    this.error,
  });

  /// Whether a newer version is available.
  final bool hasUpdate;

  /// Latest version tag from GitHub (e.g. "v1.1.0").
  final String latestVersion;

  /// Current installed version (e.g. "1.0.0").
  final String currentVersion;

  /// HTML URL of the release page.
  final String? releaseUrl;

  /// Release notes / body text.
  final String? releaseNotes;

  /// Error message if the check failed.
  final String? error;

  bool get isError => error != null;
}

/// Checks GitHub releases for a newer app version.
class UpdateChecker {
  UpdateChecker(this._dio);

  final Dio _dio;

  /// Normalize a version string by stripping leading "v" and splitting on ".".
  List<int> _parseVersion(String v) {
    final cleaned = v.trim().replaceAll(RegExp(r'^v'), '');
    return cleaned
        .split('.')
        .map((e) => int.tryParse(e) ?? 0)
        .toList();
  }

  /// Compare two version strings.
  /// Returns >0 if a > b, 0 if equal, <0 if a < b.
  int _compareVersions(String a, String b) {
    final pa = _parseVersion(a);
    final pb = _parseVersion(b);
    final maxLen = pa.length > pb.length ? pa.length : pb.length;
    for (var i = 0; i < maxLen; i++) {
      final va = i < pa.length ? pa[i] : 0;
      final vb = i < pb.length ? pb[i] : 0;
      if (va != vb) return va - vb;
    }
    return 0;
  }

  /// Fetches the latest release from GitHub and compares to the current version.
  Future<UpdateResult> check() async {
    final current = AppConstants.appVersion;
    try {
      final response = await _dio.get<dynamic>(
        AppConstants.githubReleasesApi,
        options: Options(
          headers: {'Accept': 'application/vnd.github+json'},
          sendTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
        ),
      );
      final data = response.data as Map<String, dynamic>;
      final tag = data['tag_name'] as String? ?? '';
      final latest = tag.replaceAll(RegExp(r'^v'), '');
      final htmlUrl = data['html_url'] as String?;
      final body = data['body'] as String?;
      final hasUpdate = _compareVersions(latest, current) > 0;
      return UpdateResult(
        hasUpdate: hasUpdate,
        latestVersion: latest,
        currentVersion: current,
        releaseUrl: htmlUrl,
        releaseNotes: body,
      );
    } on DioException catch (e) {
      final msg = e.response?.statusCode == 404
          ? '尚未发布任何 Release'
          : '网络错误: ${e.message ?? e.type.name}';
      return UpdateResult(
        hasUpdate: false,
        latestVersion: '',
        currentVersion: current,
        error: msg,
      );
    } catch (e) {
      return UpdateResult(
        hasUpdate: false,
        latestVersion: '',
        currentVersion: current,
        error: '检查失败: $e',
      );
    }
  }
}

/// Provider for [UpdateChecker].
final updateCheckerProvider = Provider<UpdateChecker>((ref) {
  // Reuse a dedicated Dio instance (no auth needed for GitHub API).
  return UpdateChecker(Dio(BaseOptions(
    baseUrl: '',
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
  )));
});
