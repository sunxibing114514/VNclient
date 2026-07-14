import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/endpoints/vn_endpoint.dart';
import '../../core/models/query_result.dart';
import '../../core/models/vn.dart';
import '../../core/providers/endpoints_provider.dart';
import '../../widgets/vn_card.dart';

/// Search page with free-text search, advanced filter builder and compact
/// filter-string paste support.
class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({super.key});

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  final _termController = TextEditingController();
  final _compactController = TextEditingController();
  final _scrollController = ScrollController();

  final List<Vn> _items = [];
  bool _hasMore = true;
  bool _loading = false;
  Object? _error;
  int _page = 1;
  Object? _activeFilters;
  bool _showAdvanced = false;

  // Advanced filter state
  String? _language; // e.g. 'en', 'ja'
  String? _platform; // e.g. 'win', 'psp'
  String? _releasedFrom; // YYYY
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

  /// Build the active filters object based on the current filter state.
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
      _activeFilters = _buildFilters();
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
      final hasCompact = _compactController.text.trim().isNotEmpty;
      final QueryResult<Vn> result =
          await ref.read(vnEndpointProvider).query(
                filters: _activeFilters,
                fields: VnEndpoint.listFields,
                sort: _sort,
                reverse: _sort == 'rating' ||
                    _sort == 'votecount' ||
                    _sort == 'released' ||
                    _sort == 'id',
                results: 20,
                page: _page,
                compactFilters: hasCompact,
                normalizedFilters: hasCompact,
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
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                TextField(
                  controller: _termController,
                  decoration: InputDecoration(
                    hintText: '搜索 VN 标题、别名、发行版本…',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.search),
                      onPressed: _runSearch,
                    ),
                  ),
                  onSubmitted: (_) => _runSearch(),
                ),
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
            ),
          ),
          Expanded(child: _buildList()),
        ],
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
            // Language dropdown
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
            // Platform dropdown
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
            // Released date range
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
                    onChanged: (v) => _releasedFrom = v.trim().isEmpty ? null : v.trim(),
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
                    onChanged: (v) => _releasedTo = v.trim().isEmpty ? null : v.trim(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Minimum rating
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
            // Tag filter
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
            // Developer filter
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
            // Sort dropdown
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
        final vn = _items[i];
        return VnCard(
          vn: vn,
          onTap: () => context.push('/vn/${vn.id}'),
        );
      },
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
