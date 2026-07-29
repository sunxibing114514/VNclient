import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_constants.dart';
import '../../core/api/endpoints/vn_endpoint.dart';
import '../../core/models/vn.dart';
import '../../core/providers/endpoints_provider.dart';
import '../../core/providers/theme_provider.dart';
import '../../core/services/browsing_history_service.dart';
import '../../core/theme/title_resolver.dart';
import '../../widgets/vndb_icons.dart';

/// Displays the user's recently-viewed VNs, most-recent first.
class BrowsingHistoryPage extends ConsumerWidget {
  const BrowsingHistoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(browsingHistoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('浏览历史'),
        actions: [
          if (history.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep),
              tooltip: '清空历史',
              onPressed: () => _confirmClear(context, ref),
            ),
        ],
      ),
      body: history.isEmpty
          ? _buildEmpty(context)
          : _HistoryList(history: history),
    );
  }

  Widget _buildEmpty(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.history, size: 56),
          const SizedBox(height: 12),
          const Text('暂无浏览历史'),
          const SizedBox(height: 8),
          Text(
            '浏览过的 VN 会在此显示',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Future<void> _confirmClear(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('清空历史'),
        content: const Text('确定清空所有浏览历史吗？此操作不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('清空'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(browsingHistoryProvider.notifier).clear();
    }
  }
}

class _HistoryList extends ConsumerStatefulWidget {
  const _HistoryList({required this.history});
  final List<HistoryEntry> history;

  @override
  ConsumerState<_HistoryList> createState() => _HistoryListState();
}

class _HistoryListState extends ConsumerState<_HistoryList> {
  List<Vn>? _vns;
  Object? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchVns();
  }

  @override
  void didUpdateWidget(_HistoryList oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Re-fetch when the history entries change (e.g. after deletion).
    final oldIds = oldWidget.history.map((e) => e.vnId).toList();
    final newIds = widget.history.map((e) => e.vnId).toList();
    if (oldIds.length != newIds.length ||
        !_listEquals(oldIds, newIds)) {
      _fetchVns();
    }
  }

  bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  Future<void> _fetchVns() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final ids = widget.history.map((e) => e.vnId).toList();
      if (ids.isEmpty) {
        setState(() {
          _vns = [];
          _loading = false;
        });
        return;
      }
      // Query VNs by id list using the "id" filter with an OR group.
      final result = await ref.read(vnEndpointProvider).query(
            filters: ['or', ...ids.map((id) => ['id', '=', id])],
            fields: VnEndpoint.listFields,
            sort: 'id',
            results: AppConstants.browsingHistoryLimit,
          );
      // Sort the results to match the history order (most-recent first).
      final order = {for (var i = 0; i < ids.length; i++) ids[i]: i};
      final sorted = result.results.toList()
        ..sort((a, b) {
          final oa = order[a.id] ?? 999999;
          final ob = order[b.id] ?? 999999;
          return oa.compareTo(ob);
        });
      if (!mounted) return;
      setState(() {
        _vns = sorted;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48),
            const SizedBox(height: 8),
            Text('$_error'),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _fetchVns,
              child: const Text('重试'),
            ),
          ],
        ),
      );
    }
    final vns = _vns ?? [];
    if (vns.isEmpty) {
      return const Center(child: Text('暂无浏览历史'));
    }
    final historyMap = {
      for (final e in widget.history) e.vnId: e.viewedAt,
    };
    return RefreshIndicator(
      onRefresh: _fetchVns,
      child: ListView.builder(
        itemCount: vns.length,
        itemBuilder: (context, i) {
          final vn = vns[i];
          final viewedAt = historyMap[vn.id] ?? 0;
          return _HistoryTile(
            vn: vn,
            viewedAt: viewedAt,
            onRemove: () => ref
                .read(browsingHistoryProvider.notifier)
                .remove(vn.id),
          );
        },
      ),
    );
  }
}

class _HistoryTile extends ConsumerWidget {
  const _HistoryTile({
    required this.vn,
    required this.viewedAt,
    required this.onRemove,
  });

  final Vn vn;
  final int viewedAt;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final titleMode =
        ref.watch(themeNotifierProvider.select((s) => s.titleDisplay));
    final title = TitleResolver.resolveSimple(
      vn.title,
      vn.alttitle,
      titleMode,
    );

    return Dismissible(
      key: ValueKey('history_${vn.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (_) async {
        return await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('移除'),
            content: Text('从浏览历史移除 ${vn.title} 吗？'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('取消'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('移除'),
              ),
            ],
          ),
        );
      },
      onDismissed: (_) => onRemove(),
      child: Card(
        child: ListTile(
          contentPadding: const EdgeInsets.all(8),
          leading: vn.image?.thumbnail != null
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: CachedNetworkImage(
                    imageUrl: vn.image!.thumbnail!,
                    width: 48,
                    height: 70,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(
                      width: 48,
                      height: 70,
                      color: Theme.of(context).colorScheme.surface,
                    ),
                    errorWidget: (_, __, ___) => Container(
                      width: 48,
                      height: 70,
                      color: Theme.of(context).colorScheme.surface,
                      child: const Icon(Icons.broken_image, size: 20),
                    ),
                  ),
                )
              : Container(
                  width: 48,
                  height: 70,
                  color: Theme.of(context).colorScheme.surface,
                  child: const Icon(Icons.book),
                ),
          title: Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              if (vn.languages.isNotEmpty || vn.platforms.isNotEmpty)
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (vn.languages.isNotEmpty)
                      VndbIcons.langRow(vn.languages),
                    if (vn.platforms.isNotEmpty)
                      VndbIcons.platRow(vn.platforms),
                  ],
                ),
              const SizedBox(height: 4),
              Text(
                _formatViewedAt(viewedAt),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
          onTap: () => context.push('/vn/${vn.id}'),
        ),
      ),
    );
  }

  String _formatViewedAt(int millis) {
    final dt = DateTime.fromMillisecondsSinceEpoch(millis);
    final y = dt.year.toString();
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final h = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '浏览于 $y-$m-$d $h:$min';
  }
}
