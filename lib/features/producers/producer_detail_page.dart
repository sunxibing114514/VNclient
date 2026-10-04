import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/producer.dart';
import '../../core/models/vn.dart';
import '../../core/providers/endpoints_provider.dart';
import '../../core/services/follow_service.dart';
import '../../widgets/async_value_widget.dart';
import '../../widgets/section_header.dart';
import '../../widgets/vn_card.dart';

final _producerProvider =
    FutureProvider.autoDispose.family<Producer, String>((ref, id) {
  return ref.watch(producerEndpointProvider).getById(id);
});

class ProducerDetailPage extends ConsumerWidget {
  const ProducerDetailPage({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final producer = ref.watch(_producerProvider(id));
    return Scaffold(
      appBar: AppBar(title: const Text('制作方')),
      body: AsyncValueWidget(
        value: producer,
        data: (p) => _ProducerBody(producer: p),
        errorRetry: () => ref.invalidate(_producerProvider(id)),
      ),
    );
  }
}

class _ProducerBody extends ConsumerWidget {
  const _ProducerBody({required this.producer});
  final Producer producer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final followState = ref.watch(followServiceProvider);
    final isFollowing = followState.followed.any((p) => p.id == producer.id);

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Text(producer.name, style: Theme.of(context).textTheme.titleLarge),
        if (producer.original != null)
          Text(producer.original!, style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            if (producer.lang != null) Chip(label: Text(producer.lang!)),
            Chip(label: Text(producer.typeLabel)),
          ],
        ),
        const SizedBox(height: 12),
        // Follow / unfollow toggle.
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () {
              final svc = ref.read(followServiceProvider.notifier);
              if (isFollowing) {
                svc.unfollow(producer.id);
              } else {
                svc.follow(producer.id, producer.name);
              }
            },
            icon: Icon(isFollowing ? Icons.notifications_active : Icons.notifications_none),
            label: Text(isFollowing ? '已关注' : '关注制作方'),
            style: isFollowing
                ? FilledButton.styleFrom(
                    backgroundColor:
                        Theme.of(context).colorScheme.secondaryContainer,
                    foregroundColor:
                        Theme.of(context).colorScheme.onSecondaryContainer,
                  )
                : null,
          ),
        ),
        if (producer.aliases.isNotEmpty) ...[
          const SizedBox(height: 12),
          const SectionHeader(title: '别名', icon: Icons.label, padding: EdgeInsets.zero),
          Text(producer.aliases.join(', ')),
        ],
        if (producer.description != null) ...[
          const SizedBox(height: 12),
          const SectionHeader(title: '简介', icon: Icons.description, padding: EdgeInsets.zero),
          Text(producer.description!),
        ],
        const SizedBox(height: 12),
        // 该制作方的作品,直接在应用内分页浏览(不再跳转网页)。
        _ProducerWorks(producerId: producer.id),
        if (producer.extlinks.isNotEmpty) ...[
          const SizedBox(height: 12),
          const SectionHeader(title: '外部链接', icon: Icons.link, padding: EdgeInsets.zero),
          for (final link in producer.extlinks)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(link.label),
              trailing: const Icon(Icons.open_in_new, size: 18),
              onTap: () => context.push(
                  '/webview?url=${Uri.encodeComponent(link.url)}&title=${Uri.encodeComponent(link.label)}'),
            ),
        ],
        const SizedBox(height: 24),
      ],
    );
  }
}

/// 制作方作品列表:通过 `/vn` 的 developer 嵌套过滤器分页加载。
class _ProducerWorks extends ConsumerStatefulWidget {
  const _ProducerWorks({required this.producerId});

  final String producerId;

  @override
  ConsumerState<_ProducerWorks> createState() => _ProducerWorksState();
}

class _ProducerWorksState extends ConsumerState<_ProducerWorks> {
  final _items = <Vn>[];
  final _scrollController = ScrollController();
  int _page = 1;
  bool _hasMore = true;
  bool _loading = false;
  Object? _error;
  int _epoch = 0;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _fetch() async {
    if (_loading) return;
    final epoch = _epoch;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await ref.read(vnEndpointProvider).byDeveloper(
            widget.producerId,
            page: _page,
            results: 20,
          );
      if (!mounted || epoch != _epoch) return;
      setState(() {
        _items.addAll(result.results);
        _hasMore = result.more;
        _page += 1;
        _loading = false;
      });
    } catch (e) {
      if (!mounted || epoch != _epoch) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (!_hasMore || _loading) return;
    await _fetch();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(
          title: '作品',
          icon: Icons.library_books,
          padding: EdgeInsets.zero,
        ),
        if (_items.isEmpty && _loading)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_items.isEmpty && _error != null)
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                Text('$_error'),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: () {
                    _epoch++;
                    _fetch();
                  },
                  child: const Text('重试'),
                ),
              ],
            ),
          )
        else if (_items.isEmpty)
          const Padding(
            padding: EdgeInsets.all(12),
            child: Text('暂无作品'),
          )
        else
          for (var i = 0; i < _items.length; i++)
            () {
              // 列表尾部触发加载下一页(下一帧执行,避免构建期 setState)。
              if (i == _items.length - 1 && _hasMore && !_loading) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) _loadMore();
                });
              }
              final vn = _items[i];
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: VnCard(
                  vn: vn,
                  onTap: () => context.push('/vn/${vn.id}'),
                ),
              );
            }(),
        if (_loading && _items.isNotEmpty)
          const Padding(
            padding: EdgeInsets.all(12),
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
      ],
    );
  }
}
