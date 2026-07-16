import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/models/vn.dart';
import '../core/providers/theme_provider.dart';
import '../core/theme/title_resolver.dart';
import 'rating_bar.dart';
import 'vndb_icons.dart';

/// A card representing a single visual novel, used in lists and grids.
class VnCard extends ConsumerWidget {
  const VnCard({super.key, required this.vn, this.onTap});

  final Vn vn;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final titleMode = ref.watch(
        themeNotifierProvider.select((s) => s.titleDisplay));
    final title = TitleResolver.resolve(vn, titleMode);
    final subtitle = TitleResolver.secondary(vn, titleMode);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Cover(url: vn.image?.displayUrl),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    if (subtitle != null && subtitle != title) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (vn.released != null)
                          _InfoChip(icon: Icons.calendar_today, label: vn.released!),
                        if (vn.languages.isNotEmpty)
                          VndbIcons.langRow(vn.languages),
                        if (vn.platforms.isNotEmpty)
                          VndbIcons.platRow(vn.platforms),
                      ],
                    ),
                    const SizedBox(height: 6),
                    RatingBar(rating: vn.rating, votes: vn.votecount),
                    if (vn.lengthMinutes != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        '约 ${(vn.lengthMinutes! / 60).toStringAsFixed(1)} 小时',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Cover extends StatelessWidget {
  const _Cover({this.url});
  final String? url;

  @override
  Widget build(BuildContext context) {
    if (url == null || url!.isEmpty) {
      return Container(
        width: 56,
        height: 80,
        color: Theme.of(context).colorScheme.surface,
        child: const Icon(Icons.image, size: 28),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: CachedNetworkImage(
        imageUrl: url!,
        width: 56,
        height: 80,
        fit: BoxFit.cover,
        placeholder: (_, __) => Container(
          color: Theme.of(context).colorScheme.surface,
          width: 56,
          height: 80,
        ),
        errorWidget: (_, __, ___) => Container(
          color: Theme.of(context).colorScheme.surface,
          width: 56,
          height: 80,
          child: const Icon(Icons.broken_image, size: 24),
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: Theme.of(context).textTheme.bodySmall?.color),
        const SizedBox(width: 3),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}
