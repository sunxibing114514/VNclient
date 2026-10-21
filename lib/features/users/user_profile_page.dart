import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/user_info.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/providers/endpoints_provider.dart';
import '../../core/router/app_router.dart';
import '../../core/services/user_hist_service.dart';
import '../../widgets/copyable_text.dart';
import '../../widgets/section_header.dart';

/// Looks up a user's public profile data (`GET /user`) by id.
final userRecordProvider = FutureProvider.autoDispose
    .family<UserRecord?, String>((ref, userId) async {
  final record = await ref
      .watch(userEndpointProvider)
      .get(userId, fields: 'lengthvotes,lengthvotes_sum');
  return record;
});

/// Parameters for [userEditsProvider].
class UserEditsQuery {
  const UserEditsQuery({required this.userId, required this.page});

  final String userId;
  final int page;

  @override
  bool operator ==(Object other) =>
      other is UserEditsQuery &&
      other.userId == userId &&
      other.page == page;

  @override
  int get hashCode => Object.hash(userId, page);
}

/// One page of a user's edit history (`/u<id>/hist` on the website,
/// parsed natively so no WebView is needed).
final userEditsProvider = FutureProvider.autoDispose
    .family<List<UserEditEntry>, UserEditsQuery>((ref, query) {
  return ref.watch(userHistServiceProvider).fetch(
        query.userId,
        page: query.page,
      );
});

/// Native profile page for any VNDB user, shown at `/user/:id`.
///
/// Everything is rendered inside the client:
///  - 详细信息: username, id, play-time vote stats (`GET /user`);
///  - 列表: the user's public VN list, votes and wishlist, browsed
///    natively via `POST /ulist` / `GET /ulist_labels` (no WebView);
///  - 最近编辑: the user's contribution history parsed from the site.
///
/// When the requested id happens to be the signed-in user, the own-list
/// shortcuts and the token permission chips are shown instead of the
/// "other user" affordances.
class UserProfilePage extends ConsumerStatefulWidget {
  const UserProfilePage({super.key, required this.userId});

  final String userId;

  @override
  ConsumerState<UserProfilePage> createState() => _UserProfilePageState();
}

