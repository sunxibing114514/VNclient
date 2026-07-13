import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/producer.dart';
import '../../core/providers/endpoints_provider.dart';
import '../../widgets/async_value_widget.dart';
import '../../widgets/section_header.dart';

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

class _ProducerBody extends StatelessWidget {
  const _ProducerBody({required this.producer});
  final Producer producer;

  @override
  Widget build(BuildContext context) {
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
        const SizedBox(height: 12),
        // Browse VNs by this developer via webview search.
        FilledButton.icon(
          icon: const Icon(Icons.search),
          label: const Text('查看该制作方的作品'),
          onPressed: () => context.push(
              '/webview?url=${Uri.encodeComponent("https://vndb.org/${producer.id}")}&title=${Uri.encodeComponent(producer.name)}'),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}
