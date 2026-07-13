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

final _tagVnsProvider =
    FutureProvider.autoDispose.family<List<Vn>, String>((ref, tagId) async {
  final result = await ref.watch(vnEndpointProvider).byTag(tagId, results: 30);
  return result.results;
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

class _TagBody extends ConsumerWidget {
  const _TagBody({required this.tag});
  final Tag tag;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vns = ref.watch(_tagVnsProvider(tag.id));
    return Scaffold(
      appBar: AppBar(title: Text(tag.name)),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              Chip(label: Text(tag.categoryLabel)),
              Chip(label: Text('${tag.vnCount} VN')),
              if (!tag.applicable) const Chip(label: Text('Not applicable')),
            ],
          ),
          const SizedBox(height: 12),
          const SectionHeader(title: '描述', icon: Icons.description, padding: EdgeInsets.zero),
          Text(tag.description ?? '暂无描述'),
          const SectionHeader(title: '相关 VN', icon: Icons.book),
          AsyncValueWidget(
            value: vns,
            data: (list) => Column(
              children: list
                  .map((vn) => VnCard(
                        vn: vn,
                        onTap: () => context.push('/vn/${vn.id}'),
                      ))
                  .toList(),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
