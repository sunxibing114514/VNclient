import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/services/follow_service.dart';

/// Lists all producers the user follows. Tapping an entry opens the producer
/// detail page; entries can be unfollowed by swiping or via the trailing icon.
class FollowListPage extends ConsumerWidget {
  const FollowListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final followed = ref.watch(followServiceProvider.select((s) => s.followed));

    return Scaffold(
      appBar: AppBar(
        title: const Text('关注列表'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: '检查新作',
            onPressed: () async {
              final count =
                  await ref.read(followServiceProvider.notifier).checkForNewWorks();
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(count > 0 ? '发现 $count 部新作品' : '暂无新作品'),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
          ),
        ],
      ),
      body: followed.isEmpty
          ? _buildEmpty(context)
          : ListView.separated(
              itemCount: followed.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final p = followed[i];
                return Dismissible(
                  key: ValueKey(p.id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    color: Theme.of(context).colorScheme.error,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 16),
                    child: const Icon(Icons.person_remove, color: Colors.white),
                  ),
                  onDismissed: (_) {
                    ref.read(followServiceProvider.notifier).unfollow(p.id);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('已取消关注 ${p.name}'),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor:
                          Theme.of(context).colorScheme.primaryContainer,
                      child: const Icon(Icons.domain),
                    ),
                    title: Text(
                      p.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      p.lastSeenAt == 0
                          ? '尚未检查新作'
                          : '上次检查: ${formatLastSeenAt(p.lastSeenAt)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.person_remove, size: 20),
                      tooltip: '取消关注',
                      onPressed: () {
                        ref
                            .read(followServiceProvider.notifier)
                            .unfollow(p.id);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('已取消关注 ${p.name}'),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      },
                    ),
                    onTap: () => context.push('/producer/${p.id}'),
                  ),
                );
              },
            ),
    );
  }

  Widget _buildEmpty(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.favorite_border, size: 56),
          const SizedBox(height: 12),
          const Text('暂未关注任何制作商'),
          const SizedBox(height: 8),
          const Text(
            '在制作商详情页点击"关注制作方",\n当其发布新作品时将在此提醒。',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 16),
          FilledButton.tonalIcon(
            icon: const Icon(Icons.search),
            label: const Text('浏览制作商'),
            onPressed: () => context.push('/producers'),
          ),
        ],
      ),
    );
  }
}
