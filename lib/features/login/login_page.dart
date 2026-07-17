import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/app_constants.dart';
import '../../core/providers/auth_provider.dart';

/// Page where the user pastes an API token to authenticate.
class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _controller = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _busy = true);
    final ok = await ref.read(authNotifierProvider.notifier).login(
          _controller.text.trim(),
        );
    if (!mounted) return;
    setState(() => _busy = false);
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Token 无效或网络错误')),
      );
    }
    // On success the auth state changes and the router redirects automatically.
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authNotifierProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('登录')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.vpn_key, size: 56),
            const SizedBox(height: 16),
            Text(
              '使用 VNDB API Token 登录',
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              '在你的 VNDB 个人资料 → Applications 页面创建一个 API Token，'
              '然后粘贴到下方。Token 形如 xxxx-xxxxx-xxxxx-xxxx-xxxxx-xxxxx-xxxx。',
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _controller,
              decoration: const InputDecoration(
                labelText: 'API Token',
                hintText: 'xxxx-xxxxx-xxxxx-xxxx-xxxxx-xxxxx-xxxx',
                prefixIcon: Icon(Icons.token),
              ),
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _busy ? null : _submit,
              child: _busy
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('保存 Token'),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              icon: const Icon(Icons.open_in_new),
              label: const Text('前往创建 Token 页面'),
              onPressed: () => launchUrl(
                Uri.parse(AppLinks.tokens),
                mode: LaunchMode.externalApplication,
              ),
            ),
            if (auth.status == AuthStatus.error && auth.error != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.error.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline,
                        color: Theme.of(context).colorScheme.error),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        auth.error.toString(),
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.error),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 12),
            Text(
              '不登录也可以浏览公开的数据库内容。',
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () => Navigator.of(context).maybePop(),
              child: const Text('以游客身份继续'),
            ),
          ],
        ),
      ),
    );
  }
}
