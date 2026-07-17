import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/quote.dart';
import '../../core/providers/endpoints_provider.dart';
import '../../widgets/async_value_widget.dart';

/// Page that displays a random quote (like the VNDB footer) and lets the user
/// fetch another.
class QuotesPage extends ConsumerWidget {
  const QuotesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quote = ref.watch(_randomQuoteProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('随机语录'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: '下一条',
            onPressed: () => ref.invalidate(_randomQuoteProvider),
          ),
        ],
      ),
      body: AsyncValueWidget(
        value: quote,
        data: (q) => _QuoteCard(quote: q),
        errorRetry: () => ref.invalidate(_randomQuoteProvider),
      ),
    );
  }
}

final _randomQuoteProvider = FutureProvider.autoDispose<Quote>((ref) {
  return ref.watch(quoteEndpointProvider).random();
});

class _QuoteCard extends StatelessWidget {
  const _QuoteCard({required this.quote});
  final Quote quote;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.format_quote, size: 48),
          const SizedBox(height: 16),
          Text(
            '"${quote.quote}"',
            style: Theme.of(context).textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          if (quote.character != null || quote.vn != null)
            Wrap(
              spacing: 8,
              alignment: WrapAlignment.center,
              children: [
                if (quote.character != null)
                  ActionChip(
                    label: Text('— ${quote.character!.name}'),
                    onPressed: () =>
                        context.push('/character/${quote.character!.id}'),
                  ),
                if (quote.vn != null)
                  ActionChip(
                    label: Text(quote.vn!.title),
                    onPressed: () => context.push('/vn/${quote.vn!.id}'),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}
