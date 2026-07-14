import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/endpoints_provider.dart';

/// A searchable, paginated list of all producers.
class ProducerListPage extends ConsumerStatefulWidget {
  const ProducerListPage({super.key});

  @override
  ConsumerState<ProducerListPage> createState() => _ProducerListPageState();
}

class _ProducerListPageState extends ConsumerState<ProducerListPage> {
  final _controller = TextEditingController();
  String _term = '';
  int _page = 1;
  final _items = <dynamic>[];
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
      final result =
          await ref.read(producerEndpointProvider).search(_term, page: _page);
      setState(() {
        _items.addAll(result.results);
        _hasMore = result.more;
        _fetched = true;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Producers')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _controller,
              decoration: InputDecoration(
                hintText: '搜索制作商…',
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
                ? const Center(child: Text('未找到制作商'))
                : RefreshIndicator(
                    onRefresh: () => _fetch(reset: true),
                    child: ListView.builder(
                      itemCount: _items.length + (_hasMore ? 1 : 0),
                      itemBuilder: (context, i) {
                        if (i >= _items.length) {
                          _fetch();
                          return const Padding(
                            padding: EdgeInsets.all(16),
                            child: Center(child: CircularProgressIndicator()),
                          );
                        }
                        final p = _items[i];
                        return Card(
                          child: ListTile(
                            title: Text(p.name),
                            subtitle: Text(
                              '${p.typeLabel}${p.lang != null ? " · ${p.lang}" : ""}',
                            ),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => context.push('/producer/${p.id}'),
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
