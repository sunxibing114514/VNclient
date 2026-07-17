import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/endpoints/vn_endpoint.dart';
import '../../core/models/vn.dart';
import '../../core/providers/endpoints_provider.dart';
import '../../widgets/vn_card.dart';

/// The database entry type to search against.
enum SearchTarget {
  vn('VN 作品', '/vn', Icons.book),
  character('角色', '/character', Icons.person),
  producer('制作商', '/producer', Icons.business),
  staff('制作人员', '/staff', Icons.people),
  release('发行版本', '/release', Icons.album),
  tag('标签', '/tag', Icons.label),
  trait('特质', '/trait', Icons.category);

  const SearchTarget(this.label, this.route, this.icon);
  final String label;
  final String route;
  final IconData icon;
}

/// Search page with a selectable search target (VN / character / producer /
/// staff / release / tag / trait), free-text search, advanced VN filter
/// builder and compact filter-string paste support.
class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({super.key, this.initialTarget});

  final SearchTarget? initialTarget;

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  late SearchTarget _target =
      widget.initialTarget ?? SearchTarget.vn;
  final _termController = TextEditingController();
  final _compactController = TextEditingController();
  final _scrollController = ScrollController();

  final List<dynamic> _items = [];
  bool _hasMore = true;
  bool _loading = false;
  Object? _error;
  int _page = 1;
  Object? _activeFilters;
  bool _showAdvanced = false;

  // Advanced filter state (VN only)
  String? _language;
  String? _platform;
  String? _releasedFrom;
  String? _releasedTo;
  double _minRating = 0;
  String _sort = 'searchrank';
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

  static const _sorts = <_SortOption>[
    _SortOption(label: '搜索相关度', value: 'searchrank'),
    _SortOption(label: '评分', value: 'rating'),
    _SortOption(label: '投票数', value: 'votecount'),
    _SortOption(label: '发行日期', value: 'released'),
    _SortOption(label: '标题', value: 'title'),
    _SortOption(label: 'ID', value: 'id'),
  ];

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _termController.dispose();
    _compactController.dispose();
    _scrollController.dispose();
    _tagController.dispose();
    _devController.dispose();
    _releasedFromController.dispose();
    _releasedToController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_loading &&
        _hasMore) {
      _loadMore();
    }
  }

  /// Switch the active search target, clearing any in-flight results.
  void _switchTarget(SearchTarget target) {
    if (target == _target) return;
    setState(() {
      _target = target;
      _items.clear();
      _hasMore = true;
      _error = null;
      _activeFilters = null;
      _page = 1;
      _showAdvanced = false;
    });
  }

  /// Build the active filters object based on the current filter state (VN).
  Object? _buildFilters() {
    if (_compactController.text.trim().isNotEmpty) {
      return _compactController.text.trim();
    }
    final parts = <List<dynamic>>[];
    final term = _termController.text.trim();
    if (term.isNotEmpty) {
      parts.add(['search', '=', term]);
    }
    if (_language != null) {
      parts.add(['lang', '=', _language!]);
    }
    if (_platform != null) {
      parts.add(['platform', '=', _platform!]);
    }
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
    if (tagTerm.isNotEmpty) {
      parts.add(['tag', '=', tagTerm]);
    }
    final devTerm = _devController.text.trim();
    if (devTerm.isNotEmpty) {
      parts.add(['developer', '=', devTerm]);
    }
    if (parts.isEmpty) return <Object>[];
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

  Future<void> _runSearch() async {
    setState(() {
      _items.clear();
      _page = 1;
      _hasMore = true;
      _error = null;
      if (_target == SearchTarget.vn) {
        _activeFilters = _buildFilters();
      } else {
        // For non-VN targets, the search term is the filter.
        final term = _termController.text.trim();
        _activeFilters = term.isEmpty ? null : ['search', '=', term];
      }
    });
    await _fetch();
  }

  Future<void> _loadMore() async {
    _page += 1;
    await _fetch();
  }

  Future<void> _fetch() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final hasCompact = _target == SearchTarget.vn &&
          _compactController.text.trim().isNotEmpty;
      final dynamic result = await _runQuery(
        compactFilters: hasCompact,
      );
      setState(() {
        _items.addAll(result.results as List);
        _hasMore = result.more as bool;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  /// Dispatches the query to the endpoint matching the current [_target].
  Future<dynamic> _runQuery({bool compactFilters = false}) async {
    final filters = _activeFilters;
    switch (_target) {
      case SearchTarget.vn:
        return ref.read(vnEndpointProvider).query(
              filters: filters,
              fields: VnEndpoint.listFields,
              sort: _sort,
              reverse: _sort == 'rating' ||
                  _sort == 'votecount' ||
                  _sort == 'released' ||
                  _sort == 'id',
              results: 20,
              page: _page,
              compactFilters: compactFilters,
              normalizedFilters: compactFilters,
            );
      case SearchTarget.character:
        return ref.read(characterEndpointProvider).query(
              filters: filters,
              fields:
                  'name, original, image{id,url,dims,sexual,violence}, vns{role,id,title}',
              sort: 'searchrank',
              results: 20,
              page: _page,
            );
      case SearchTarget.producer:
        return ref.read(producerEndpointProvider).query(
              filters: filters,
              fields: 'name, original, lang, type',
              sort: 'searchrank',
              results: 20,
              page: _page,
            );
      case SearchTarget.staff:
        // Always include ismain=1 to deduplicate aliases.
        final f = filters == null
            ? ['ismain', '=', 1]
            : (filters is List && filters.isNotEmpty && filters.first == 'and'
                ? ['and', ...filters.sublist(1), ['ismain', '=', 1]]
                : ['and', filters, ['ismain', '=', 1]]);
        return ref.read(staffEndpointProvider).query(
              filters: f,
              fields: 'aid, ismain, name, original, lang, gender',
              sort: 'searchrank',
              results: 20,
              page: _page,
            );
      case SearchTarget.release:
        return ref.read(releaseEndpointProvider).query(
              filters: filters,
              fields:
                  'title, alttitle, released, platforms, official, freeware',
              sort: 'searchrank',
              results: 20,
              page: _page,
            );
      case SearchTarget.tag:
        return ref.read(tagEndpointProvider).query(
              filters: filters,
              fields: 'name, category, vn_count, searchable',
              sort: 'searchrank',
              results: 20,
              page: _page,
            );
      case SearchTarget.trait:
        return ref.read(traitEndpointProvider).query(
              filters: filters,
              fields:
                  'name, group_id, group_name, char_count, searchable, sexual',
              sort: 'searchrank',
              results: 20,
              page: _page,
            );
    }
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
    return Scaffold(
      appBar: AppBar(title: const Text('搜索')),
      body: Column(
        children: [
          // Target selector
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: _buildTargetSelector(),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                TextField(
                  controller: _termController,
                  decoration: InputDecoration(
                    hintText: _searchHint(),
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.search),
                      onPressed: _runSearch,
                    ),
                  ),
                  onSubmitted: (_) => _runSearch(),
                ),
                if (_target == SearchTarget.vn) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _compactController,
                          decoration: const InputDecoration(
                            hintText: '或粘贴 compact filter 字符串',
                            isDense: true,
                            prefixIcon: Icon(Icons.code),
                          ),
                          onSubmitted: (_) => _runSearch(),
                        ),
                      ),
                      IconButton(
                        icon: Icon(_showAdvanced
                            ? Icons.expand_less
                            : Icons.expand_more),
                        tooltip: '高级筛选',
                        onPressed: () => setState(
                            () => _showAdvanced = !_showAdvanced),
                      ),
                    ],
                  ),
                  if (_showAdvanced) _buildAdvancedFilters(),
                ],
              ],
            ),
          ),
          Expanded(child: _buildList()),
        ],
      ),
    );
  }

  String _searchHint() {
    switch (_target) {
      case SearchTarget.vn:
        return '搜索 VN 标题、别名、发行版本…';
      case SearchTarget.character:
        return '搜索角色名、别名…';
      case SearchTarget.producer:
        return '搜索制作商名称…';
      case SearchTarget.staff:
        return '搜索制作人员名、别名…';
      case SearchTarget.release:
        return '搜索发行版本标题…';
      case SearchTarget.tag:
        return '搜索标签名、别名…';
      case SearchTarget.trait:
        return '搜索特质名、别名…';
    }
  }

  Widget _buildTargetSelector() {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: SearchTarget.values.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final t = SearchTarget.values[i];
          final selected = t == _target;
          return FilterChip(
            avatar: Icon(t.icon, size: 16),
            label: Text(t.label),
            selected: selected,
            onSelected: (_) => _switchTarget(t),
          );
        },
      ),
    );
  }

  Widget _buildAdvancedFilters() {
    return Card(
      child: Padding(
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
            Text('最低评分: ${(_minRating * 10).round()}'),
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
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                icon: const Icon(Icons.search),
                label: const Text('搜索'),
                onPressed: _runSearch,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList() {
    if (_items.isEmpty && !_loading && _error == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.search, size: 56),
            const SizedBox(height: 12),
            Text('输入关键词开始搜索',
                style: Theme.of(context).textTheme.bodyMedium),
            if (_hasAdvancedFilters) ...[
              const SizedBox(height: 8),
              Text('已有高级筛选条件',
                  style: Theme.of(context).textTheme.bodySmall),
            ],
          ],
        ),
      );
    }
    if (_error != null && _items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48),
            const SizedBox(height: 8),
            Text('$_error'),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _runSearch,
              child: const Text('重试'),
            ),
          ],
        ),
      );
    }
    return ListView.builder(
      controller: _scrollController,
      itemCount: _items.length + (_hasMore ? 1 : 0),
      itemBuilder: (context, i) {
        if (i >= _items.length) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        return _buildResultTile(_items[i]);
      },
    );
  }

  /// Builds a result tile appropriate for the current search target.
  Widget _buildResultTile(dynamic item) {
    switch (_target) {
      case SearchTarget.vn:
        final vn = item as Vn;
        return VnCard(
          vn: vn,
          onTap: () => context.push('/vn/${vn.id}'),
        );
      case SearchTarget.character:
        return _GenericResultTile(
          leading: item.image?.url != null
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: CachedNetworkImage(
                    imageUrl: item.image!.url!,
                    width: 48,
                    height: 64,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => Container(
                      width: 48,
                      height: 64,
                      color: Theme.of(context).colorScheme.surface,
                      child: const Icon(Icons.person, size: 20),
                    ),
                  ),
                )
              : null,
          title: item.name ?? '',
          subtitle: [
            if (item.original != null) item.original,
            if (item.vns != null && item.vns.isNotEmpty) item.vns.first.title,
          ].join(' · '),
          onTap: () => context.push('/character/${item.id}'),
        );
      case SearchTarget.producer:
        return _GenericResultTile(
          leading: CircleAvatar(
            child: Text((item.name ?? '?').substring(0, 1)),
          ),
          title: item.name ?? '',
          subtitle: [
            if (item.original != null) item.original,
            if (item.lang != null) item.lang,
            _producerTypeLabel(item.type),
          ].join(' · '),
          onTap: () => context.push('/producer/${item.id}'),
        );
      case SearchTarget.staff:
        return _GenericResultTile(
          leading: const CircleAvatar(child: Icon(Icons.person)),
          title: item.name ?? '',
          subtitle: [
            if (item.original != null) item.original,
            if (item.lang != null) item.lang,
            if (item.gender != null) item.gender,
          ].join(' · '),
          onTap: () => context.push('/staff/${item.id}'),
        );
      case SearchTarget.release:
        return _GenericResultTile(
          leading: const CircleAvatar(child: Icon(Icons.album)),
          title: item.title ?? '',
          subtitle: [
            if (item.released != null) item.released,
            if (item.platforms != null && item.platforms.isNotEmpty)
              item.platforms.join(', '),
            if (item.official == true) 'Official' else 'Unofficial',
          ].join(' · '),
          onTap: () => context.push('/release/${item.id}'),
        );
      case SearchTarget.tag:
        return _GenericResultTile(
          leading: const CircleAvatar(child: Icon(Icons.label)),
          title: item.name ?? '',
          subtitle: [
            _tagCategoryLabel(item.category),
            if (item.vn_count != null) '${item.vn_count} VN',
          ].join(' · '),
          onTap: () => context.push('/tag/${item.id}'),
        );
      case SearchTarget.trait:
        return _GenericResultTile(
          leading: const CircleAvatar(child: Icon(Icons.category)),
          title: item.name ?? '',
          subtitle: [
            if (item.group_name != null) item.group_name,
            if (item.char_count != null) '${item.char_count} 角色',
            if (item.sexual == true) '色情',
          ].join(' · '),
          onTap: () => context.push('/trait/${item.id}'),
        );
    }
  }

  String _producerTypeLabel(String? type) {
    switch (type) {
      case 'co':
        return '公司';
      case 'in':
        return '个人';
      case 'ng':
        return '业余组';
      default:
        return '';
    }
  }

  String _tagCategoryLabel(String? category) {
    switch (category) {
      case 'cont':
        return '内容';
      case 'tech':
        return '技术';
      case 'ero':
        return '色情';
      default:
        return '';
    }
  }
}

/// A generic list tile used for non-VN search results.
class _GenericResultTile extends StatelessWidget {
  const _GenericResultTile({
    this.leading,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final Widget? leading;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.all(8),
        leading: leading ??
            CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              child: Icon(Icons.tag,
                  color: Theme.of(context).colorScheme.primary),
            ),
        title: Text(
          title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: subtitle.isEmpty
            ? null
            : Text(
                subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

class _DropdownOption {
  const _DropdownOption({required this.label, required this.value});
  final String label;
  final String? value;
}

class _SortOption {
  const _SortOption({required this.label, required this.value});
  final String label;
  final String value;
}
