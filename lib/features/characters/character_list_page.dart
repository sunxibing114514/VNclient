import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/endpoints_provider.dart';

/// A searchable, paginated list of all characters.
class CharacterListPage extends ConsumerStatefulWidget {
  const CharacterListPage({super.key});

  @override
  ConsumerState<CharacterListPage> createState() => _CharacterListPageState();
}

class _CharacterListPageState extends ConsumerState<CharacterListPage> {
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
          await ref.read(characterEndpointProvider).search(_term, page: _page);
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
      appBar: AppBar(title: const Text('Characters')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _controller,
              decoration: InputDecoration(
                hintText: '搜索角色…',
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
                ? const Center(child: Text('未找到角色'))
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
                        final c = _items[i];
                        return Card(
                          child: ListTile(
                            contentPadding: const EdgeInsets.all(8),
                            leading: c.image?.url != null
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: CachedNetworkImage(
                                      imageUrl: c.image!.url!,
                                      width: 48,
                                      height: 64,
                                      fit: BoxFit.cover,
                                      placeholder: (_, __) => Container(
                                        width: 48,
                                        height: 64,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .surface,
                                      ),
                                      errorWidget: (_, __, ___) => Container(
                                        width: 48,
                                        height: 64,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .surface,
                                        child: const Icon(Icons.person,
                                            size: 20),
                                      ),
                                    ),
                                  )
                                : Container(
                                    width: 48,
                                    height: 64,
                                    color:
                                        Theme.of(context).colorScheme.surface,
                                    child: const Icon(Icons.person),
                                  ),
                            title: Text(
                              c.name,
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            subtitle: Text(
                              [
                                if (c.original != null) c.original,
                                if (c.vns.isNotEmpty) c.vns.first.title,
                              ].join(' · '),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => context.push('/character/${c.id}'),
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
