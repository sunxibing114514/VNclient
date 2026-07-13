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

  Future<void> _runSearch() async {
    setState(() {
      _items.clear();
      _page = 1;
      _hasMore = true;
      _error = null;
      _activeFilters = _compactController.text.trim().isNotEmpty
          ? _compactController.text.trim()
          : (_termController.text.trim().isEmpty
              ? <Object>[]
              : ['search', '=', _termController.text.trim()]);
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
      final QueryResult<Vn> result =
          await ref.read(vnEndpointProvider).query(
                filters: _activeFilters,
                fields: VnEndpoint.listFields,
                sort: 'searchrank',
                results: 20,
                page: _page,
                compactFilters: _compactController.text.trim().isNotEmpty,
                normalizedFilters: _compactController.text.trim().isNotEmpty,
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
                      onPressed: () => setState(
                          () => _showAdvanced = !_showAdvanced),
                    ),
                  ],
                ),
                if (_showAdvanced) _AdvancedFilters(),
              ],
            ),
          ),
          Expanded(child: _buildList()),
        ],
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

/// A basic advanced-filter panel. Currently supports language, platform and
/// minimum rating. Additional rules can be added following the same pattern.
class _AdvancedFilters extends ConsumerStatefulWidget {
  @override
  ConsumerState<_AdvancedFilters> createState() => _AdvancedFiltersState();
}

class _AdvancedFiltersState extends ConsumerState<_AdvancedFilters> {
  final _langController = TextEditingController();
  final _platformController = TextEditingController();
  double _minRating = 0;

  @override
  void dispose() {
    _langController.dispose();
    _platformController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('高级筛选 (示例)'),
            const SizedBox(height: 8),
            TextField(
              controller: _langController,
              decoration: const InputDecoration(
                labelText: '语言 (如 en, ja)',
                isDense: true,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _platformController,
              decoration: const InputDecoration(
                labelText: '平台 (如 win, psp)',
                isDense: true,
              ),
            ),
            const SizedBox(height: 8),
            Text('最低评分: ${(_minRating * 10).round()}'),
            Slider(
              value: _minRating,
              min: 0,
              max: 10,
              divisions: 9,
              onChanged: (v) => setState(() => _minRating = v),
            ),
            const SizedBox(height: 8),
            const Text(
              '提示: 这些筛选为示例，可按需扩展。完整筛选请使用 compact filter 字符串。',
              style: TextStyle(fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}
