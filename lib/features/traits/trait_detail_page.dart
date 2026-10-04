import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/i18n/vndb_zh.dart';
import '../../core/models/character.dart';
import '../../core/models/trait.dart';
import '../../core/providers/endpoints_provider.dart';
import '../../core/providers/theme_provider.dart';
import '../../core/theme/title_resolver.dart';
import '../../widgets/async_value_widget.dart';
import '../../widgets/section_header.dart';

final _traitProvider =
    FutureProvider.autoDispose.family<Trait, String>((ref, id) {
  return ref.watch(traitEndpointProvider).getById(id);
});

final _traitCharsProvider =
    FutureProvider.autoDispose.family<List<Character>, String>(
        (ref, traitId) async {
  final result =
      await ref.watch(characterEndpointProvider).byTrait(traitId, results: 30);
  return result.results;
});

class TraitDetailPage extends ConsumerWidget {
  const TraitDetailPage({super.key, this.id, this.trait});

  final String? id;
  final Trait? trait;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (trait != null) {
      return _TraitBody(trait: trait!);
    }
    final traitAsync = ref.watch(_traitProvider(id!));
    return Scaffold(
      appBar: AppBar(title: const Text('特质')),
      body: AsyncValueWidget(
        value: traitAsync,
        data: (t) => _TraitBody(trait: t),
        errorRetry: () => ref.invalidate(_traitProvider(id!)),
      ),
    );
  }
}

class _TraitBody extends ConsumerWidget {
  const _TraitBody({required this.trait});
  final Trait trait;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chars = ref.watch(_traitCharsProvider(trait.id));
    final titleMode =
        ref.watch(themeNotifierProvider.select((s) => s.titleDisplay));
    return Scaffold(
      appBar: AppBar(
          title: Text(VndbZh.traitTitle(trait.id, trait.name))),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              if (trait.groupName != null)
                Chip(label: Text(VndbZh.traitGroup(trait.groupName))),
              Chip(label: Text('${trait.charCount} 角色')),
              if (trait.sexual) const Chip(label: Text('性相关')),
            ],
          ),
          const SizedBox(height: 12),
          const SectionHeader(title: '描述', icon: Icons.description, padding: EdgeInsets.zero),
          Text(trait.description ?? '暂无描述'),
          const SectionHeader(title: '相关角色', icon: Icons.face),
          AsyncValueWidget(
            value: chars,
            data: (list) => Column(
              children: list
                  .map((c) => ListTile(
                        title: Text(TitleResolver.resolvePair(
                            c.name, c.original, titleMode)),
                        subtitle: Text(TitleResolver.pairSecondary(
                                c.name, c.original, titleMode) ??
                            ''),
                        onTap: () => context.push('/character/${c.id}'),
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
