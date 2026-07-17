import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/tag.dart';
import '../../core/models/vn.dart';
import '../../core/providers/endpoints_provider.dart';
import '../../widgets/async_value_widget.dart';
import '../../widgets/section_header.dart';
import '../../widgets/vn_card.dart';

final _tagProvider =
    FutureProvider.autoDispose.family<Tag, String>((ref, id) {
  return ref.watch(tagEndpointProvider).getById(id);
});

class TagDetailPage extends ConsumerWidget {
  const TagDetailPage({super.key, this.id, this.tag});

  final String? id;
  final Tag? tag;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (tag != null) {
      return _TagBody(tag: tag!);
    }
    final tagAsync = ref.watch(_tagProvider(id!));
    return Scaffold(
      appBar: AppBar(title: const Text('标签')),
      body: AsyncValueWidget(
        value: tagAsync,
        data: (t) => _TagBody(tag: t),
        errorRetry: () => ref.invalidate(_tagProvider(id!)),
      ),
    );
  }
}

class _TagBody extends ConsumerStatefulWidget {
  const _TagBody({required this.tag});
  final Tag tag;

  @override
  ConsumerState<_TagBody> createState() => _TagBodyState();
}

class _TagBodyState extends ConsumerState<_TagBody> {
  final _scrollController = ScrollController();
  final List<Vn> _vns = [];
  int _page = 1;
  bool _hasMore = true;
  bool _loading = false;
  bool _initialLoaded = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _fetch();
  }

  @override
  void dispose() {
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

  Future<void> _fetch() async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      final result = await ref.read(vnEndpointProvider).byTag(
            widget.tag.id,
            page: _page,
            results: 20,
          );
      setState(() {
        _vns.addAll(result.results);
        _hasMore = result.more;
        _page += 1;
        _initialLoaded = true;
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
      appBar: AppBar(title: Text(widget.tag.name)),
      body: ListView(
        controller: _scrollController,
        padding: const EdgeInsets.all(12),
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              Chip(label: Text(widget.tag.categoryLabel)),
              Chip(label: Text('${widget.tag.vnCount} VN')),
              if (!widget.tag.applicable)
                const Chip(label: Text('Not applicable')),
            ],
          ),
          const SizedBox(height: 12),
          const SectionHeader(
              title: '描述', icon: Icons.description, padding: EdgeInsets.zero),
          Text(widget.tag.description ?? '暂无描述'),
          const SectionHeader(title: '相关 VN', icon: Icons.book),
          if (_initialLoaded && _vns.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: Text('暂无相关 VN')),
            )
          else
            ..._vns.map((vn) => VnCard(
                  vn: vn,
                  onTap: () => context.push('/vn/${vn.id}'),
                )),
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
