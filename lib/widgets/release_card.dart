import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/models/release.dart';
import '../core/providers/theme_provider.dart';
import '../core/theme/title_resolver.dart';
import 'nsf_image.dart';

/// A compact card for a release entry, with an optional cover image.
///
/// The title follows the user's 日文/罗马音 display preference and the cover
/// is blurred for sexual/violent images when the NSFW blur setting is on.
class ReleaseCard extends ConsumerWidget {
  const ReleaseCard({super.key, required this.release, this.onTap});

  final Release release;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final titleMode =
        ref.watch(themeNotifierProvider.select((s) => s.titleDisplay));
    final title = TitleResolver.resolveSimple(
      release.title,
      release.alttitle,
      titleMode,
    );
    final img = release.images.isNotEmpty
        ? (release.images.first.image?.thumbnail ??
            release.images.first.image?.url)
        : null;
    final imageRef = release.images.isNotEmpty
        ? release.images.first.image
        : null;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // 封面
            if (img != null)
              SizedBox(
                height: 90,
                width: double.infinity,
                child: NsfImage(
                  imageUrl: img,
                  sexual: imageRef?.sexual,
                  violence: imageRef?.violence,
                  fit: BoxFit.cover,
                  placeholder: Container(
                    color:
                        Theme.of(context).colorScheme.surfaceContainerHighest,
                  ),
                  errorWidget: Container(
                    color:
                        Theme.of(context).colorScheme.surfaceContainerHighest,
                    child: const Icon(Icons.album, size: 28),
                  ),
                ),
              )
            else
              SizedBox(
                height: 90,
                width: double.infinity,
                child: Container(
                  color:
                      Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: const Icon(Icons.album, size: 28),
                ),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: [
                      if (release.released != null)
                        _MiniChip(release.released!),
                      if (release.platforms.isNotEmpty)
                        _MiniChip(release.platforms.join(', ')),
                      if (release.official)
                        const _MiniChip('Official'),
                    ],
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

class _MiniChip extends StatelessWidget {
  const _MiniChip(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: Theme.of(context).chipTheme.backgroundColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 10),
      ),
    );
  }
}
