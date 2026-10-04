import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/i18n/vndb_zh.dart';
import '../../core/models/trait.dart';
import '../../core/providers/endpoints_provider.dart';
import 'trait_detail_page.dart';

/// A searchable, paginated list of all traits.
class TraitListPage extends ConsumerStatefulWidget {
  const TraitListPage({super.key});

  @override
  ConsumerState<TraitListPage> createState() => _TraitListPageState();
}

class _TraitListPageState extends ConsumerState<TraitListPage> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  String _term = '';
  int _page = 1;
  int _epoch = 0;
  final List<Trait> _items = [];
  bool _hasMore = true;
  bool _loading = false;
  bool _fetched = false;

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
    // epoch:丢弃 reset 之后才返回的旧请求,防止搜索竞态串页。
    final epoch = reset ? ++_epoch : _epoch;
    if (reset) {
      _items.clear();
      _page = 1;
      _hasMore = true;
    }
    setState(() => _loading = true);
    try {
      final result = _term.isEmpty
          ? await ref.read(traitEndpointProvider).list(page: _page)
          : await ref.read(traitEndpointProvider).search(_term, page: _page);
      if (!mounted || epoch != _epoch) return;
      setState(() {
        _items.addAll(result.results);
        _hasMore = result.more;
        // 关键:加载成功后推进页码,否则下滑会一直重复拉取第 1 页。
        _page += 1;
        _fetched = true;
      });
    } finally {
      if (mounted && epoch == _epoch) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('特质')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _controller,
              decoration: InputDecoration(
                hintText: '搜索特质…',
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
          ),
          Expanded(
            child: _fetched && _items.isEmpty
                ? const Center(child: Text('未找到特质'))
                : ListView.builder(
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
                        title: Text(VndbZh.traitTitle(t.id, t.name)),
                        subtitle: Text(
                          '${VndbZh.traitGroup(t.groupName)} · ${t.charCount} 角色',
                        ),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => TraitDetailPage(trait: t),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
