import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
  String _term = '';
  int _page = 1;
  final List<Trait> _items = [];
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
          ? await ref.read(traitEndpointProvider).list(page: _page)
          : await ref.read(traitEndpointProvider).search(_term, page: _page);
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
                        subtitle: Text(
                          '${t.groupName ?? "未分组"} · ${t.charCount} 角色',
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
