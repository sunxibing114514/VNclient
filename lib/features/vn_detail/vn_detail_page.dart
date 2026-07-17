import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/release.dart';
import '../../core/models/character.dart';
import '../../core/models/vn.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/providers/detail_providers.dart';
import '../../core/providers/theme_provider.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/title_resolver.dart';
import '../../widgets/async_value_widget.dart';
import '../../widgets/nsf_image.dart';
import '../../widgets/section_header.dart';
import '../../widgets/vndb_icons.dart';
import 'list_edit_dialog.dart';
import 'vote_dialog.dart';

/// Detailed view for a single visual novel.
class VnDetailPage extends ConsumerWidget {
  const VnDetailPage({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vn = ref.watch(vnDetailProvider(id));
    return Scaffold(
      body: AsyncValueWidget(
        value: vn,
        data: (data) => _VnDetailView(vn: data, id: id),
        errorRetry: () => ref.invalidate(vnDetailProvider(id)),
      ),
      floatingActionButton: vn.maybeWhen(
        data: (d) => _AddToListFab(vnId: d.id),
        orElse: () => const SizedBox.shrink(),
      ),
    );
  }
}

class _AddToListFab extends ConsumerWidget {
  const _AddToListFab({required this.vnId});
  final String vnId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authNotifierProvider);
    if (!auth.canWriteList) return const SizedBox.shrink();
    return FloatingActionButton.extended(
      icon: const Icon(Icons.bookmark_add),
      label: const Text('加入列表'),
      onPressed: () => showDialog<void>(
        context: context,
        builder: (_) => ListEditDialog(vnId: vnId),
      ),
    );
  }
}

class _VnDetailView extends ConsumerStatefulWidget {
  const _VnDetailView({required this.vn, required this.id});

  final Vn vn;
  final String id;

  @override
  ConsumerState<_VnDetailView> createState() => _VnDetailViewState();
}

class _VnDetailViewState extends ConsumerState<_VnDetailView>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vn = widget.vn;
    final releases = ref.watch(releasesByVnProvider(widget.id));
    final characters = ref.watch(charactersByVnProvider(widget.id));
    final titleMode =
        ref.watch(themeNotifierProvider.select((s) => s.titleDisplay));
    final displayTitle = TitleResolver.resolve(vn, titleMode);
    final secondaryTitle = TitleResolver.secondary(vn, titleMode);

    return CustomScrollView(
      slivers: [
        // --- 1. Glassmorphism top nav bar ---
        SliverAppBar(
          pinned: true,
          expandedHeight: 0,
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          leading: _GlassButton(
            icon: Icons.arrow_back,
            onTap: () => Navigator.of(context).maybePop(),
          ),
          actions: [
            _GlassButton(
              icon: Icons.share,
              onTap: () => _shareVn(context, vn),
            ),
            _GlassButton(
              icon: Icons.search,
              onTap: () => context.push('/search'),
            ),
            const SizedBox(width: 8),
          ],
          flexibleSpace: _GlassAppBarBackground(imageUrl: vn.image?.url),
        ),

        // --- 2. Main info area: left cover + right text ---
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Cover with rounded corners + shadow
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.4),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: SizedBox(
                      width: 120,
                      height: 170,
                      child: nsfImageFromRef(
                        vn.image,
                        fit: BoxFit.cover,
                        placeholder: Container(
                          color: Theme.of(context).colorScheme.surfaceContainerHighest,
                          child: const Icon(Icons.book, size: 40),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                // Right side: title + dev/play status
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayTitle,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          shadows: [
                            Shadow(color: Colors.black54, blurRadius: 4),
                          ],
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (secondaryTitle != null &&
                          secondaryTitle != displayTitle) ...[
                        const SizedBox(height: 4),
                        Text(
                          secondaryTitle,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white.withValues(alpha: 0.8),
                            shadows: const [
                              Shadow(color: Colors.black54, blurRadius: 4),
                            ],
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const SizedBox(height: 8),
                      // Developer + play status in gray
                      if (vn.developers.isNotEmpty)
                        Text(
                          vn.developers.map((d) => d.name).join(', '),
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.white.withValues(alpha: 0.7),
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      const SizedBox(height: 4),
                      Text(
                        [
                          vn.devStatusLabel,
                          if (vn.released != null) vn.released!,
                        ].join(' · '),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        // --- 3. Stats area: 3 columns (votes / rating / duration) ---
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
            child: Row(
              children: [
                _StatColumn(
                  label: '投票',
                  value: '${vn.votecount}',
                ),
                _StatColumn(
                  label: '评分',
                  value: vn.rating != null
                      ? (vn.rating! / 10).toStringAsFixed(1)
                      : '-',
                  onTap: () => _openVote(context, vn),
                ),
                _StatColumn(
                  label: '时长',
                  value: vn.lengthMinutes != null
                      ? '${(vn.lengthMinutes! / 60).toStringAsFixed(1)}h'
                      : vn.lengthLabel,
                ),
              ],
            ),
          ),
        ),

        // --- 4. Tab bar ---
        SliverToBoxAdapter(
          child: TabBar(
            controller: _tabController,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: const [
              Tab(text: '概况'),
              Tab(text: '角色'),
              Tab(text: '版本'),
              Tab(text: '人员'),
            ],
          ),
        ),

        // --- 5. Tab content ---
        SliverFillRemaining(
          hasScrollBody: true,
          child: TabBarView(
            controller: _tabController,
            children: [
              // Overview tab
              _OverviewTab(
                vn: vn,
                releases: releases,
                characters: characters,
              ),
              // Characters tab
              _CharactersTab(characters: characters),
              // Releases tab
              _ReleasesTab(releases: releases),
              // Staff tab
              _StaffTab(vn: vn),
            ],
          ),
        ),

        const SliverToBoxAdapter(child: SizedBox(height: 80)),
      ],
    );
  }

  void _shareVn(BuildContext context, Vn vn) async {
    final url = 'https://vndb.org/${vn.id}';
    await Clipboard.setData(ClipboardData(text: url));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已复制链接: $url'), duration: const Duration(seconds: 2)),
    );
  }

  /// Opens the quick vote dialog. Requires an authenticated user with list
  /// write permission (voting is implemented via PATCH /ulist/<id> with the
  /// `vote` field, which is the VNDB mechanism for casting a rating).
  void _openVote(BuildContext context, Vn vn) {
    final auth = ref.read(authNotifierProvider);
    if (!auth.canWriteList) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先登录并在 VNDB 获取 listwrite 权限的 Token 以投票')),
      );
      return;
    }
    showDialog<bool>(
      context: context,
      builder: (_) => VoteDialog(vnId: vn.id, vnTitle: vn.title),
    ).then((voted) {
      if (voted == true && context.mounted) {
        ref.invalidate(vnDetailProvider(vn.id));
      }
    });
  }
}

