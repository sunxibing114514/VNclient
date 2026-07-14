import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/tag.dart';
import '../../core/providers/endpoints_provider.dart';
import 'tag_detail_page.dart';

/// A searchable, paginated list of all tags with category filtering and
/// sort options.
class TagListPage extends ConsumerStatefulWidget {
  const TagListPage({super.key});

  @override
  ConsumerState<TagListPage> createState() => _TagListPageState();
}

class _TagListPageState extends ConsumerState<TagListPage> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  String _term = '';
  String? _category; // null = all, 'cont', 'ero', 'tech'
  String _sort = 'name'; // 'name' or 'vn_count'
  int _page = 1;
  final List<Tag> _items = [];
  bool _hasMore = true;
  bool _loading = false;
  bool _fetched = false;

  static const _categories = <_CategoryOption>[
    _CategoryOption(label: '全部', value: null),
    _CategoryOption(label: '内容', value: 'cont'),
    _CategoryOption(label: '色情', value: 'ero'),
    _CategoryOption(label: '技术', value: 'tech'),
  ];

  static const _sorts = <_SortOption>[
    _SortOption(label: '名称', value: 'name'),
    _SortOption(label: '数量', value: 'vn_count'),
  ];

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _fetch(reset: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_loading &&
        _hasMore) {
      _fetch();
    }
  }

  Future<void> _fetch({bool reset = false}) async {
    if (_loading) return;
    if (reset) {
      _items.clear();
      _page = 1;
      _hasMore = true;
    }
    setState(() => _loading = true);
    try {
      final endpoint = ref.read(tagEndpointProvider);
      final result = _term.isEmpty
          ? await endpoint.list(
              page: _page,
              sort: _sort,
              category: _category,
            )
          : await endpoint.search(_term, page: _page);
      setState(() {
        _items.addAll(result.results);
        _hasMore = result.more;
        _fetched = true;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载失败: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('标签')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                TextField(
                  controller: _controller,
                  decoration: InputDecoration(
                    hintText: '搜索标签…',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.search),
                      onPressed: () {
                        _term = _controller.text.trim();
                        _fetch(reset: true);
                      },
                    ),
                  ),
                  onSubmitted: (_) {
                    _term = _controller.text.trim();
                    _fetch(reset: true);
                  },
                ),
                const SizedBox(height: 8),
                // 分类筛选
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final cat in _categories) ...[
                        ChoiceChip(
                          label: Text(cat.label),
                          selected: _category == cat.value,
                          onSelected: (_) {
                            setState(() => _category = cat.value);
                            _fetch(reset: true);
                          },
                        ),
                        const SizedBox(width: 6),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                // 排序选项
                Row(
                  children: [
                    const Text('排序: ', style: TextStyle(fontSize: 12)),
                    for (final s in _sorts) ...[
                      ChoiceChip(
                        label: Text(s.label),
                        selected: _sort == s.value,
                        onSelected: (_) {
                          setState(() => _sort = s.value);
                          _fetch(reset: true);
                        },
                      ),
                      const SizedBox(width: 6),
                    ],
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: _fetched && _items.isEmpty
                ? const Center(child: Text('未找到标签'))
                : RefreshIndicator(
                    onRefresh: () => _fetch(reset: true),
                    child: ListView.builder(
                      controller: _scrollController,
                      itemCount: _items.length + (_hasMore ? 1 : 0),
                      itemBuilder: (context, i) {
                        if (i >= _items.length) {
                          return const Padding(
                            padding: EdgeInsets.all(16),
                            child: Center(child: CircularProgressIndicator()),
                          );
                        }
                        final t = _items[i];
                        return ListTile(
                          title: Text(t.name),
                          subtitle: Text(
                              '${t.categoryLabel} · ${t.vnCount} VN'),
                          trailing: t.vnCount > 0
                              ? CircleAvatar(
                                  radius: 14,
                                  backgroundColor:
                                      Theme.of(context).colorScheme.primaryContainer,
                                  child: Text(
                                    '${t.vnCount}',
                                    style: const TextStyle(fontSize: 10),
                                  ),
                                )
                              : null,
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => TagDetailPage(tag: t),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _CategoryOption {
  const _CategoryOption({required this.label, required this.value});
  final String label;
  final String? value;
}

class _SortOption {
  const _SortOption({required this.label, required this.value});
  final String label;
  final String value;
}