class _UserProfilePageState extends ConsumerState<UserProfilePage> {
  /// How many edit-history pages have been loaded.
  int _editPages = 1;

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authNotifierProvider);
    final recordAsync = ref.watch(userRecordProvider(widget.userId));
    final isSelf = auth.user?.id == widget.userId;

    return Scaffold(
      appBar: AppBar(
        title: Text(recordAsync.maybeWhen(
          data: (r) => r?.username ?? widget.userId,
          orElse: () => widget.userId,
        )),
      ),
      body: recordAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48),
              const SizedBox(height: 12),
              Text('$e'),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () =>
                    ref.invalidate(userRecordProvider(widget.userId)),
                child: const Text('重试'),
              ),
            ],
          ),
        ),
        data: (record) {
          final username = record?.username ?? widget.userId;
          return ListView(
            padding: const EdgeInsets.only(bottom: 32),
            children: [
              const SizedBox(height: 16),
              // --- Avatar + name ---
              CircleAvatar(
                radius: 40,
                child: Text(
                  username.isNotEmpty
                      ? username.substring(0, 1).toUpperCase()
                      : '?',
                  style: const TextStyle(fontSize: 32),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: CopyableText(
                  text: username,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              Center(
                child: CopyableText(
                  text: widget.userId,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              // --- Token permission chips (own account only) ---
              if (isSelf && auth.user != null) ...[
                const SizedBox(height: 8),
                Center(
                  child: Wrap(
                    spacing: 8,
                    children: [
                      if (auth.user!.canReadList)
                        const Chip(label: Text('listread')),
                      if (auth.user!.canWriteList)
                        const Chip(label: Text('listwrite')),
                    ],
                  ),
                ),
              ],
              // --- 详细信息 ---
              SectionHeader(title: '详细信息', icon: Icons.info_outline),
              ListTile(
                dense: true,
                leading: const Icon(Icons.badge, size: 20),
                title: const Text('用户名'),
                trailing: CopyableText(
                  text: username,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
              ListTile(
                dense: true,
                leading: const Icon(Icons.tag, size: 20),
                title: const Text('ID'),
                trailing: CopyableText(
                  text: widget.userId,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
              if (record?.lengthvotes != null)
                ListTile(
                  dense: true,
                  leading: const Icon(Icons.schedule, size: 20),
                  title: const Text('游戏时长投票'),
                  trailing: Text('${record!.lengthvotes} 条'),
                ),
              if (record?.lengthvotesSum != null && record!.lengthvotesSum! > 0)
                ListTile(
                  dense: true,
                  leading: const Icon(Icons.timelapse, size: 20),
                  title: const Text('总游戏时长'),
                  trailing: Text(
                    '${(record.lengthvotesSum! / 60).toStringAsFixed(1)} 小时',
                  ),
                ),
              // --- 游戏时长投票 ---
              // Kana API 未提供提交时长投票的接口 (api-kana.md 仅提供
              // lengthvotes / lengthvotes_sum 读取字段), 网页版可查看并
              // 提交投票。
              ListTile(
                dense: true,
                leading: const Icon(Icons.how_to_vote, size: 20),
                title: const Text('游戏时长投票'),
                subtitle: const Text('在网页版查看 / 提交时长投票',
                    style: TextStyle(fontSize: 11)),
                trailing: const Icon(Icons.chevron_right, size: 18),
                onTap: () => openWebView(
                  context,
                  'https://vndb.org/${widget.userId}/lengthvotes',
                  title: '时长投票',
                ),
              ),
              // --- 列表 ---
              SectionHeader(title: isSelf ? '我的列表' : 'TA 的列表', icon: Icons.bookmark),
              ListTile(
                leading: const Icon(Icons.bookmark),
                title: Text(isSelf ? '我的 VN 列表' : 'TA 的 VN 列表'),
                subtitle: const Text('在客户端内查看'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push(
                    isSelf ? '/list' : '/user/${widget.userId}/list'),
              ),
              ListTile(
                leading: const Icon(Icons.star),
                title: Text(isSelf ? '我的投票' : 'TA 的投票'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push(isSelf
                    ? '/list?tab=votes'
                    : '/user/${widget.userId}/list?tab=votes'),
              ),
              ListTile(
                leading: const Icon(Icons.card_giftcard),
                title: Text(isSelf ? '我的愿望单' : 'TA 的愿望单'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push(isSelf
                    ? '/list?tab=wishlist'
                    : '/user/${widget.userId}/list?tab=wishlist'),
              ),
              // --- 最近编辑 (native, no WebView) ---
              SectionHeader(
                title: isSelf ? '我的最近编辑' : 'TA 的最近编辑',
                icon: Icons.history,
              ),
              _buildEditsSection(),
            ],
          );
        },
      ),
    );
  }

  /// The native edit-history list with incremental "load more" pages.
  Widget _buildEditsSection() {
    return Column(
      children: [
        for (var p = 1; p <= _editPages; p++)
          _EditsPage(userId: widget.userId, page: p),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: OutlinedButton.icon(
            icon: const Icon(Icons.expand_more, size: 18),
            label: const Text('加载更多'),
            onPressed: () => setState(() => _editPages++),
          ),
        ),
      ],
    );
  }
}

/// A single page of the edit history.
class _EditsPage extends ConsumerWidget {
  const _EditsPage({required this.userId, required this.page});

  final String userId;
  final int page;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(userEditsProvider(UserEditsQuery(
      userId: userId,
      page: page,
    )));

    return async.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      error: (e, _) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text('编辑记录加载失败: $e',
                style: const TextStyle(fontSize: 12),
                textAlign: TextAlign.center),
            TextButton(
              onPressed: () => ref.invalidate(userEditsProvider(UserEditsQuery(
                userId: userId,
                page: page,
              ))),
              child: const Text('重试'),
            ),
          ],
        ),
      ),
      data: (entries) {
        if (entries.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: Text('暂无编辑记录')),
          );
        }
        return Column(
          children: [
            for (final e in entries)
              ListTile(
                dense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                leading: SizedBox(
                  width: 56,
                  child: Text(
                    e.entryId,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                title: CopyableText(
                  text: e.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(e.date,
                        style: Theme.of(context).textTheme.bodySmall),
                    if (e.comment != null)
                      Text(
                        e.comment!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                  ],
                ),
                onTap: () {
                  final route = e.route;
                  if (route != null) {
                    context.push(route);
                  } else {
                    // Entry types without an in-app page (e.g. docs).
                    context.push(
                        '/webview?url=${Uri.encodeComponent('https://vndb.org/${e.revId}')}&title=${Uri.encodeComponent(e.title)}');
                  }
                },
              ),
          ],
        );
      },
    );
  }
}
