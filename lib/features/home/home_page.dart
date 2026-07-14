import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/app_constants.dart';
import '../../core/l10n/app_localizations.dart';
import '../../core/models/vn.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/providers/endpoints_provider.dart';
import '../../core/router/app_router.dart';
import '../../widgets/async_value_widget.dart';
import '../../widgets/release_card.dart';
import '../../widgets/section_header.dart';
import 'home_provider.dart';

/// The bottom-navigation shell hosting the four main tabs.
class HomeShell extends ConsumerWidget {
  const HomeShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authNotifierProvider);
    final l10n = ref.watch(l10nProvider);
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (index) {
          // The list & profile tabs require authentication.
          if ((index == 2 || index == 3) && !auth.isAuthenticated) {
            context.push('/login');
            return;
          }
          navigationShell.goBranch(
            index,
            initialLocation: index == navigationShell.currentIndex,
          );
        },
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.home_outlined),
            selectedIcon: const Icon(Icons.home),
            label: l10n.tr('home'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.search),
            label: l10n.tr('search'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.bookmark_outline),
            selectedIcon: const Icon(Icons.bookmark),
            label: l10n.tr('list'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.person_outline),
            selectedIcon: const Icon(Icons.person),
            label: l10n.tr('profile'),
          ),
        ],
      ),
    );
  }
}

/// The home page, a vertical scroll replicating the VNDB home layout.
class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authNotifierProvider);
    final l10n = ref.watch(l10nProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('VNDB'),
        actions: [
          IconButton(
            icon: const Icon(Icons.casino),
            tooltip: l10n.tr('randomVn'),
            onPressed: () => _randomVn(context, ref),
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: l10n.tr('settings'),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.read(recommendationsSeedProvider.notifier).state++;
          await Future.wait<dynamic>([
            ref.refresh(homeDataProvider.future),
            ref.refresh(recommendationsProvider.future),
          ]);
        },
        child: ListView(
          padding: const EdgeInsets.only(bottom: 32),
          children: [
            _DonationHeader(),
            _MenuGrid(),
            const _StatsCard(),
            const _RecentChangesSection(),
            const _RecommendationsSection(),
            const _ReleasesSection(),
            const _SiteLinksSection(),
            if (auth.isAuthenticated) ...[
              const _UserMenuSection(),
              const _EditorSection(),
            ] else
              const _SignInPrompt(),
            const _FooterSection(),
          ],
        ),
      ),
    );
  }

  Future<void> _randomVn(BuildContext context, WidgetRef ref) async {
    final endpoint = ref.read(vnEndpointProvider);
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      const SnackBar(content: Text('正在抽取随机 VN…'), duration: Duration(seconds: 1)),
    );
    try {
      final vn = await endpoint.random();
      if (!context.mounted) return;
      context.push('/vn/${vn.id}');
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('失败: $e')));
    }
  }
}

class _DonationHeader extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authNotifierProvider);
    final user = auth.user;
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              auth.isAuthenticated && user != null
                  ? 'Hello, ${user.username}'
                  : 'VNDB',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          TextButton.icon(
            icon: const Icon(Icons.favorite, size: 16),
            label: const Text('Patreon'),
            onPressed: () => _openExternal(AppLinks.patreon),
          ),
          TextButton.icon(
            icon: const Icon(Icons.favorite, size: 16),
            label: const Text('SubscribeStar'),
            onPressed: () => _openExternal(AppLinks.subscribestar),
          ),
        ],
      ),
    );
  }

  void _openExternal(String url) =>
      launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
}

/// A menu grid entry with both English (original) and Chinese labels.
class _MenuEntry {
  const _MenuEntry({
    required this.label,
    required this.translatedLabel,
    required this.icon,
    required this.onTap,
  });
  final String label;
  final String translatedLabel;
  final IconData icon;
  final VoidCallback onTap;
}

