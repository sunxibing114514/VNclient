import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/app_constants.dart';
import '../../core/l10n/app_localizations.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/providers/locale_provider.dart';
import '../../core/providers/theme_provider.dart';
import '../../core/services/update_checker.dart';
import '../../core/theme/app_backgrounds.dart';

/// Settings page: token management, appearance, language, WebView login, links.
class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  static const _storage = FlutterSecureStorage();
  final _userController = TextEditingController();
  final _passController = TextEditingController();
  bool _checkingUpdate = false;
  UpdateResult? _updateResult;

  @override
  void initState() {
    super.initState();
    _loadCredentials();
  }

  @override
  void dispose() {
    _userController.dispose();
    _passController.dispose();
    super.dispose();
  }

  Future<void> _loadCredentials() async {
    final user = await _storage.read(key: 'vndb_web_user') ?? '';
    final pass = await _storage.read(key: 'vndb_web_pass') ?? '';
    _userController.text = user;
    _passController.text = pass;
  }

  Future<void> _saveCredentials() async {
    await _storage.write(key: 'vndb_web_user', value: _userController.text);
    await _storage.write(key: 'vndb_web_pass', value: _passController.text);
    if (mounted) {
      final l10n = ref.read(l10nProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.tr('savedCredentials'))),
      );
    }
  }

  Future<void> _checkForUpdates() async {
    setState(() {
      _checkingUpdate = true;
      _updateResult = null;
    });
    final result = await ref.read(updateCheckerProvider).check();
    if (mounted) {
      setState(() {
        _checkingUpdate = false;
        _updateResult = result;
      });
      if (result.isError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result.error!)),
        );
      } else if (result.hasUpdate) {
        _showUpdateDialog(result);
      } else if (!result.isError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已是最新版本 (${result.currentVersion})')),
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
            Text('当前版本: ${result.currentVersion}'),
            Text('最新版本: ${result.latestVersion}'),
            if (result.releaseNotes != null &&
                result.releaseNotes!.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text(
                '更新内容:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
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
              launchUrl(Uri.parse(url),
                  mode: LaunchMode.externalApplication);
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authNotifierProvider);
    final l10n = ref.watch(l10nProvider);
    final theme = ref.watch(themeNotifierProvider);
    final locale = ref.watch(localeNotifierProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.tr('settings'))),
      body: ListView(
        children: [
          _SectionTitle(l10n.tr('account')),
          ListTile(
            leading: const Icon(Icons.vpn_key),
            title: Text(l10n.tr('apiToken')),
            subtitle: Text(auth.isAuthenticated
                ? '${l10n.tr("loggedIn")}: ${auth.user?.username} (${auth.user?.id})'
                : l10n.tr('notLoggedIn')),
            trailing: auth.isAuthenticated
                ? TextButton(
                    onPressed: () async {
                      await ref
                          .read(authNotifierProvider.notifier)
                          .logout();
                      if (context.mounted) context.go('/home');
                    },
                    child: Text(l10n.tr('logout')),
                  )
                : TextButton(
                    onPressed: () => context.push('/login'),
                    child: Text(l10n.tr('signIn')),
                  ),
          ),
          const Divider(),
          _SectionTitle(l10n.tr('appearance')),
          ListTile(
            leading: const Icon(Icons.palette),
            title: Text(l10n.tr('seedColor')),
            subtitle: theme.backgroundId != 'none'
                ? const Text('跟随背景主题', style: TextStyle(fontSize: 11))
                : null,
            trailing: _ColorIndicator(
              color: theme.effectiveSeedColor,
              onTap: () => _pickColor(context, theme.effectiveSeedColor),
            ),
            onTap: () => _pickColor(context, theme.effectiveSeedColor),
          ),
          ListTile(
            leading: const Icon(Icons.brightness_6),
            title: Text(l10n.tr('themeMode')),
            trailing: DropdownButton<ThemeMode>(
              value: theme.mode,
              underline: const SizedBox(),
              items: [
                DropdownMenuItem(
                  value: ThemeMode.dark,
                  child: Text(l10n.tr('dark')),
                ),
                DropdownMenuItem(
                  value: ThemeMode.light,
                  child: Text(l10n.tr('light')),
                ),
                DropdownMenuItem(
                  value: ThemeMode.system,
                  child: Text(l10n.tr('system')),
                ),
              ],
              onChanged: (m) {
                if (m != null) {
                  ref.read(themeNotifierProvider.notifier).setMode(m);
                }
              },
            ),
          ),
          ListTile(
            leading: const Icon(Icons.wallpaper),
            title: const Text('背景主题'),
            subtitle: Text(theme.background.displayName),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _pickBackground(context, theme.backgroundId),
          ),
          ListTile(
            leading: const Icon(Icons.title),
            title: const Text('作品名显示'),
            subtitle: Text(theme.titleDisplay == TitleDisplayMode.japanese
                ? '日文/原名'
                : '罗马音'),
            trailing: DropdownButton<TitleDisplayMode>(
              value: theme.titleDisplay,
              underline: const SizedBox(),
              items: const [
                DropdownMenuItem(
                  value: TitleDisplayMode.romanized,
                  child: Text('罗马音'),
                ),
                DropdownMenuItem(
                  value: TitleDisplayMode.japanese,
                  child: Text('日文/原名'),
                ),
              ],
              onChanged: (m) {
                if (m != null) {
                  ref
                      .read(themeNotifierProvider.notifier)
                      .setTitleDisplay(m);
                }
              },
            ),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.blur_on),
            title: const Text('模糊色情图片'),
            subtitle: const Text('默认对色情/暴力图片进行模糊处理'),
            value: theme.blurNsfw,
            onChanged: (v) =>
                ref.read(themeNotifierProvider.notifier).setBlurNsfw(v),
          ),
          const Divider(),
          _SectionTitle(l10n.tr('language')),
          ListTile(
            leading: const Icon(Icons.language),
            title: Text(l10n.tr('language')),
            trailing: DropdownButton<Locale>(
              value: locale,
              underline: const SizedBox(),
              items: [
                DropdownMenuItem(
                  value: const Locale('zh'),
                  child: Text(l10n.tr('chinese')),
                ),
                DropdownMenuItem(
                  value: const Locale('en'),
                  child: Text(l10n.tr('english')),
                ),
              ],
              onChanged: (l) {
                if (l != null) {
                  ref.read(localeNotifierProvider.notifier).setLocale(l);
                }
              },
            ),
          ),
          const Divider(),
          _SectionTitle(l10n.tr('webViewLogin')),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              l10n.tr('webViewLoginDesc'),
              style: const TextStyle(fontSize: 12),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  controller: _userController,
                  decoration: InputDecoration(
                    labelText: l10n.tr('username'),
                    prefixIcon: const Icon(Icons.person),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _passController,
                  decoration: InputDecoration(
                    labelText: l10n.tr('password'),
                    prefixIcon: const Icon(Icons.lock),
                  ),
                  obscureText: true,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    FilledButton.icon(
                      icon: const Icon(Icons.save),
                      label: Text(l10n.tr('saveCredentials')),
                      onPressed: _saveCredentials,
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.open_in_browser),
                      label: Text(l10n.tr('openWebLogin')),
                      onPressed: () => context.push(
                        '/webview?url=${Uri.encodeComponent("https://vndb.org/u/login")}&title=${Uri.encodeComponent(l10n.tr("signIn"))}'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(),
          _SectionTitle(l10n.tr('about')),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('当前版本'),
            subtitle: Text('v${AppConstants.appVersion}'),
          ),
          ListTile(
            leading: _checkingUpdate
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: Padding(
                      padding: EdgeInsets.all(2),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : const Icon(Icons.system_update),
            title: const Text('检查更新'),
            subtitle: _updateResult != null && _updateResult!.hasUpdate
                ? Text('新版本可用: v${_updateResult!.latestVersion}',
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.primary))
                : null,
            trailing: _checkingUpdate
                ? null
                : const Icon(Icons.chevron_right),
            onTap: _checkingUpdate ? null : _checkForUpdates,
          ),
          ListTile(
            leading: const Icon(Icons.info),
            title: Text(l10n.tr('aboutClient')),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/about'),
          ),
          ListTile(
            leading: const Icon(Icons.code),
            title: const Text('GitHub'),
            subtitle: const Text('sunxibing114514/VNclient'),
            onTap: () => launchUrl(Uri.parse(AppLinks.github),
                mode: LaunchMode.externalApplication),
          ),
          ListTile(
            leading: const Icon(Icons.book),
            title: Text(l10n.tr('apiDocs')),
            onTap: () => context.push(
                '/webview?url=${Uri.encodeComponent(AppLinks.apiDocs)}&title=${Uri.encodeComponent(l10n.tr("apiDocs"))}'),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Future<void> _pickColor(BuildContext context, Color current) async {
    final l10n = ref.read(l10nProvider);
    final presets = <Color>[
      const Color(0xFFf59e0b), // VNDB orange
      const Color(0xFF6366f1), // Indigo
      const Color(0xFFec4899), // Pink
      const Color(0xFF10b981), // Emerald
      const Color(0xFF3b82f6), // Blue
      const Color(0xFFef4444), // Red
      const Color(0xFF8b5cf6), // Violet
      const Color(0xFF14b8a6), // Teal
      const Color(0xFFf97316), // Orange
      const Color(0xFF84cc16), // Lime
      const Color(0xFF06b6d4), // Cyan
      const Color(0xFFeab308), // Yellow
    ];

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        Color selected = current;
        return StatefulBuilder(
          builder: (ctx, setState) => AlertDialog(
            title: Text(l10n.tr('seedColor')),
            content: SizedBox(
              width: 280,
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                children: presets
                    .map((c) => GestureDetector(
                          onTap: () => setState(() => selected = c),
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: c,
                              shape: BoxShape.circle,
                              border: selected.toARGB32() == c.toARGB32()
                                  ? Border.all(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface,
                                      width: 3,
                                    )
                                  : null,
                            ),
                          ),
                        ))
                    .toList(),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(l10n.tr('cancel')),
              ),
              FilledButton(
                onPressed: () {
                  ref
                      .read(themeNotifierProvider.notifier)
                      .setSeedColor(selected);
                  Navigator.pop(ctx);
                },
                child: Text(l10n.tr('save')),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickBackground(BuildContext context, String currentId) async {
    final l10n = ref.read(l10nProvider);
    await showDialog<void>(
      context: context,
      builder: (ctx) {
        String selected = currentId;
        return StatefulBuilder(
          builder: (ctx, setState) => AlertDialog(
            title: const Text('选择背景主题'),
            contentPadding: const EdgeInsets.symmetric(vertical: 8),
            content: SizedBox(
              width: 320,
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final bg in AppBackgrounds.all)
                    _backgroundTile(
                      context: ctx,
                      bg: bg,
                      selected: selected,
                      onTap: () => setState(() => selected = bg.id),
                    ),
                  // Custom image option (dynamic, shows preview if active).
                  _backgroundTile(
                    context: ctx,
                    bg: AppBackgrounds.custom(
                      ref.read(themeNotifierProvider).customBackgroundPath ??
                          '',
                    ),
                    selected: selected,
                    onTap: () async {
                      Navigator.pop(ctx);
                      await _pickCustomImage();
                    },
                    isCustom: true,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(l10n.tr('cancel')),
              ),
              FilledButton(
                onPressed: () {
                  ref
                      .read(themeNotifierProvider.notifier)
                      .setBackground(selected);
                  Navigator.pop(ctx);
                },
                child: Text(l10n.tr('save')),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Builds a single selectable background tile.
  Widget _backgroundTile({
    required BuildContext context,
    required AppBackground bg,
    required String selected,
    required VoidCallback onTap,
    bool isCustom = false,
  }) {
    final isSelected = bg.id == selected;
    Widget? leading;
    if (isCustom) {
      final path = ref.read(themeNotifierProvider).customBackgroundPath;
      leading = ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: SizedBox(
          width: 40,
          height: 40,
          child: (path != null && path.isNotEmpty && File(path).existsSync())
              ? Image.file(File(path), fit: BoxFit.cover)
              : Container(
                  color: bg.seedColor,
                  child: const Icon(Icons.add_photo_alternate,
                      color: Colors.white, size: 20),
                ),
        ),
      );
    } else {
      leading = ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: SizedBox(
          width: 40,
          height: 40,
          child: bg.asset.isEmpty
              ? Container(
                  color: bg.seedColor,
                  child: const Icon(Icons.texture,
                      color: Colors.white, size: 20),
                )
              : Image.asset(bg.asset, fit: BoxFit.cover),
        ),
      );
    }
    return ListTile(
      leading: leading,
      title: Text(bg.displayName),
      subtitle: Text(
        isCustom
            ? '从相册选择自定义图片'
            : '${_brightnessLabel(bg.brightness)} · #${bg.seedColor.toARGB32().toRadixString(16).padLeft(8, '0').toUpperCase()}',
        style: const TextStyle(fontSize: 11),
      ),
      trailing: isSelected
          ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary)
          : null,
      onTap: onTap,
    );
  }

  /// Opens the system image picker, copies the picked file into the app's
  /// documents directory, and activates it as the background theme.
  Future<void> _pickCustomImage() async {
    final picker = ImagePicker();
    try {
      final xFile = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 90,
      );
      if (xFile == null) return;
      await ref
          .read(themeNotifierProvider.notifier)
          .setCustomBackground(File(xFile.path));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已设置自定义背景')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('选择图片失败: $e')),
        );
      }
    }
  }

  String _brightnessLabel(Brightness b) =>
      b == Brightness.dark ? '黑暗' : '明亮';
}

class _ColorIndicator extends StatelessWidget {
  const _ColorIndicator({required this.color, this.onTap});
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: Theme.of(context).colorScheme.outline,
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Text(
        text,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }
}
