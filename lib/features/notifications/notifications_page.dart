import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/services/follow_service.dart';

/// Lists producer new-work notifications. Tapping a notification opens the
/// VN detail page; entries can be dismissed individually or all at once.
class NotificationsPage extends ConsumerWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(followServiceProvider);
    final notifs = state.notifications;

    return Scaffold(
      appBar: AppBar(
        title: const Text('消息中心'),
        actions: [
          if (notifs.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.done_all),
              tooltip: '全部标为已读',
              onPressed: () =>
                  ref.read(followServiceProvider.notifier).markAllRead(),
            ),
          if (notifs.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep),
              tooltip: '清空全部',
              onPressed: () => _confirmClearAll(context, ref),
            ),
        ],
      ),
      body: notifs.isEmpty
          ? _buildEmpty(context, ref)
          : ListView.separated(
              itemCount: notifs.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final n = notifs[i];
                return Dismissible(
                  key: ValueKey(n.id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    color: Theme.of(context).colorScheme.error,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 16),
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  onDismissed: (_) => ref
                      .read(followServiceProvider.notifier)
                      .dismissNotification(n.id),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: n.read
                          ? Theme.of(context).colorScheme.surfaceVariant
                          : Theme.of(context).colorScheme.primaryContainer,
                      child: const Icon(Icons.notifications),
                    ),
                    title: Text(
                      n.vnTitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight:
                            n.read ? FontWeight.normal : FontWeight.bold,
                      ),
                    ),
                    subtitle: Text(
                      [
                        n.producerName,
                        if (n.released != null) n.released,
                      ].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      ref
                          .read(followServiceProvider.notifier)
                          .markAllRead();
                      context.push('/vn/${n.vnId}');
                    },
                  ),
                );
              },
            ),
    );
  }

  Widget _buildEmpty(BuildContext context, WidgetRef ref) {
    final followed = ref.watch(followServiceProvider).followed;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.notifications_none, size: 56),
          const SizedBox(height: 12),
          const Text('暂无消息'),
          const SizedBox(height: 8),
          if (followed.isEmpty)
            const Text(
              '在制作商详情页点击"关注制作方",\n有新作品时将在此提醒。',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12),
            )
          else
            Text('已关注 ${followed.length} 个制作商, 暂无新作品。',
                style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  void _confirmClearAll(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('清空全部消息'),
        content: const Text('确定要清空所有通知吗? 此操作不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              ref.read(followServiceProvider.notifier).clearAllNotifications();
            },
            child: const Text('清空'),
          ),
        ],
      ),
    );
  }
}