/// A circular glassmorphism button used in the app bar.
class _GlassButton extends StatelessWidget {
  const _GlassButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(6),
      child: GestureDetector(
        onTap: onTap,
        child: ClipOval(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.3),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: Colors.white, size: 22),
            ),
          ),
        ),
      ),
    );
  }
}

/// Blurred background image for the app bar area.
class _GlassAppBarBackground extends StatelessWidget {
  const _GlassAppBarBackground({this.imageUrl});
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    if (imageUrl == null || imageUrl!.isEmpty) {
      return Container(color: Theme.of(context).colorScheme.surface);
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        CachedNetworkImage(
          imageUrl: imageUrl!,
          fit: BoxFit.cover,
          placeholder: (_, __) =>
              Container(color: Theme.of(context).colorScheme.surface),
          errorWidget: (_, __, ___) =>
              Container(color: Theme.of(context).colorScheme.surface),
        ),
        // Dark gradient overlay for text legibility
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0.5),
                Colors.black.withValues(alpha: 0.7),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// A three-column stat display: label on top, value below.
class _StatColumn extends StatelessWidget {
  const _StatColumn({required this.label, required this.value, this.onTap});
  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
    if (onTap == null) return Expanded(child: content);
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: content,
        ),
      ),
    );
  }
}

// ---- Tab content widgets ----

/// Overview tab: description, tags, screenshots, relations, extlinks.
class _OverviewTab extends ConsumerWidget {
  const _OverviewTab({
    required this.vn,
    required this.releases,
    required this.characters,
  });

