import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/booth_auth_service.dart';

class BoothLoginPage extends ConsumerStatefulWidget {
  const BoothLoginPage({super.key});

  @override
  ConsumerState<BoothLoginPage> createState() => _BoothLoginPageState();
}

class _BoothLoginPageState extends ConsumerState<BoothLoginPage> {
  InAppWebViewController? _controller;
  bool _busy = false;
  bool _adopted = false;
  bool _exiting = false;
  bool _finishing = false;
  Future<bool>? _inFlight;

  static const _signInUrl = 'https://booth.pm/users/sign_in';

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && !_exiting) _exit();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('登录 BOOTH'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _exiting ? null : _exit,
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () => _controller?.reload(),
            ),
            IconButton(
              tooltip: '我已完成登录',
              icon: const Icon(Icons.done),
              onPressed: _busy || _exiting ? null : _adoptManually,
            ),
          ],
        ),
        body: Column(
          children: [
            Container(
              width: double.infinity,
              color: Colors.amber.shade100,
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    size: 16,
                    color: Colors.amber.shade900,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '注意: 本应用为第三方客户端, 使用 BOOTH 登录与下载可能存在封号风险, 请自行斟酌',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.amber.shade900,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Stack(
                children: [
                  InAppWebView(
                    initialUrlRequest: URLRequest(url: WebUri(_signInUrl)),
                    initialSettings: InAppWebViewSettings(
                      javaScriptEnabled: true,
                      domStorageEnabled: true,
                    ),
                    onWebViewCreated: (controller) =>
                        _controller = controller,
                    onLoadStop: (controller, url) async {
                      final host = url?.host ?? '';
                      if (host.endsWith('booth.pm') &&
                          !_isSignInUrl(url.toString())) {
                        final ok = await _adopt();
                        if (ok && mounted) {
                          _finishWithSuccess();
                        }
                      }
                    },
                  ),
                  if (_busy)
                    const Positioned(
                      left: 0,
                      right: 0,
                      top: 0,
                      child: LinearProgressIndicator(minHeight: 3),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static bool _isSignInUrl(String url) =>
      url.contains('sign_in') || url.contains('login');

  Future<void> _adoptManually() async {
    final ok = await _adopt(
      timeout: const Duration(seconds: 12),
      allowNetworkFallback: true,
    );
    if (!mounted) return;
    if (ok) {
      _finishWithSuccess();
    } else {
      _showMessage('获取账号失败, 请确认已在页面中完成登录');
    }
  }

  Future<void> _exit() async {
    if (_exiting || _finishing) return;
    _exiting = true;
    if (!_adopted) {
      final ok = await _adopt(
        timeout: const Duration(seconds: 8),
        allowNetworkFallback: true,
      );
      if (ok && mounted) {
        _showMessage('获取账号成功');
      } else if (mounted) {
        _showMessage('获取账号失败');
      }
    }
    if (mounted) Navigator.of(context).pop();
  }

  void _finishWithSuccess() {
    if (_finishing) return;
    _finishing = true;
    _adopted = true;
    _showMessage('获取账号成功');
    Future<void>.delayed(const Duration(milliseconds: 700)).then((_) {
      if (mounted) Navigator.of(context).pop();
    });
  }

  Future<bool> _adopt({
    Duration? timeout,
    bool allowNetworkFallback = false,
  }) {
    if (_adopted) return Future.value(true);
    final existing = _inFlight;
    if (existing != null) {
      return timeout == null
          ? existing
          : existing.timeout(timeout, onTimeout: () => _adopted);
    }
    setState(() => _busy = true);
    final task = _doAdopt(allowNetworkFallback: allowNetworkFallback);
    _inFlight = task;
    task.whenComplete(() {
      _inFlight = null;
      if (mounted) setState(() => _busy = false);
    });
    return timeout == null ? task : task.timeout(timeout, onTimeout: () => _adopted);
  }

  Future<bool> _doAdopt({required bool allowNetworkFallback}) async {
    try {
      final controller = _controller;
      if (controller == null) return false;
      final ok = await _adoptFromWebview(
        controller,
        allowNetworkFallback: allowNetworkFallback,
      );
      if (ok) _adopted = true;
      return ok;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _adoptFromWebview(
    InAppWebViewController controller, {
    required bool allowNetworkFallback,
  }) async {
    var pageSaysLoggedIn = false;
    try {
      final result = await controller.evaluateJavascript(
        source:
            "document.querySelector('a[href*=\"sign_in\"]') === null",
      );
      pageSaysLoggedIn = result == true || result == 'true';
    } catch (_) {
    }

    if (!pageSaysLoggedIn && !allowNetworkFallback) return false;

    final cm = CookieManager.instance();
    final cookies = await cm.getCookies(url: WebUri('https://booth.pm/'));
    final pairs = cookies
        .map((c) => '${c.name}=${c.value}')
        .where((p) => p.contains('='))
        .toList();

    return ref
        .read(boothAuthProvider.notifier)
        .adoptWebviewCookies(pairs, pageSaysLoggedIn: pageSaysLoggedIn);
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}
