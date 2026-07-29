import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_constants.dart';
import '../../core/l10n/app_localizations.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/providers/detail_providers.dart';
import '../../core/providers/endpoints_provider.dart';
import '../../core/providers/theme_provider.dart';
import '../../core/theme/title_resolver.dart';
import '../../widgets/section_header.dart';
import '../../widgets/vndb_icons.dart';
import '../vn_detail/list_edit_dialog.dart';

/// A tabbed view of the user's VN list. The top bar shows all available
/// labels (Playing, Finished, Stalled, Dropped, Wishlist, Voted, Blacklist,
/// plus any custom labels) fetched from the API.
class UserListPage extends ConsumerWidget {
  const UserListPage({super.key, this.initialTab});

  /// `'votes'`, `'wishlist'`, `'playing'`, `'finished'`, `'stalled'`,
  /// `'dropped'`, `'blacklist'` or null (all).
  final String? initialTab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authNotifierProvider);
    final l10n = ref.watch(l10nProvider);
    if (!auth.isAuthenticated) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.tr('myList'))),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_outline, size: 48),
              const SizedBox(height: 12),
              Text(l10n.tr('pleaseLogin')),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => context.push('/login'),
                child: Text(l10n.tr('signIn')),
              ),
            ],
          ),
        ),
      );
    }

    final labelsAsync = ref.watch(userLabelsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.tr('myList'))),
      body: labelsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48),
              const SizedBox(height: 12),
              Text('$e'),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => ref.invalidate(userLabelsProvider),
                child: const Text('重试'),
              ),
            ],
          ),
        ),
        data: (apiLabels) {
          // Build the tab list: "All" first, then all predefined labels in a
          // sensible order, then any custom labels from the API.
          final tabs = <_ListTab>[_ListTab(label: '全部', labelId: null)];

          // Predefined labels in display order.
          final predefined = <int?>[
            AppConstants.labelPlaying,
            AppConstants.labelFinished,
            AppConstants.labelStalled,
            AppConstants.labelDropped,
            AppConstants.labelWishlist,
            AppConstants.labelVoted,
            6, // Blacklist (id=6, not defined as a constant)
          ];
          final predefinedNames = <int, String>{
            AppConstants.labelPlaying: '在玩',
            AppConstants.labelFinished: '已完成',
            AppConstants.labelStalled: '搁置',
            AppConstants.labelDropped: '弃坑',
            AppConstants.labelWishlist: '愿望单',
            AppConstants.labelVoted: '已投票',
            6: '黑名单',
          };

          for (final id in predefined) {
            tabs.add(_ListTab(
              label: predefinedNames[id] ?? 'Label $id',
              labelId: id,
            ));
          }

          // Custom labels (id >= 10, excluding predefined ones).
          for (final l in apiLabels) {
            if (predefined.contains(l.id)) continue;
            if (l.id == 0) continue; // skip "no label"
            tabs.add(_ListTab(label: l.label, labelId: l.id));
          }

          // Resolve initial index.
          final initialIndex = switch (initialTab) {
            'playing' => 1,
            'finished' => 2,
            'stalled' => 3,
            'dropped' => 4,
            'wishlist' => 5,
            'votes' => 6,
            'blacklist' => 7,
            _ => 0,
          };
          final clampedIndex =
              initialIndex.clamp(0, tabs.length - 1).toInt();

          return DefaultTabController(
            length: tabs.length,
            initialIndex: clampedIndex,
            child: Column(
              children: [
                TabBar(
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  tabs: [
                    for (final t in tabs) Tab(text: t.label),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: tabs
                        .map((t) => _ListTabView(labelId: t.labelId))
                        .toList(),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ListTab {
  const _ListTab({required this.label, required this.labelId});
  final String label;
  final int? labelId;
}

/// A single tab's paginated list, filtered by [labelId].
class _ListTabView extends ConsumerStatefulWidget {
  const _ListTabView({this.labelId});

  final int? labelId;

  @override
  ConsumerState<_ListTabView> createState() => _ListTabViewState();
}

class _ListTabViewState extends ConsumerState<_ListTabView>
    with AutomaticKeepAliveClientMixin {
  int _page = 1;
  final _items = <dynamic>[];
  bool _hasMore = true;
  bool _loading = false;
  Object? _error;
  String _searchTerm = '';
  final _searchController = TextEditingController();
  Timer? _debounce;

  // ---- 高级筛选状态 (与搜索界面保持一致) ----
  bool _showAdvanced = false;
  String? _language;
  String? _platform;
  String? _releasedFrom;
  String? _releasedTo;
  double _minRating = 0;
  String _sort = 'vote';
  bool _reverse = true;
  final _tagController = TextEditingController();
  final _devController = TextEditingController();
  final _releasedFromController = TextEditingController();
  final _releasedToController = TextEditingController();

  static const _languages = <_DropdownOption>[
    _DropdownOption(label: '全部', value: null),
    _DropdownOption(label: '英语', value: 'en'),
    _DropdownOption(label: '日语', value: 'ja'),
    _DropdownOption(label: '中文', value: 'zh'),
    _DropdownOption(label: '韩语', value: 'ko'),
    _DropdownOption(label: '法语', value: 'fr'),
    _DropdownOption(label: '德语', value: 'de'),
    _DropdownOption(label: '西班牙语', value: 'es'),
    _DropdownOption(label: '俄语', value: 'ru'),
    _DropdownOption(label: '意大利语', value: 'it'),
    _DropdownOption(label: '葡萄牙语', value: 'pt'),
  ];

  static const _platforms = <_DropdownOption>[
    _DropdownOption(label: '全部', value: null),
    _DropdownOption(label: 'Windows', value: 'win'),
    _DropdownOption(label: 'Linux', value: 'lin'),
    _DropdownOption(label: 'macOS', value: 'mac'),
    _DropdownOption(label: 'Android', value: 'and'),
    _DropdownOption(label: 'iOS', value: 'ios'),
    _DropdownOption(label: 'PC-98', value: 'p98'),
    _DropdownOption(label: 'PC-88', value: 'p88'),
    _DropdownOption(label: 'PS2', value: 'ps2'),
    _DropdownOption(label: 'PSP', value: 'psp'),
    _DropdownOption(label: 'PS Vita', value: 'psv'),
    _DropdownOption(label: 'PS3', value: 'ps3'),
    _DropdownOption(label: 'PS4', value: 'ps4'),
    _DropdownOption(label: 'Nintendo Switch', value: 'swi'),
    _DropdownOption(label: 'Nintendo DS', value: 'nds'),
    _DropdownOption(label: 'Nintendo 3DS', value: 'n3ds'),
    _DropdownOption(label: 'Wii', value: 'wii'),
    _DropdownOption(label: 'Wii U', value: 'wiu'),
    _DropdownOption(label: 'Xbox 360', value: 'x360'),
    _DropdownOption(label: 'Xbox One', value: 'xbo'),
    _DropdownOption(label: 'Web', value: 'web'),
    _DropdownOption(label: 'Other', value: 'oth'),
  ];

  /// ulist 排序选项：贝叶斯评分/投票数/发行日期/标题/ID/我的评分。
  static const _sorts = <_SortOption>[
    _SortOption(label: '我的评分', value: 'vote'),
    _SortOption(label: '贝叶斯评分', value: 'rating'),
    _SortOption(label: '投票数', value: 'votecount'),
    _SortOption(label: '发行日期', value: 'released'),
    _SortOption(label: '标题', value: 'title'),
    _SortOption(label: 'ID', value: 'id'),
    _SortOption(label: '添加时间', value: 'added'),
    _SortOption(label: '修改时间', value: 'lastmod'),
    _SortOption(label: '开始日期', value: 'started'),
    _SortOption(label: '完成日期', value: 'finished'),
  ];

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _fetch(reset: true);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    _tagController.dispose();
    _devController.dispose();
    _releasedFromController.dispose();
    _releasedToController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (_searchTerm != value.trim()) {
        _searchTerm = value.trim();
        _fetch(reset: true);
      }
    });
  }

  /// 构造高级筛选的 ulist 兼容 filter 树。
  /// ulist 接受所有 VN 过滤器，但需使用 `['vn','=', [...]]` 包装，
  /// 此处直接平铺到顶层 and 中，因为 VNDB ulist 文档允许使用所有 vn 过滤器。
  Object? _buildExtraFilters() {
    final parts = <List<dynamic>>[];
    if (_searchTerm.isNotEmpty) {
      parts.add(['search', '=', _searchTerm]);
    }
    if (_language != null) parts.add(['lang', '=', _language!]);
    if (_platform != null) parts.add(['platform', '=', _platform!]);
    if (_releasedFrom != null && _releasedFrom!.isNotEmpty) {
      parts.add(['released', '>=', _releasedFrom!]);
    }
    if (_releasedTo != null && _releasedTo!.isNotEmpty) {
      parts.add(['released', '<=', _releasedTo!]);
    }
    if (_minRating > 0) {
      parts.add(['rating', '>=', (_minRating * 10).round()]);
    }
    final tagTerm = _tagController.text.trim();
    if (tagTerm.isNotEmpty) parts.add(['tag', '=', tagTerm]);
    final devTerm = _devController.text.trim();
    if (devTerm.isNotEmpty) parts.add(['developer', '=', devTerm]);
    if (parts.isEmpty) return null;
    if (parts.length == 1) return parts.first;
    return ['and', ...parts];
  }

  bool get _hasAdvancedFilters =>
      _language != null ||
      _platform != null ||
      (_releasedFrom != null && _releasedFrom!.isNotEmpty) ||
      (_releasedTo != null && _releasedTo!.isNotEmpty) ||
      _minRating > 0 ||
      _tagController.text.trim().isNotEmpty ||
      _devController.text.trim().isNotEmpty;

  Future<void> _fetch({bool reset = false}) async {
    final auth = ref.read(authNotifierProvider);
    final userId = auth.user?.id;
    if (userId == null) return;
    if (_loading) return;
    if (reset) {
      _items.clear();
      _page = 1;
      _hasMore = true;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await ref.read(listEndpointProvider).getList(
            userId,
            labelId: widget.labelId,
            sort: _sort,
            reverse: _reverse,
            page: _page,
            extraFilters: _buildExtraFilters(),
          );
      setState(() {
        _items.addAll(result.results);
        _hasMore = result.more;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (!_hasMore || _loading) return;
    _page += 1;
    await _fetch();
  }

  Future<void> _onRefresh() async {
    await _fetch(reset: true);
  }

  void _resetFilters() {
    setState(() {
      _language = null;
      _platform = null;
      _releasedFrom = null;
      _releasedTo = null;
      _minRating = 0;
      _tagController.clear();
      _devController.clear();
      _releasedFromController.clear();
      _releasedToController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search, size: 20),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 20),
                            onPressed: () {
                              _searchController.clear();
                              _searchTerm = '';
                              _fetch(reset: true);
                            },
                          )
                        : null,
                    hintText: '搜索列表中的作品',
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 12),
                  ),
                  onChanged: _onSearchChanged,
                ),
              ),
              IconButton(
                icon: Icon(_showAdvanced
                    ? Icons.expand_less
                    : Icons.filter_list),
                tooltip: '高级筛选',
                onPressed: () =>
                    setState(() => _showAdvanced = !_showAdvanced),
              ),
            ],
          ),
        ),
        if (_showAdvanced) Flexible(child: _buildAdvancedFilters()),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _onRefresh,
            child: _buildBody(),
          ),
        ),
      ],
    );
  }

  /// 高级筛选面板 (与搜索界面保持一致的结构)。
  Widget _buildAdvancedFilters() {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('高级筛选',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const Spacer(),
                TextButton.icon(
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('重置'),
                  onPressed: _resetFilters,
                ),
              ],
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String?>(
              value: _language,
              decoration: const InputDecoration(
                labelText: '语言',
                isDense: true,
                border: OutlineInputBorder(),
              ),
              items: _languages
                  .map((e) => DropdownMenuItem<String?>(
                        value: e.value,
                        child: Text(e.label),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => _language = v),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String?>(
              value: _platform,
              decoration: const InputDecoration(
                labelText: '平台',
                isDense: true,
                border: OutlineInputBorder(),
              ),
              items: _platforms
                  .map((e) => DropdownMenuItem<String?>(
                        value: e.value,
                        child: Text(e.label),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => _platform = v),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _releasedFromController,
                    decoration: const InputDecoration(
                      labelText: '发行起 (YYYY)',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (v) => _releasedFrom =
                        v.trim().isEmpty ? null : v.trim(),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _releasedToController,
                    decoration: const InputDecoration(
                      labelText: '发行止 (YYYY)',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (v) => _releasedTo =
                        v.trim().isEmpty ? null : v.trim(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('最低贝叶斯评分: ${(_minRating * 10).round()}'),
            Slider(
              value: _minRating,
              min: 0,
              max: 10,
              divisions: 9,
              label: '${(_minRating * 10).round()}',
              onChanged: (v) => setState(() => _minRating = v),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _tagController,
              decoration: const InputDecoration(
                labelText: '标签 ID (如 g1)',
                isDense: true,
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.label),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _devController,
              decoration: const InputDecoration(
                labelText: '开发商 ID 或名称 (如 p1)',
                isDense: true,
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.business),
              ),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _sort,
              decoration: const InputDecoration(
                labelText: '排序',
                isDense: true,
                border: OutlineInputBorder(),
              ),
              items: _sorts
                  .map((e) => DropdownMenuItem<String>(
                        value: e.value,
                        child: Text(e.label),
                      ))
                  .toList(),
              onChanged: (v) {
                if (v != null) setState(() => _sort = v);
              },
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              dense: true,
              title: const Text('倒序'),
              value: _reverse,
              onChanged: (v) => setState(() => _reverse = v),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                icon: const Icon(Icons.search),
                label: const Text('应用筛选'),
                onPressed: () => _fetch(reset: true),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_items.isEmpty && _loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_items.isEmpty && _error != null) {
      return ListView(children: [
        const SizedBox(height: 120),
        Center(child: Text('$_error')),
        const SizedBox(height: 12),
        Center(
          child: FilledButton(
            onPressed: () => _fetch(reset: true),
            child: const Text('重试'),
          ),
        ),
      ]);
    }
    if (_items.isEmpty) {
      return ListView(children: [
        const SizedBox(height: 160),
        Center(
            child: Text(_searchTerm.isNotEmpty || _hasAdvancedFilters
                ? '未找到匹配的作品'
                : '列表为空')),
      ]);
    }
    return ListView.builder(
      itemCount: _items.length + (_hasMore ? 1 : 0),
      itemBuilder: (context, i) {
        if (i >= _items.length) {
          _loadMore();
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final entry = _items[i];
        return _ListEntryTile(
          entry: entry,
          onRefresh: _onRefresh,
        );
      },
    );
  }
}

class _DropdownOption {
  const _DropdownOption({required this.label, required this.value});
  final String label;
  final dynamic value;
}

class _SortOption {
  const _SortOption({required this.label, required this.value});
  final String label;
  final String value;
}

class _ListEntryTile extends ConsumerWidget {
  const _ListEntryTile({required this.entry, required this.onRefresh});
  final dynamic entry;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vn = entry.vn;
    final titleMode =
        ref.watch(themeNotifierProvider.select((s) => s.titleDisplay));
    final title = vn == null
        ? entry.id
        : TitleResolver.resolveSimple(
            vn.title as String? ?? entry.id,
            vn.alttitle as String?,
            titleMode,
          );
    final langs = vn?.languages as List<String>? ?? const <String>[];
    final plats = vn?.platforms as List<String>? ?? const <String>[];
    final labels = (entry.labels as List?) ?? const [];

    return Dismissible(
      key: ValueKey(entry.id),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (_) async {
        return await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('移除'),
            content: Text('从列表移除 ${vn?.title ?? "此条目"} 吗？'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('取消'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('移除'),
              ),
            ],
          ),
        );
      },
      onDismissed: (_) async {
        try {
          await ProviderScope.containerOf(context)
              .read(listEndpointProvider)
              .deleteList(entry.id);
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('删除失败: $e')),
            );
          }
        }
        onRefresh();
      },
      child: Card(
        child: ListTile(
          contentPadding: const EdgeInsets.all(8),
          leading: vn?.image?.thumbnail != null
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: CachedNetworkImage(
                    imageUrl: vn!.image!.thumbnail!,
                    width: 48,
                    height: 70,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(
                      width: 48,
                      height: 70,
                      color: Theme.of(context).colorScheme.surface,
                    ),
                    errorWidget: (_, __, ___) => Container(
                      width: 48,
                      height: 70,
                      color: Theme.of(context).colorScheme.surface,
                      child: const Icon(Icons.broken_image, size: 20),
                    ),
                  ),
                )
              : Container(
                  width: 48,
                  height: 70,
                  color: Theme.of(context).colorScheme.surface,
                  child: const Icon(Icons.book),
                ),
          title: Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              // Top row: list status icons + language flags + platform icons.
              if (labels.isNotEmpty ||
                  langs.isNotEmpty ||
                  plats.isNotEmpty)
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    for (final l in labels)
                      if (l.id is int && l.id >= 1 && l.id <= 6)
                        VndbIcons.listImage(l.id as int, size: 16),
                    if (langs.isNotEmpty) VndbIcons.langRow(langs),
                    if (plats.isNotEmpty) VndbIcons.platRow(plats),
                  ],
                ),
              if (entry.vote != null)
                Text('投票: ${(entry.vote / 10).toStringAsFixed(1)}'),
              if (labels.isNotEmpty)
                Wrap(
                  spacing: 4,
                  children: labels
                      .map<Widget>((l) => Chip(
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                            padding: EdgeInsets.zero,
                            label: Text(l.label,
                                style: const TextStyle(fontSize: 10)),
                          ))
                      .toList(),
                ),
              if (entry.notes != null && entry.notes.isNotEmpty)
                Text(entry.notes,
                    maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
          ),
          onTap: () => context.push('/vn/${entry.id}'),
          onLongPress: () => showDialog<void>(
            context: context,
            builder: (_) => ListEditDialog(vnId: entry.id),
          ).then((_) => onRefresh()),
        ),
      ),
    );
  }
}