  final Vn vn;
  final AsyncValue<List<Release>> releases;
  final AsyncValue<List<Character>> characters;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Description
        _Section(title: '简介', child: Text(
          vn.description ?? '暂无简介',
          style: Theme.of(context).textTheme.bodyMedium,
        )),
        // Info rows
        _Section(title: '详情', child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (vn.platforms.isNotEmpty)
              _IconInfoRow(
                label: '平台',
                icons: VndbIcons.platRow(vn.platforms, size: 16),
                text: vn.platforms.join(', '),
              ),
            if (vn.languages.isNotEmpty)
              _IconInfoRow(
                label: '语言',
                icons: VndbIcons.langRow(vn.languages, size: 16),
                text: vn.languages.join(', '),
              ),
            if (vn.olang != null) _InfoRow('原始语言', vn.olang!),
            if (vn.lengthMinutes != null)
              _InfoRow('时长', '约 ${(vn.lengthMinutes! / 60).toStringAsFixed(1)} 小时 (${vn.lengthLabel})'),
            if (vn.developers.isNotEmpty)
              _InfoChipRow(
                label: '开发商',
                chips: vn.developers.map((d) => _NamedChip(
                  id: d.id, name: d.name, routePrefix: '/producer',
                )).toList(),
              ),
            if (releases.hasValue && releases.value!.isNotEmpty)
              _PublisherRow(releases: releases.value!),
          ],
        )),
        // Aliases
        if (vn.aliases.isNotEmpty)
          _Section(title: '别名', child: Text(
            vn.aliases.join(', '),
            style: Theme.of(context).textTheme.bodyMedium,
          )),
        // Tags (collapsible)
        if (vn.tags.isNotEmpty)
          _CollapsibleTagsSection(tags: vn.tags),
        // Screenshots
        if (vn.screenshots.isNotEmpty) ...[
          const SizedBox(height: 8),
          const SectionHeader(
              title: '截图', icon: Icons.photo, padding: EdgeInsets.zero),
          const SizedBox(height: 8),
          SizedBox(
            height: 180,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: vn.screenshots.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final shot = vn.screenshots[i];
                final url = shot.image?.url ?? shot.image?.thumbnail;
                return GestureDetector(
                  onTap: () => _showFullScreen(context, url),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      width: 240,
                      child: nsfImageFromRef(
                        shot.image,
                        fit: BoxFit.cover,
                        width: 240,
                        placeholder: Container(
                          width: 240,
                          color: Theme.of(context).colorScheme.surfaceContainerHighest,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
        // Relations
        if (vn.relations.isNotEmpty) ...[
          const SizedBox(height: 12),
          const SectionHeader(
              title: '相关作品', icon: Icons.link, padding: EdgeInsets.zero),
          for (final r in vn.relations)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(r.title),
              subtitle: Text(r.relation +
                  (r.released != null ? ' · ${r.released}' : '')),
              onTap: () => context.push('/vn/${r.id}'),
            ),
        ],
        // External links
        if (vn.extlinks.isNotEmpty) ...[
          const SizedBox(height: 12),
          const SectionHeader(
              title: '外部链接',
              icon: Icons.link_outlined,
              padding: EdgeInsets.zero),
          for (final link in vn.extlinks)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(link.label),
              trailing: const Icon(Icons.open_in_new, size: 18),
              onTap: () => openWebView(context, link.url, title: link.label),
            ),
        ],
        const SizedBox(height: 16),
      ],
    );
  }

  void _showFullScreen(BuildContext context, String? url) {
    if (url == null) return;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => Scaffold(
        backgroundColor: Colors.black,
        body: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Center(
            child: InteractiveViewer(
              child: CachedNetworkImage(imageUrl: url),
            ),
          ),
        ),
      ),
    ));
  }
}

/// Characters tab.
class _CharactersTab extends StatelessWidget {
  const _CharactersTab({required this.characters});
  final AsyncValue<List<Character>> characters;

  @override
  Widget build(BuildContext context) {
    return AsyncValueWidget(
      value: characters,
      data: (list) {
        if (list.isEmpty) {
          return const Center(child: Text('暂无角色'));
        }
        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate:
              const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 140,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 0.6,
          ),
          itemCount: list.length,
          itemBuilder: (context, i) =>
              _CharacterTile(character: list[i]),
        );
      },
    );
  }
}

/// Releases tab.
class _ReleasesTab extends StatelessWidget {
  const _ReleasesTab({required this.releases});
  final AsyncValue<List<Release>> releases;

  @override
  Widget build(BuildContext context) {
    return AsyncValueWidget(
      value: releases,
      data: (list) {
        if (list.isEmpty) {
          return const Center(child: Text('暂无发行版本'));
        }
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [_ReleaseGroups(releases: list)],
        );
      },
    );
  }
}

/// Staff tab.
class _StaffTab extends StatelessWidget {
  const _StaffTab({required this.vn});
  final Vn vn;

  @override
  Widget build(BuildContext context) {
    if (vn.staff.isEmpty) {
      return const Center(child: Text('暂无制作人员'));
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [_StaffByRole(staff: vn.staff)],
    );
  }
}

