import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/services/announcement_service.dart';
import '../../core/services/follow_service.dart';

/// Lists remote announcements and producer new-work notifications. Tapping a
/// notification opens the VN detail page; entries can be dismissed
/// individually or all at once.
class NotificationsPage extends ConsumerStatefulWidget {
  const NotificationsPage({super.key});

  @override
  ConsumerState<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends ConsumerState<NotificationsPage> {
  final Set<String> _expanded = <String>{};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final ann = ref.read(announcementServiceProvider.notifier);
      await ann.refresh();
      ann.markAllSeen();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(followServiceProvider);
    final annState = ref.watch(announcementServiceProvider);
    final notifs = state.notifications;
    final announcements = annState.items;
    final hasDivider =
        announcements.isNotEmpty && notifs.isNotEmpty;

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
      body: notifs.isEmpty && announcements.isEmpty
          ? _buildEmpty(context, ref)
          : RefreshIndicator(
              onRefresh: () async {
                await Future.wait<void>([
                  ref.read(announcementServiceProvider.notifier).refresh(),
                  ref
                      .read(followServiceProvider.notifier)
                      .checkForNewWorks(),
                ]);
              },
              child: ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                itemCount: announcements.length +
                    (hasDivider ? 1 : 0) +
                    notifs.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  if (i < announcements.length) {
                    return _buildAnnouncement(
                      context,
                      announcements[i],
                      top: i == 0,
                    );
                  }
                  if (i == announcements.length && hasDivider) {
                    return _buildSectionHeader(context);
                  }
                  final n = notifs[i - announcements.length - (hasDivider ? 1 : 0)];
                  return _buildNotifTile(context, n);
                },
              ),
            ),
    );
  }

  Widget _buildAnnouncement(BuildContext context, Announcement a,
      {required bool top}) {
    final expanded = _expanded.contains(a.id);
    return Padding(
      padding: EdgeInsets.only(
        left: 12,
        right: 12,
        top: top ? 12 : 0,
      ),
      child: Card(
        margin: EdgeInsets.zero,
        elevation: 0,
        color: a.pinned
            ? Theme.of(context).colorScheme.secondaryContainer.withValues(alpha: 0.45)
            : Theme.of(context).colorScheme.surfaceVariant.withValues(alpha: 0.4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: Theme.of(context).colorScheme.outlineVariant,
            width: 0.5,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            setState(() {
              if (expanded) {
                _expanded.remove(a.id);
              } else {
                _expanded.add(a.id);
              }
            });
          },
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.campaign,
                      size: 20,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        a.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    if (a.pinned) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          '置顶',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            height: 1.2,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                if (a.date.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    a.date,
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
                if (a.content.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  _buildMarkdown(context, a.content, expanded),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMarkdown(BuildContext context, String data, bool expanded) {
    final md = MarkdownBody(
      data: data,
      shrinkWrap: true,
      styleSheet: _markdownStyle(context),
      onTapLink: (_, String? href, String? title) {
        final uri = Uri.tryParse(href ?? '');
        if (uri == null || !uri.hasScheme) return;
        context.push(
          '/webview?url=${Uri.encodeComponent(href!)}&title=${Uri.encodeComponent('公告链接')}',
        );
      },
    );
    if (expanded) {
      return md;
    }
    return SizedBox(
      height: 58,
      child: ClipRect(
        child: OverflowBox(
          alignment: Alignment.topLeft,
          maxHeight: double.infinity,
          child: md,
        ),
      ),
    );
  }

  MarkdownStyleSheet _markdownStyle(BuildContext context) {
    final theme = Theme.of(context);
    final base = MarkdownStyleSheet.fromTheme(theme);
    return base.copyWith(
      p: base.p?.copyWith(fontSize: 13, height: 1.4),
      h1: base.h1?.copyWith(fontSize: 16, fontWeight: FontWeight.bold),
      h2: base.h2?.copyWith(fontSize: 15, fontWeight: FontWeight.bold),
      h3: base.h3?.copyWith(fontSize: 14, fontWeight: FontWeight.bold),
      listBullet: base.listBullet?.copyWith(fontSize: 13, height: 1.4),
      blockquote: base.blockquote?.copyWith(fontSize: 13, height: 1.4),
      code: base.code?.copyWith(
        fontSize: 12,
        backgroundColor: theme.colorScheme.surfaceVariant,
      ),
      codeblockDecoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(6),
      ),
      blockquoteDecoration: BoxDecoration(
        color: theme.colorScheme.outlineVariant,
        borderRadius: BorderRadius.circular(4),
      ),
      a: TextStyle(
        color: theme.colorScheme.primary,
        decoration: TextDecoration.underline,
        decorationColor: theme.colorScheme.primary,
      ),
      horizontalRuleDecoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: theme.colorScheme.outlineVariant, width: 1),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
      child: Row(
        children: [
          Icon(
            Icons.person_search,
            size: 16,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 6),
          Text(
            '订阅动态',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: Divider(height: 1)),
        ],
      ),
    );
  }

  Widget _buildNotifTile(BuildContext context, ProducerNotification n) {
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
            fontWeight: n.read ? FontWeight.normal : FontWeight.bold,
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
          ref.read(followServiceProvider.notifier).markRead(n.id);
          context.push('/vn/${n.vnId}');
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
