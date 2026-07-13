import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/tag.dart';
import '../../core/providers/endpoints_provider.dart';
import 'tag_detail_page.dart';

/// A searchable, paginated list of all tags.
class TagListPage extends ConsumerStatefulWidget {
  const TagListPage({super.key});

  @override
  ConsumerState<TagListPage> createState() => _TagListPageState();
}

class _TagListPageState extends ConsumerState<TagListPage> {
  final _controller = TextEditingController();
  String _term = '';
  int _page = 1;
  final List<Tag> _items = [];
  bool _hasMore = true;
  bool _loading = false;
  bool _fetched = false;

  @override
  void initState() {
    super.initState();
    _fetch(reset: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
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
      final result = _term.isEmpty
          ? await ref.read(tagEndpointProvider).list(page: _page)
          : await ref.read(tagEndpointProvider).search(_term, page: _page);
      setState(() {
        _items.addAll(result.results);
        _hasMore = result.more;
        _fetched = true;
      });
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
            child: TextField(
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
          ),
          Expanded(
            child: _fetched && _items.isEmpty
                ? const Center(child: Text('未找到标签'))
                : ListView.builder(
                    itemCount: _items.length + (_hasMore ? 1 : 0),
                    itemBuilder: (context, i) {
                      if (i >= _items.length) {
                        _fetch();
                        return const Padding(
                          padding: EdgeInsets.all(16),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      final t = _items[i];
                      return ListTile(
                        title: Text(t.name),
                        subtitle: Text('${t.categoryLabel} · ${t.vnCount} VN'),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => TagDetailPage(tag: t),
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
