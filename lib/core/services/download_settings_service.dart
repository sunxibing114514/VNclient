import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/app_constants.dart';

/// Persisted download settings (Android game downloads).
class DownloadSettings {
  const DownloadSettings({this.directory = defaultDirectory});

  /// Default: a `VNclient` subfolder of the public Download directory.
  static const String defaultDirectory = 'VNclient';

  final String directory;

  /// Whether the configured directory is an absolute path the user typed.
  bool get isAbsolute => directory.startsWith('/');

  /// Human-readable description of the final location.
  String describe(String filename) => isAbsolute
      ? '$directory/$filename'
      : 'Download/$directory/$filename';
}

/// State notifier persisting the game download directory through
/// [SharedPreferences].
class DownloadSettingsNotifier extends StateNotifier<DownloadSettings> {
  DownloadSettingsNotifier() : super(const DownloadSettings()) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final dir = prefs.getString(AppConstants.downloadDirKey);
    if (dir != null && dir.trim().isNotEmpty) {
      state = DownloadSettings(directory: dir.trim());
    }
  }

  Future<void> setDirectory(String directory) async {
    final trimmed = directory.trim();
    final value =
        trimmed.isEmpty ? DownloadSettings.defaultDirectory : trimmed;
    state = DownloadSettings(directory: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.downloadDirKey, value);
  }

  Future<void> resetToDefault() => setDirectory(
        DownloadSettings.defaultDirectory,
      );
}

final downloadSettingsProvider =
    StateNotifierProvider<DownloadSettingsNotifier, DownloadSettings>((ref) {
  return DownloadSettingsNotifier();
});

/// The `vnclient/media` platform channel (shared with screenshot
/// share/save, see `image_viewer_page.dart`).
const MethodChannel mediaChannel = MethodChannel('vnclient/media');

/// Moves a downloaded file into the user-configured destination through the
/// platform channel.
///
/// The native side decides how to store it:
///  - absolute configured path → written directly (works for app-specific
///    directories; public paths may be denied on Android 10+);
///  - relative name (default) → the public Download collection:
///    MediaStore on Android 10+ (no permission needed), direct file copy on
///    Android 9 and below (legacy storage permission).
///
/// Returns the final absolute path of the stored file.
Future<String> moveDownloadToDestination(
  String tempPath,
  String filename,
  String directorySetting,
) {
  return mediaChannel.invokeMethod<String>('saveDownload', {
    'path': tempPath,
    'filename': filename,
    'dir': directorySetting,
  }).then((path) => path ?? tempPath);
}

/// Opens a downloaded file with the system viewer (best-effort).
Future<String> openDownloadedFile(String path) async {
  final result = await mediaChannel.invokeMethod<String>('openFile', {
    'path': path,
  });
  return result ?? '已打开';
}
