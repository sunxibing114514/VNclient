import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/release.dart';
import '../../core/providers/endpoints_provider.dart';
import '../../widgets/async_value_widget.dart';
import '../../widgets/section_header.dart';

final _releaseProvider =
    FutureProvider.autoDispose.family<Release, String>((ref, id) {
  return ref.watch(releaseEndpointProvider).getById(id);
});

class ReleaseDetailPage extends ConsumerWidget {
  const ReleaseDetailPage({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final release = ref.watch(_releaseProvider(id));
    return Scaffold(
      appBar: AppBar(title: const Text('发行版本')),
      body: AsyncValueWidget(
        value: release,
        data: (r) => _ReleaseBody(release: r),
        errorRetry: () => ref.invalidate(_releaseProvider(id)),
      ),
    );
  }
}

class _ReleaseBody extends StatelessWidget {
  const _ReleaseBody({required this.release});
  final Release release;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Text(release.title, style: Theme.of(context).textTheme.titleLarge),
        if (release.alttitle != null) ...[
          const SizedBox(height: 4),
          Text(release.alttitle!,
              style: Theme.of(context).textTheme.bodyMedium),
        ],
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            if (release.released != null) Chip(label: Text(release.released!)),
            Chip(label: Text(release.official ? 'Official' : 'Unofficial')),
            Chip(label: Text(release.freeware ? '免费' : '收费')),
            if (release.patch) const Chip(label: Text('Patch')),
            if (release.minage != null) Chip(label: Text('${release.minage}+')),
          ],
        ),
        const SizedBox(height: 12),
        const SectionHeader(title: '详情', icon: Icons.info, padding: EdgeInsets.zero),
        _KV('平台', release.platforms.join(', ')),
        _KV('价格', release.freeware ? '免费' : '收费'),
        _KV('引擎', release.engine ?? '未知'),
        _KV('语音', release.voicedLabel),
        _KV('目录号', release.catalog ?? '未知'),
        _KV('GTIN', release.gtin ?? '未知'),
        _KV(
          '分辨率',
          release.resolution == null
              ? '未知'
              : (release.resolution is List
                  ? '${(release.resolution as List)[0]}x${(release.resolution as List)[1]}'
                  : release.resolution.toString()),
        ),
        _KV('成人内容', release.hasEro ? '是' : '否'),
        if (release.media.isNotEmpty)
          _KV('介质',
              release.media.map((m) => m.qty > 0 ? '${m.qty}× ${m.medium}' : m.medium).join(', ')),
        if (release.notes != null) ...[
          const SizedBox(height: 12),
          const SectionHeader(title: '备注', icon: Icons.notes, padding: EdgeInsets.zero),
          Text(release.notes!),
        ],
        if (release.languages.isNotEmpty) ...[
          const SizedBox(height: 12),
          const SectionHeader(title: '语言', icon: Icons.translate, padding: EdgeInsets.zero),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: release.languages
                .map((l) => Chip(
                      label: Text(l.lang +
                          (l.mtl ? ' (MTL)' : '') +
                          (l.main ? ' · main' : '')),
                    ))
                .toList(),
          ),
        ],
        if (release.producers.isNotEmpty) ...[
          const SizedBox(height: 12),
          const SectionHeader(title: '制作方', icon: Icons.business, padding: EdgeInsets.zero),
          for (final p in release.producers)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(p.name),
              subtitle: Text([
                if (p.developer) 'Developer',
                if (p.publisher) 'Publisher',
                if (p.type != null) p.type!,
              ].join(' · ')),
              onTap: () => context.push('/producer/${p.id}'),
            ),
        ],
        if (release.vns.isNotEmpty) ...[
          const SizedBox(height: 12),
          const SectionHeader(title: '关联 VN', icon: Icons.book, padding: EdgeInsets.zero),
          for (final v in release.vns)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(v.title),
              subtitle: Text(v.rtype),
              onTap: () => context.push('/vn/${v.id}'),
            ),
        ],
        if (release.extlinks.isNotEmpty) ...[
          const SizedBox(height: 12),
          const SectionHeader(title: '外部链接', icon: Icons.link, padding: EdgeInsets.zero),
          for (final link in release.extlinks)
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

class _KV extends StatelessWidget {
  const _KV(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 72,
            child: Text(label, style: Theme.of(context).textTheme.bodySmall),
          ),
          Expanded(
            child: Text(value, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}