// ---- Shared widgets ----

/// A section with a bold title and content below it.
class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          child,
        ],
      ),
    );
  }
}

/// A tags section with category filtering (content / technical / ero),
/// spoiler-level control (hide / show minor / spoil me) and a summary view.
///
/// Mirrors the VNDB website tag panel:
/// - Categories: 全部 (all) / 内容 (cont) / 技术 (tech) / 色情 (ero)
/// - Spoiler levels: 隐藏剧透 (0) / 显示轻微剧透 (1) / 全部剧透 (2)
/// - Summary mode: collapses the list to the top-rated tags per category.
class _CollapsibleTagsSection extends StatefulWidget {
  const _CollapsibleTagsSection({required this.tags});
  final List<dynamic> tags;

  @override
  State<_CollapsibleTagsSection> createState() =>
      _CollapsibleTagsSectionState();
}

class _CollapsibleTagsSectionState extends State<_CollapsibleTagsSection> {
  /// Selected category filter: null = all.
  String? _category;
  /// Maximum spoiler level to display (0, 1 or 2).
  int _spoilerLevel = 0;
  /// Whether the summary (top tags only) view is active.
  bool _summary = true;
  static const int _summaryCount = 8;

  @override
  Widget build(BuildContext context) {
    final filtered = widget.tags.where((t) {
      if (_category != null && t.category != _category) return false;
      // Hide tags whose spoiler level exceeds the chosen threshold.
      if ((t.spoiler as int) > _spoilerLevel) return false;
      return true;
    }).toList()
      ..sort((a, b) => (b.rating as num).compareTo(a.rating as num));

    final visible = _summary && filtered.length > _summaryCount
        ? filtered.sublist(0, _summaryCount)
        : filtered;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Text(
                  '标签 (${widget.tags.length})',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                if (filtered.length > _summaryCount)
                  TextButton.icon(
                    icon: Icon(_summary ? Icons.expand : Icons.compress,
                        size: 16),
                    label: Text(_summary ? '全部' : '摘要'),
                    onPressed: () =>
                        setState(() => _summary = !_summary),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          // Category filter chips.
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              _filterChip('全部', null),
              _filterChip('内容', 'cont'),
              _filterChip('技术', 'tech'),
              _filterChip('色情', 'ero'),
            ],
          ),
          const SizedBox(height: 4),
          // Spoiler-level segmented control.
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              _spoilerChip('隐藏剧透', 0),
              _spoilerChip('显示轻微剧透', 1),
              _spoilerChip('全部剧透', 2),
            ],
          ),
          const SizedBox(height: 8),
          if (visible.isEmpty)
            Text('当前筛选下无标签',
                style: Theme.of(context).textTheme.bodySmall)
          else
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: visible.map<Widget>((t) {
                final lie = (t.lie as bool?) == true;
                return ActionChip(
                  avatar: lie
                      ? const Icon(Icons.close, size: 14)
                      : (_spoilerLevel > 0 && (t.spoiler as int) > 0
                          ? const Icon(Icons.warning_amber,
                              size: 14)
                          : null),
                  label: Text('${t.name} (${(t.rating as num).toStringAsFixed(1)})'),
                  onPressed: () => context.push('/tag/${t.id}'),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _filterChip(String label, String? value) {
    final selected = _category == value;
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => setState(() => _category = selected ? null : value),
    );
  }

  Widget _spoilerChip(String label, int value) {
    final selected = _spoilerLevel == value;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => setState(() => _spoilerLevel = value),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    if (value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 64,
            child: Text(label,
                style: Theme.of(context).textTheme.bodySmall),
          ),
          Expanded(child: Text(value, style: Theme.of(context).textTheme.bodyMedium)),
        ],
      ),
    );
  }
}

/// Like [_InfoRow] but leads the value with a row of icon widgets (e.g.
/// language flags / platform icons) followed by the textual code list.
class _IconInfoRow extends StatelessWidget {
  const _IconInfoRow({
    required this.label,
    required this.icons,
    required this.text,
  });
  final String label;
  final Widget icons;
  final String text;

