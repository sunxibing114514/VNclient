import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/router/app_router.dart';
import '../../core/services/booth_auth_service.dart';
import '../../core/services/download_settings_service.dart';
import '../../core/services/game_download_service.dart';

/// Copies [url] to the clipboard and confirms with a snackbar.
///
/// Used for the long-press gesture on every kind of link (extlinks, 备注内
/// 链接), so links can always be copied without opening them.
void copyLinkToClipboard(BuildContext context, String url) {
  Clipboard.setData(ClipboardData(text: url));
  ScaffoldMessenger.maybeOf(context)?.showSnackBar(
    SnackBar(
      content: const Text('链接已复制'),
      duration: const Duration(seconds: 2),
    ),
  );
}

/// Handles taps on external links of releases / VNs / 备注链接
/// (Android only; other platforms fall through to the in-app WebView).
///
/// When the link points at a site this client can resolve to a direct game
/// file (freem!, NovelGame, Vector, or a plain archive URL — see
/// [GameDownloadService]), the user is asked whether to download the game
/// right away or to visit the page in the browser. Anything else (commercial
/// stores, wikis, blogs, …) opens the in-app WebView as usual.
Future<void> handleGameLinkTap(
  BuildContext context,
  WidgetRef ref,
  String url, {
  String? label,
  String? name,
}) async {
  final source = GameDownloadService.detectSource(url, name: name);
  final downloadable = Platform.isAndroid && source != null;

  if (!downloadable) {
    // Not Android, or not a resolvable download link: plain browsing.
    openWebView(context, url, title: label);
    return;
  }

  String? boothCookie;
  if (source == GameDownloadSource.booth) {
    boothCookie = ref.read(boothAuthProvider).cookieHeader;
    if (boothCookie == null || boothCookie.isEmpty) {
      final loginChoice = await showModalBottomSheet<String>(
        context: context,
        showDragHandle: true,
        builder: (sheetContext) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.account_circle_outlined, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'BOOTH 下载需要登录',
                            style: Theme.of(sheetContext).textTheme.titleMedium,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '免费与已购作品都需要 BOOTH 账号, 登录状态会保存在本机。',
                      style: Theme.of(sheetContext).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              ListTile(
                leading: const Icon(Icons.login),
                title: const Text('前往设置登录'),
                subtitle: const Text('支持 Pixiv 与邮箱登录'),
                onTap: () => Navigator.pop(sheetContext, 'login'),
              ),
              ListTile(
                leading: const Icon(Icons.open_in_new),
                title: const Text('访问 BOOTH 页面'),
                onTap: () => Navigator.pop(sheetContext, 'visit'),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      );
      if (!context.mounted) return;
      switch (loginChoice) {
        case 'login':
          context.push('/settings');
        case 'visit':
          openWebView(context, url, title: label);
      }
      return;
    }
  }

  final sourceName = GameDownloadService.sourceLabel(source!);
  final settings = ref.read(downloadSettingsProvider);
  final choice = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.videogame_asset_outlined, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '检测到 $sourceName 可下载链接',
                        style: Theme.of(sheetContext).textTheme.titleMedium,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '本作品可直接下载解析到的游戏文件。',
                  style: Theme.of(sheetContext).textTheme.bodySmall,
                ),
                const SizedBox(height: 6),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      size: 14,
                      color: Colors.orange.shade800,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '请遵守各平台条款; 本软件不绕过任何平台限制。',
                        style: Theme.of(sheetContext)
                            .textTheme
                            .bodySmall
                            ?.copyWith(
                              color: Colors.orange.shade800,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.download),
            title: const Text('下载游戏'),
            subtitle: Text(
              '保存到 ${settings.isAbsolute ? settings.directory : 'Download/${settings.directory}'}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(sheetContext).textTheme.bodySmall,
            ),
            onTap: () => Navigator.pop(sheetContext, 'download'),
          ),
          ListTile(
            leading: const Icon(Icons.open_in_new),
            title: Text('访问 $sourceName 页面'),
            onTap: () => Navigator.pop(sheetContext, 'visit'),
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );

  if (!context.mounted) return;
  if (choice == 'visit') {
    openWebView(context, url, title: label);
  } else if (choice == 'download') {
    await _startGameDownload(context, ref, url, boothCookie: boothCookie);
  }
}

