import 'package:flutter/material.dart';
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
      body: InAppWebView(
        initialUrlRequest: URLRequest(url: WebUri(widget.url)),
        initialSettings: InAppWebViewSettings(
          javaScriptEnabled: true,
          domStorageEnabled: true,
          useShouldOverrideUrlLoading: true,
        ),
        onWebViewCreated: (controller) => _controller = controller,
        shouldOverrideUrlLoading: (controller, action) async {
          // Open external (non-vndb) links in the system browser.
          final url = action.request.url;
          if (url != null && !url.toString().contains('vndb.org')) {
            await launchUrl(url, mode: LaunchMode.externalApplication);
            return NavigationActionPolicy.CANCEL;
          }
          return NavigationActionPolicy.ALLOW;
        },
        onLoadStart: (controller, url) {
          setState(() => _loading = true);
        },
        onLoadStop: (controller, url) async {
          await _persistCookies();
          final t = await controller.getTitle();
          final back = await controller.canGoBack();
          final fwd = await controller.canGoForward();
          setState(() {
            _loading = false;
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
    );
  }

  Future<void> _shareCurrent() async {
    final uri = await _controller.getUrl();
    if (uri != null) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