/// The "profile" / user center tab. Shows the current user's info and links to
/// their lists, or, when [userId] is provided, opens that user's profile.
class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key, this.userId});

  final String? userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authNotifierProvider);
    final uid = userId ?? auth.user?.id;

    if (uid == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('我的')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.person_outline, size: 64),
              const SizedBox(height: 12),
              const Text('未登录'),
              const SizedBox(height: 12),
              FilledButton.icon(
                icon: const Icon(Icons.login),
                label: const Text('登录'),
                onPressed: () => context.push('/login'),
              ),
            ],
          ),
        ),
      );
    }

    final user = auth.user;
    return Scaffold(
      appBar: AppBar(
        title: Text(userId != null ? '用户' : '我的'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: ListView(
        children: [
          const SizedBox(height: 16),
          CircleAvatar(
            radius: 40,
            child: Text(
              (user?.username ?? uid).substring(0, 1).toUpperCase(),
              style: const TextStyle(fontSize: 32),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              user?.username ?? uid,
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          Center(
            child: Text(uid,
                style: Theme.of(context).textTheme.bodySmall),
          ),
          if (user != null) ...[
            const SizedBox(height: 8),
            Center(
              child: Wrap(
                spacing: 8,
                children: [
                  if (user.canReadList)
                    const Chip(label: Text('listread')),
                  if (user.canWriteList)
                    const Chip(label: Text('listwrite')),
                ],
              ),
            ),
          ],
          SectionHeader(title: '我的列表', icon: Icons.bookmark),
          if (userId == null) ...[
            ListTile(
              leading: const Icon(Icons.bookmark),
              title: const Text('我的 VN 列表'),
              onTap: () => context.push('/list'),
            ),
            ListTile(
              leading: const Icon(Icons.star),
              title: const Text('我的投票'),
              onTap: () => context.push('/list?tab=votes'),
            ),
            ListTile(
              leading: const Icon(Icons.card_giftcard),
              title: const Text('我的愿望单'),
              onTap: () => context.push('/list?tab=wishlist'),
            ),
            ListTile(
              leading: const Icon(Icons.history),
              title: const Text('浏览历史'),
              onTap: () => context.push('/history'),
            ),
            ListTile(
              leading: const Icon(Icons.favorite),
              title: const Text('关注列表'),
              onTap: () => context.push('/followed-producers'),
            ),
          ] else
            ListTile(
              leading: const Icon(Icons.public),
              title: const Text('在网页查看'),
              onTap: () => context.push(
                  '/webview?url=${Uri.encodeComponent("https://vndb.org/$uid")}&title=${Uri.encodeComponent("用户资料")}'),
            ),
          SectionHeader(title: '账户', icon: Icons.manage_accounts),
          ListTile(
            leading: const Icon(Icons.person),
            title: const Text('我的资料 (网页)'),
            onTap: () =>
                context.push('/webview?url=${Uri.encodeComponent("https://vndb.org/$uid")}&title=${Uri.encodeComponent("用户资料")}'),
          ),
          if (userId == null)
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('退出登录'),
              onTap: () => _logout(context, ref),
            ),
        ],
      ),
    );
  }

  Future<void> _logout(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('退出登录'),
        content: const Text('确定退出登录吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('退出'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(authNotifierProvider.notifier).logout();
      if (context.mounted) context.go('/home');
    }
  }
}