class _MenuGrid extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final entries = <_MenuEntry>[
      _MenuEntry(
        label: 'Visual Novels',
        translatedLabel: '视觉小说',
        icon: Icons.book,
        onTap: () => context.push('/search'),
      ),
      _MenuEntry(
        label: 'Tags',
        translatedLabel: '标签',
        icon: Icons.label,
        onTap: () => context.push('/tags'),
      ),
      _MenuEntry(
        label: 'Releases',
        translatedLabel: '发行版本',
        icon: Icons.album,
        onTap: () => context.push('/releases'),
      ),
      _MenuEntry(
        label: 'Producers',
        translatedLabel: '制作商',
        icon: Icons.business,
        onTap: () => context.push('/producers'),
      ),
      _MenuEntry(
        label: 'Staff',
        translatedLabel: '制作人员',
        icon: Icons.people,
        onTap: () => context.push('/staff'),
      ),
      _MenuEntry(
        label: 'Characters',
        translatedLabel: '角色',
        icon: Icons.face,
        onTap: () => context.push('/characters'),
      ),
      _MenuEntry(
        label: 'Traits',
        translatedLabel: '特征',
        icon: Icons.category,
        onTap: () => context.push('/traits'),
      ),
      _MenuEntry(
        label: 'Quotes',
        translatedLabel: '语录',
        icon: Icons.format_quote,
        onTap: () => context.push('/quotes'),
      ),
      _MenuEntry(
        label: 'Users',
        translatedLabel: '用户',
        icon: Icons.group,
        onTap: () => context.push('/users'),
      ),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: GridView.count(
        crossAxisCount: 3,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        childAspectRatio: 1.3,
        children: entries
            .map((e) => Card(
                  child: InkWell(
                    onTap: e.onTap,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(e.icon, color: primary),
                        const SizedBox(height: 4),
                        Text(
                          e.translatedLabel,
                          style: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                        Text(
                          e.label,
                          style: TextStyle(
                            fontSize: 9,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ))
            .toList(),
      ),
    );
  }
}

class _StatsCard extends ConsumerWidget {
  const _StatsCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(homeDataProvider);
    return AsyncValueWidget(
      value: data,
      data: (d) => Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('数据库统计',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Wrap(
                spacing: 16,
                runSpacing: 8,
                children: [
                  _stat(context, 'VN', d.stats.vn),
                  _stat(context, 'Releases', d.stats.releases),
                  _stat(context, 'Characters', d.stats.chars),
                  _stat(context, 'Producers', d.stats.producers),
                  _stat(context, 'Staff', d.stats.staff),
                  _stat(context, 'Tags', d.stats.tags),
                  _stat(context, 'Traits', d.stats.traits),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stat(BuildContext context, String label, int count) {
    return Column(
      children: [
        Text(count.toString(),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _RecentChangesSection extends ConsumerWidget {
  const _RecentChangesSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(homeDataProvider);
    return AsyncValueWidget(
      value: data,
      data: (d) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: '最近更改',
            icon: Icons.history,
            actionLabel: '更多',
            onAction: () => openWebView(
              context,
              AppLinks.recentChanges,
              title: '最近更改',
            ),
          ),
          SizedBox(
            height: 170,
            child: d.recentVns.isEmpty
                ? const Center(child: Text('暂无'))
                : ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    itemCount: d.recentVns.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, i) {
                      final vn = d.recentVns[i];
                      return SizedBox(
                        width: 130,
                        child: _VnCard(
                          vn: vn,
                          onTap: () => context.push('/vn/${vn.id}'),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

/// "猜你喜欢" — recommendations based on the user's wishlist & finished VNs.
class _RecommendationsSection extends ConsumerWidget {
  const _RecommendationsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authNotifierProvider);
    if (!auth.isAuthenticated) return const SizedBox.shrink();
    final recs = ref.watch(recommendationsProvider);
    return AsyncValueWidget(
      value: recs,
      data: (list) {
        if (list.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader(
              title: '猜你喜欢',
              icon: Icons.recommend,
              actionLabel: '换一批',
              onAction: () {
                ref.read(recommendationsSeedProvider.notifier).state++;
                ref.invalidate(recommendationsProvider);
              },
            ),
            SizedBox(
              height: 170,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                itemCount: list.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  final vn = list[i];
                  return SizedBox(
                    width: 130,
                    child: _VnCard(
                      vn: vn,
                      onTap: () => context.push('/vn/${vn.id}'),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class _VnCard extends StatelessWidget {
  const _VnCard({required this.vn, this.onTap});
  final Vn vn;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final img = vn.image?.thumbnail ?? vn.image?.url;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 100,
              width: double.infinity,
              child: img != null
                  ? CachedNetworkImage(
                      imageUrl: img,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(
                        color: Theme.of(context).colorScheme.surface,
                      ),
                      errorWidget: (_, __, ___) => Container(
                        color: Theme.of(context).colorScheme.surface,
                        child: const Icon(Icons.book, size: 28),
                      ),
                    )
                  : Container(
                      color: Theme.of(context).colorScheme.surface,
                      child: const Icon(Icons.book, size: 28),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    vn.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (vn.released != null)
                    Text(
                      vn.released!,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReleasesSection extends ConsumerWidget {
  const _ReleasesSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(homeDataProvider);
    return AsyncValueWidget(
      value: data,
      data: (d) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: '即将发售',
            icon: Icons.upcoming,
            actionLabel: '更多',
            onAction: () => context.push('/releases'),
          ),
          SizedBox(
            height: 180,
            child: d.upcoming.isEmpty
                ? const Center(child: Text('暂无'))
                : ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    itemCount: d.upcoming.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, i) {
                      final r = d.upcoming[i];
                      return SizedBox(
                        width: 160,
                        child: ReleaseCard(
                          release: r,
                          onTap: () => context.push('/release/${r.id}'),
                        ),
                      );
                    },
                  ),
          ),
          SectionHeader(
            title: '刚刚发售',
            icon: Icons.new_releases,
            actionLabel: '更多',
            onAction: () => context.push('/releases'),
          ),
          SizedBox(
            height: 180,
            child: d.justReleased.isEmpty
                ? const Center(child: Text('暂无'))
                : ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    itemCount: d.justReleased.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, i) {
                      final r = d.justReleased[i];
                      return SizedBox(
                        width: 160,
                        child: ReleaseCard(
                          release: r,
                          onTap: () => context.push('/release/${r.id}'),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _SiteLinksSection extends StatelessWidget {
  const _SiteLinksSection();

  @override
  Widget build(BuildContext context) {
    final links = <_LinkEntry>[
      _LinkEntry('讨论版', Icons.forum, AppLinks.discussionBoard),
      _LinkEntry('FAQ', Icons.help, AppLinks.faq),
      _LinkEntry('API', Icons.code, AppLinks.apiDocs),
      _LinkEntry('Dumps', Icons.storage, AppLinks.dumps),
      _LinkEntry('数据库讨论', Icons.storage, AppLinks.dbDiscussions),
      _LinkEntry('VN 讨论', Icons.book_online, AppLinks.vnDiscussions),
      _LinkEntry('最新评测', Icons.rate_review, AppLinks.reviews),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title: '站点与社区', icon: Icons.public),
        Card(
          child: Column(
            children: links
                .map((e) => ListTile(
                      leading: Icon(e.icon),
                      title: Text(e.label),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => openWebView(context, e.url, title: e.label),
                    ))
                .toList(),
          ),
        ),
      ],
    );
  }
}

class _LinkEntry {
  const _LinkEntry(this.label, this.icon, this.url);
  final String label;
  final IconData icon;
  final String url;
}

class _UserMenuSection extends ConsumerWidget {
  const _UserMenuSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authNotifierProvider);
    final user = auth.user;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title: '我的菜单', icon: Icons.account_circle),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.person),
                title: Text('我的资料 (${user?.username ?? ""})'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => user != null ? openUserProfile(context, user.id) : null,
              ),
              ListTile(
                leading: const Icon(Icons.bookmark),
                title: const Text('我的 VN 列表'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/list'),
              ),
              ListTile(
                leading: const Icon(Icons.star),
                title: const Text('我的投票'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/list?tab=votes'),
              ),
              ListTile(
                leading: const Icon(Icons.card_giftcard),
                title: const Text('我的愿望单'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/list?tab=wishlist'),
              ),
              ListTile(
                leading: const Icon(Icons.history),
                title: const Text('我的最近更改'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => user != null
                    ? openWebView(context,
                        'https://vndb.org/${user.id}/hist', title: '我的最近更改')
                    : null,
              ),
              ListTile(
                leading: const Icon(Icons.label),
                title: const Text('我的标签'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => user != null
                    ? openWebView(context,
                        'https://vndb.org/${user.id}/tags', title: '我的标签')
                    : null,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _EditorSection extends StatelessWidget {
  const _EditorSection();

  @override
  Widget build(BuildContext context) {
    final items = <_LinkEntry>[
      _LinkEntry('图片审核', Icons.image, AppLinks.imageFlagging),
      _LinkEntry('添加 Visual Novel', Icons.add, AppLinks.addVn),
      _LinkEntry('添加 Producer', Icons.business_center, AppLinks.addProducer),
      _LinkEntry('添加 Staff', Icons.person_add, AppLinks.addStaff),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title: '编辑工具', icon: Icons.edit),
        Card(
          child: Column(
            children: items
                .map((e) => ListTile(
                      leading: Icon(e.icon),
                      title: Text(e.label),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => openWebView(context, e.url, title: e.label),
                    ))
                .toList(),
          ),
        ),
      ],
    );
  }
}

class _SignInPrompt extends StatelessWidget {
  const _SignInPrompt();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.login),
        title: const Text('登录以管理你的列表'),
        subtitle: const Text('使用 API Token 登录后可访问你的个人列表、投票与愿望单。'),
        trailing: FilledButton(
          onPressed: () => GoRouter.of(context).push('/login'),
          child: const Text('登录'),
        ),
      ),
    );
  }
}

class _FooterSection extends StatelessWidget {
  const _FooterSection();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const Divider(),
          const SizedBox(height: 8),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 12,
            children: [
              TextButton(
                onPressed: () => openWebView(context, AppLinks.privacy,
                    title: '隐私政策'),
                child: const Text('隐私政策'),
              ),
              TextButton(
                onPressed: () => context.push('/about'),
                child: const Text('关于'),
              ),
              TextButton(
                onPressed: () => context.push('/settings'),
                child: const Text('设置'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '数据来源: vndb.org · 非官方客户端',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