  @override
  Widget build(BuildContext context) {
    if (text.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 64,
            child: Text(label,
                style: Theme.of(context).textTheme.bodySmall),
          ),
          Expanded(
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 6,
              runSpacing: 4,
              children: [
                icons,
                Text(text, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CharacterTile extends StatelessWidget {
  const _CharacterTile({required this.character});
  final Character character;

  @override
  Widget build(BuildContext context) {
    final url = character.image?.thumbnail ?? character.image?.url;
    return GestureDetector(
      onTap: () => context.push('/character/${character.id}'),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 160,
              child: url == null
                  ? Container(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      child: const Icon(Icons.person, size: 40),
                    )
                  : nsfImageFromRef(
                      character.image,
                      fit: BoxFit.cover,
                      height: 160,
                      placeholder: Container(
                        height: 160,
                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                        child: const Icon(Icons.person, size: 40),
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            character.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12),
          ),
          if (character.roleDisplay.isNotEmpty)
            Text(
              character.roleLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 10),
            ),
        ],
      ),
    );
  }
}

class _ReleaseGroups extends StatelessWidget {
  const _ReleaseGroups({required this.releases});
  final List<Release> releases;

  @override
  Widget build(BuildContext context) {
    final groups = <String, List<Release>>{};
    for (final r in releases) {
      final langs = r.languages.map((l) => l.lang).toList();
      final key = langs.isEmpty ? '未知' : langs.first;
      groups.putIfAbsent(key, () => []).add(r);
    }
    final keys = groups.keys.toList()..sort();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final key in keys) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            margin: const EdgeInsets.only(top: 8, bottom: 6),
            decoration: BoxDecoration(
              color: Theme.of(context)
                  .colorScheme
                  .primaryContainer
                  .withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '$key (${groups[key]!.length})',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
            ),
          ),
          for (final r in groups[key]!)
            Card(
              margin: const EdgeInsets.only(bottom: 4),
              child: ListTile(
                dense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                title: Text(
                  r.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 14),
                ),
                subtitle: Text(
                  [
                    if (r.released != null) r.released,
                    if (r.platforms.isNotEmpty) r.platforms.join(', '),
                    if (r.official) 'Official' else 'Unofficial',
                  ].join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: const Icon(Icons.chevron_right, size: 18),
                onTap: () => context.push('/release/${r.id}'),
              ),
            ),
        ],
      ],
    );
  }
}

class _NamedChip {
  const _NamedChip({required this.id, required this.name, required this.routePrefix});
  final String id;
  final String name;
  final String routePrefix;
}

class _InfoChipRow extends StatelessWidget {
  const _InfoChipRow({required this.label, required this.chips});
  final String label;
  final List<_NamedChip> chips;

  @override
  Widget build(BuildContext context) {
    if (chips.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 64,
            child: Text(label, style: Theme.of(context).textTheme.bodySmall),
          ),
          Expanded(
            child: Wrap(
              spacing: 6,
              runSpacing: 4,
              children: chips
                  .map((c) => ActionChip(
                        label: Text(c.name),
                        onPressed: () => context.push('${c.routePrefix}/${c.id}'),
                      ))
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _PublisherRow extends StatelessWidget {
  const _PublisherRow({required this.releases});
  final List<Release> releases;

  @override
  Widget build(BuildContext context) {
    final seen = <String>{};
    final publishers = <_NamedChip>[];
    for (final r in releases) {
      for (final p in r.producers) {
        if (p.publisher && p.id.isNotEmpty && seen.add(p.id)) {
          publishers.add(_NamedChip(
            id: p.id,
            name: p.name,
            routePrefix: '/producer',
          ));
        }
      }
    }
    return _InfoChipRow(label: '发行商', chips: publishers);
  }
}

class _StaffByRole extends StatelessWidget {
  const _StaffByRole({required this.staff});
  final List<VnStaff> staff;

  @override
  Widget build(BuildContext context) {
    final byRole = <String, List<VnStaff>>{};
    for (final s in staff) {
      final role = s.role.isEmpty ? '其他' : s.role;
      byRole.putIfAbsent(role, () => []).add(s);
    }
    final roles = byRole.keys.toList()..sort();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final role in roles) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            margin: const EdgeInsets.only(top: 8, bottom: 6),
            decoration: BoxDecoration(
              color: Theme.of(context)
                  .colorScheme
                  .primaryContainer
                  .withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '$role (${byRole[role]!.length})',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
            ),
          ),
          for (final s in byRole[role]!)
            Card(
              margin: const EdgeInsets.only(bottom: 4),
              child: ListTile(
                dense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                title: Text(s.name),
                subtitle: s.note != null && s.note!.isNotEmpty
                    ? Text(s.note!,
                        maxLines: 1, overflow: TextOverflow.ellipsis)
                    : null,
                trailing: const Icon(Icons.chevron_right, size: 18),
                onTap: () => context.push('/staff/${s.id}'),
              ),
            ),
        ],
      ],
    );
  }
}