/// Runs the whole download flow: resolve the site's direct download link,
/// download to a temporary file with progress, then move the file into the
/// user-configured download directory through the platform channel. All of
/// it is visualized inside one stateful dialog.
Future<void> _startGameDownload(
  BuildContext context,
  WidgetRef ref,
  String url, {
  String? boothCookie,
}) async {
  final service = GameDownloadService();
  final cancelToken = CancelToken();
  final state = ValueNotifier<_DownloadDialogState>(
    const _DownloadDialogState(),
  );
  final messenger = ScaffoldMessenger.of(context);
  // Captured up-front so the async closure never touches a WidgetRef that
  // may belong to an already-disposed page.
  final settings = ref.read(downloadSettingsProvider);

  unawaited(() async {
    try {
      final tmpDir = await getTemporaryDirectory();
      final tmpPath =
          '${tmpDir.path}/game_${DateTime.now().millisecondsSinceEpoch}.download';

      final result = await service.download(
        url,
        tmpPath,
        cookieHeader: boothCookie,
        onStatus: (message) => state.value = state.value.copying(message),
        onProgress: (received, total) =>
            state.value = _DownloadDialogState.downloading(
          status: '正在下载…',
          received: received,
          total: total,
        ),
        cancelToken: cancelToken,
      );

      state.value = state.value.copying('正在保存到 '
          '${settings.isAbsolute ? settings.directory : 'Download/${settings.directory}'}…');
      final finalPath = await moveDownloadToDestination(
        result.file.path,
        result.filename,
        settings.directory,
      );
      state.value = _DownloadDialogState.done(finalPath, result.filename);
    } on GameDownloadException catch (e) {
      state.value = _DownloadDialogState.failed('${e.message}');
    } on DioException catch (e) {
      if (CancelToken.isCancel(e)) {
        state.value = _DownloadDialogState.failed('已取消下载');
      } else {
        state.value = _DownloadDialogState.failed('下载失败: ${e.message ?? e}');
      }
    } catch (e) {
      state.value = _DownloadDialogState.failed('下载失败: $e');
    } finally {
      service.dispose();
    }
  }());

  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => ValueListenableBuilder<_DownloadDialogState>(
      valueListenable: state,
      builder: (dialogContext, value, _) => AlertDialog(
        title: value.isDone
            ? const Text('下载完成')
            : value.error != null
                ? const Text('下载未完成')
                : const Text('下载游戏'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              url,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(dialogContext).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            if (value.isDone) ...[
              Text(
                value.filename ?? '游戏文件',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                '已保存到:\n${value.path}',
                style: Theme.of(dialogContext).textTheme.bodySmall,
              ),
            ] else if (value.error != null) ...[
              Text(
                value.error!,
                style: TextStyle(
                  color: Theme.of(dialogContext).colorScheme.error,
                ),
              ),
            ] else ...[
              Text(value.status,
                  style: Theme.of(dialogContext).textTheme.bodySmall),
              const SizedBox(height: 12),
              if (value.total > 0)
                LinearProgressIndicator(value: value.received / value.total)
              else
                const LinearProgressIndicator(),
              const SizedBox(height: 8),
              if (value.total > 0)
                Text(
                  '${(value.received / 1024 / 1024).toStringAsFixed(1)} MB / '
                  '${(value.total / 1024 / 1024).toStringAsFixed(1)} MB',
                  style: Theme.of(dialogContext).textTheme.bodySmall,
                ),
            ],
          ],
        ),
        actions: [
          if (!value.isDone && value.error == null)
            TextButton(
              onPressed: () {
                cancelToken.cancel();
                state.value = const _DownloadDialogState();
                Navigator.of(dialogContext).pop();
              },
              child: const Text('取消'),
            ),
          if (value.error != null)
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('确定'),
            ),
          if (value.isDone) ...[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('关闭'),
            ),
            FilledButton(
              onPressed: () async {
                try {
                  final message =
                      await openDownloadedFile(state.value.path);
                  if (dialogContext.mounted) {
                    Navigator.pop(dialogContext);
                    messenger.showSnackBar(
                      SnackBar(content: Text(message)),
                    );
                  }
                } catch (e) {
                  if (dialogContext.mounted) {
                    messenger.showSnackBar(
                      SnackBar(content: Text('无法打开文件: $e')),
                    );
                  }
                }
              },
              child: const Text('打开'),
            ),
          ],
        ],
      ),
    ),
  );
  // Note: the state notifier is intentionally not disposed here — the
  // download closure may still touch it right after a user cancel, and a
  // disposed ValueNotifier would throw in debug builds. It becomes
  // garbage-collectable once both the dialog and the closure are done.
}

/// Immutable snapshot of the download dialog.
@immutable
class _DownloadDialogState {
  const _DownloadDialogState({
    this.status = '正在解析下载链接…',
    this.received = 0,
    this.total = 0,
    this.error,
    this.donePath,
    this.filename,
  });

  const _DownloadDialogState.downloading({
    required this.status,
    required this.received,
    required this.total,
  })  : error = null,
        donePath = null,
        filename = null;

  final String status;
  final int received;
  final int total;
  final String? error;

  /// Final on-disk path once the download finished.
  final String? donePath;
  final String? filename;

  bool get isDone => donePath != null;

  String get path => donePath ?? '';

  _DownloadDialogState copying(String message) =>
      _DownloadDialogState(status: message);

  static _DownloadDialogState done(String path, String filename) =>
      _DownloadDialogState(
        status: '完成',
        donePath: path,
        filename: filename,
      );

  static _DownloadDialogState failed(String message) =>
      _DownloadDialogState(status: '', error: message);
}
