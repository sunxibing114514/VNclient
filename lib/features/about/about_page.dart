import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/app_constants.dart';
import '../../core/services/update_checker.dart';

/// About page with client info, version, update check, and links.
class AboutPage extends ConsumerStatefulWidget {
  const AboutPage({super.key});

  @override
  ConsumerState<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends ConsumerState<AboutPage> {
  bool _checkingUpdate = false;

  Future<void> _checkForUpdates() async {
    setState(() => _checkingUpdate = true);
    final result = await ref.read(updateCheckerProvider).check();
    if (mounted) {
      setState(() => _checkingUpdate = false);
      if (result.isError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result.error!)),
        );
      } else if (result.hasUpdate) {
        _showUpdateDialog(result);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已是最新版本 (v${result.currentVersion})')),
        );
      }
    }
  }

  void _showUpdateDialog(UpdateResult result) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('发现新版本'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('当前版本: v${result.currentVersion}'),
            Text('最新版本: v${result.latestVersion}'),
            if (result.releaseNotes != null &&
                result.releaseNotes!.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text('更新内容:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(
                result.releaseNotes!,
                style: const TextStyle(fontSize: 13),
                maxLines: 8,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('稍后再说'),
          ),
          FilledButton.icon(
            icon: const Icon(Icons.download),
            label: const Text('前往下载'),
            onPressed: () {
              Navigator.pop(ctx);
              final url = result.releaseUrl ?? AppLinks.latestReleaseUrl;
              launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('关于')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Icon(Icons.book, size: 72),
          const SizedBox(height: 16),
          Text(
            'VNDB Client',
            style: Theme.of(context).textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            '版本 v${AppConstants.appVersion}',
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          FilledButton.tonalIcon(
            onPressed: _checkingUpdate ? null : _checkForUpdates,
            icon: _checkingUpdate
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.system_update),
            label: const Text('检查更新'),
          ),
          const SizedBox(height: 24),
          const Text(
            '一个非官方的 VNDB (Visual Novel Database) Flutter 客户端，'
            '基于 VNDB Kana API v2 实现，并通过内嵌 WebView 衔接 API 暂未支持的社交与编辑功能。',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          const _AboutTile(
            icon: Icons.code,
            title: 'GitHub',
            subtitle: 'sunxibing114514/VNclient',
            url: AppLinks.github,
          ),
          const _AboutTile(
            icon: Icons.public,
            title: 'VNDB 官网',
            subtitle: 'vndb.org',
            url: AppConstants.siteBaseUrl,
          ),
          const _AboutTile(
            icon: Icons.api,
            title: 'API 文档',
            subtitle: 'VNDB Kana API',
            url: AppLinks.apiDocs,
          ),
          const _AboutTile(
            icon: Icons.new_releases_outlined,
            title: '最新发布',
            subtitle: 'GitHub Releases',
            url: AppLinks.latestReleaseUrl,
          ),
          const SizedBox(height: 24),
          Text(
            '数据来源: VNDB.org · 数据许可见官网\n'
            '本客户端不附属于 VNDB，所有数据版权归原网站及贡献者所有。',
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _AboutTile extends StatelessWidget {
  const _AboutTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.url,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String url;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.open_in_new),
      onTap: () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
    );
  }
}
