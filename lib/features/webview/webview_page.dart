import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/app_constants.dart';

/// A reusable WebView page used for every non-API feature (forums, edits,
/// profile, FAQ, etc.).
///
/// Cookies are persisted to [FlutterSecureStorage] so that a single login in
/// the WebView keeps the user signed in across all WebView screens.
class WebViewPage extends ConsumerStatefulWidget {
  const WebViewPage({
    super.key,
    required this.url,
    this.title,
  });

  final String url;
  final String? title;

  @override
  ConsumerState<WebViewPage> createState() => _WebViewPageState();
}

class _WebViewPageState extends ConsumerState<WebViewPage> {
  late final InAppWebViewController _controller;
  String _title = '';
  bool _loading = true;
  bool _canGoBack = false;
  bool _canGoForward = false;
  double _progress = 0;
  String? _loadError;

  static const _storage = FlutterSecureStorage();
  static const _cookieKey = 'vndb_web_cookies';

  @override
  void initState() {
    super.initState();
    _title = widget.title ?? '加载中…';
    _restoreCookies();
  }

  Future<void> _restoreCookies() async {
    try {
      final raw = await _storage.read(key: _cookieKey);
      if (raw == null) return;
      final cm = CookieManager.instance();
      final cookies = raw.split(';').map((c) => c.trim()).where((c) => c.isNotEmpty);
      final uri = Uri.parse(AppConstants.siteBaseUrl);
      for (final c in cookies) {
        final eq = c.indexOf('=');
        if (eq <= 0) continue;
        final name = c.substring(0, eq);
        final value = c.substring(eq + 1);
        await cm.setCookie(
          url: WebUri(uri.toString()),
          name: name,
          value: value,
          domain: '.vndb.org',
          isSecure: true,
        );
      }
    } catch (_) {
      // Cookie restoration is best-effort.
    }
  }

  Future<void> _persistCookies() async {
    try {
      final cm = CookieManager.instance();
      final cookies = await cm.getCookies(
        url: WebUri(AppConstants.siteBaseUrl),
      );
      if (cookies.isEmpty) return;
      final raw = cookies.map((c) => '${c.name}=${c.value}').join('; ');
      await _storage.write(key: _cookieKey, value: raw);
    } catch (_) {
      // Best-effort persistence.
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (_canGoBack) {
              _controller.goBack();
            } else {
              Navigator.of(context).maybePop();
            }
          },
        ),
        title: Text(
          _title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.arrow_forward),
            onPressed: _canGoForward ? () => _controller.goForward() : null,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _controller.reload(),
          ),
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () => _shareCurrent(),
          ),
        ],
        bottom: _loading
            ? PreferredSize(
                preferredSize: const Size.fromHeight(2),
                child: LinearProgressIndicator(value: _progress == 0 ? null : _progress),
              )
            : null,
      ),
      body: Stack(
        children: [
          InAppWebView(
        initialUrlRequest: URLRequest(url: WebUri(widget.url)),
        initialSettings: InAppWebViewSettings(
          javaScriptEnabled: true,
          domStorageEnabled: true,
          useShouldOverrideUrlLoading: true,
        ),
        onWebViewCreated: (controller) => _controller = controller,
        shouldOverrideUrlLoading: (controller, action) async {
          final url = action.request.url;
          if (url != null && !url.toString().contains('vndb.org')) {
            try {
              final ok =
                  await launchUrl(url, mode: LaunchMode.externalApplication);
              if (ok) return NavigationActionPolicy.CANCEL;
            } catch (_) {}
            return NavigationActionPolicy.ALLOW;
          }
          return NavigationActionPolicy.ALLOW;
        },
        onLoadError: (controller, url, code, description) {
          if (url.toString() == widget.url) {
            setState(() {
              _loadError = '加载失败 ($code): $description';
              _loading = false;
            });
          }
        },
        onReceivedError: (controller, request, error) {
          if (request.url.toString() == widget.url &&
              !request.isForMainFrame!) {
            return;
          }
          if (request.isForMainFrame == true) {
            setState(() {
              _loadError = '加载失败 (${error.type}): ${error.description}';
              _loading = false;
            });
          }
        },
        onLoadStart: (controller, url) {
          setState(() {
            _loading = true;
            _loadError = null;
          });
        },
        onLoadStop: (controller, url) async {
          await _persistCookies();
          final t = await controller.getTitle();
          final back = await controller.canGoBack();
          final fwd = await controller.canGoForward();
          setState(() {
            _loading = false;
            _loadError = null;
            if (t != null && t.isNotEmpty) _title = t;
            _canGoBack = back;
            _canGoForward = fwd;
          });
        },
        onProgressChanged: (controller, progress) {
          setState(() => _progress = progress / 100);
        },
        onTitleChanged: (controller, title) {
          if (title != null && title.isNotEmpty) {
            setState(() => _title = title);
          }
        },
          ),
          if (_loadError != null)
            Positioned.fill(
              child: Container(
                color: Theme.of(context).colorScheme.surface,
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.wifi_off,
                          size: 48, color: Theme.of(context).colorScheme.error),
                      const SizedBox(height: 12),
                      Text(
                        _loadError!,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.url,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 8,
                        children: [
                          FilledButton.icon(
                            icon: const Icon(Icons.refresh),
                            label: const Text('重试'),
                            onPressed: () => _controller.reload(),
                          ),
                          OutlinedButton.icon(
                            icon: const Icon(Icons.content_copy),
                            label: const Text('复制链接'),
                            onPressed: () {
                              Clipboard.setData(
                                  ClipboardData(text: widget.url));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('链接已复制')),
                              );
                            },
                          ),
                          OutlinedButton.icon(
                            icon: const Icon(Icons.open_in_browser),
                            label: const Text('浏览器打开'),
                            onPressed: () async {
                              try {
                                await launchUrl(Uri.parse(widget.url),
                                    mode: LaunchMode.externalApplication);
                              } catch (_) {}
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _shareCurrent() async {
    final uri = await _controller.getUrl();
    if (uri != null) {
      try {
        final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
        if (!ok) {
          Clipboard.setData(ClipboardData(text: uri.toString()));
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('无法打开外部浏览器, 链接已复制')),
            );
          }
        }
      } catch (_) {
        Clipboard.setData(ClipboardData(text: uri.toString()));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('无法打开外部浏览器, 链接已复制')),
          );
        }
      }
    }
  }
}
