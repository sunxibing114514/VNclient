import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/character.dart';
import '../../core/providers/endpoints_provider.dart';
import '../../widgets/async_value_widget.dart';
import '../../widgets/section_header.dart';

final _characterProvider =
    FutureProvider.autoDispose.family<Character, String>((ref, id) {
  return ref.watch(characterEndpointProvider).getById(id);
});

class CharacterDetailPage extends ConsumerWidget {
  const CharacterDetailPage({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final character = ref.watch(_characterProvider(id));
    return Scaffold(
      appBar: AppBar(title: const Text('角色')),
      body: AsyncValueWidget(
        value: character,
        data: (c) => _CharacterBody(character: c),
        errorRetry: () => ref.invalidate(_characterProvider(id)),
      ),
    );
  }
}

class _CharacterBody extends StatelessWidget {
  const _CharacterBody({required this.character});
  final Character character;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (character.image?.url != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: CachedNetworkImage(
                  imageUrl: character.image!.url!,
                  width: 100,
                  height: 140,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Container(
                    width: 100,
                    height: 140,
                    color: Theme.of(context).colorScheme.surface,
                  ),
                  errorWidget: (_, __, ___) => Container(
                    width: 100,
                    height: 140,
                    color: Theme.of(context).colorScheme.surface,
                    child: const Icon(Icons.person),
                  ),
                ),
              )
            else
              Container(
                width: 100,
                height: 140,
                color: Theme.of(context).colorScheme.surface,
                child: const Icon(Icons.person, size: 40),
              ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(character.name,
                      style: Theme.of(context).textTheme.titleLarge),
                  if (character.original != null)
                    Text(character.original!,
                        style: Theme.of(context).textTheme.bodyMedium),
                  const SizedBox(height: 8),
                  if (character.aliases.isNotEmpty)
                    Text('别名: ${character.aliases.join(", ")}',
                        style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 8),
                  Chip(label: Text(character.roleLabel)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        const SectionHeader(title: '属性', icon: Icons.info, padding: EdgeInsets.zero),
        _kv(context, '血型', character.bloodType?.toUpperCase()),
        _kv(context, '身高', character.height == null ? null : '${character.height} cm'),
        _kv(context, '体重', character.weight == null ? null : '${character.weight} kg'),
        _kv(context, '三围', _measures(context)),
        _kv(context, '罩杯', character.cup),
        _kv(context, '年龄', character.age == null ? null : '${character.age}'),
        if (character.birthday != null && character.birthday!.length == 2)
          _kv(context, '生日', '${character.birthday![0]}月 ${character.birthday![1]}日'),
        if (character.traits.isNotEmpty) ...[
          const SizedBox(height: 12),
          const SectionHeader(title: '特质', icon: Icons.category, padding: EdgeInsets.zero),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: character.traits.map((t) {
              final group = t.groupName == null ? '' : ' (${t.groupName})';
              return ActionChip(
                label: Text(t.name + group),
                onPressed: () => context.push('/trait/${t.id}'),
              );
            }).toList(),
          ),
        ],
        if (character.description != null) ...[
          const SizedBox(height: 12),
          const SectionHeader(title: '简介', icon: Icons.description, padding: EdgeInsets.zero),
          Text(character.description!),
        ],
        if (character.vns.isNotEmpty) ...[
          const SizedBox(height: 12),
          const SectionHeader(title: '登场作品', icon: Icons.book, padding: EdgeInsets.zero),
          for (final v in character.vns)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(v.title),
              subtitle: Text(v.role),
              onTap: () => context.push('/vn/${v.id}'),
            ),
        ],
        const SizedBox(height: 24),
      ],
    );
  }

  String _measures(BuildContext context) {
    if (character.bust == null && character.waist == null && character.hips == null) {
      return '';
    }
    return '${character.bust ?? "-"}-${character.waist ?? "-"}-${character.hips ?? "-"}';
  }

  Widget _kv(BuildContext context, String label, String? value) {
    if (value == null || value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 56,
            child: Text(label, style: Theme.of(context).textTheme.bodySmall),
          ),
          Expanded(
              child: Text(value, style: Theme.of(context).textTheme.bodyMedium)),
        ],
      ),
    );
  }
}
