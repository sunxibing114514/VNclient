import 'package:flutter/material.dart';

import '../core/models/release.dart';

/// A compact card for a release entry.
class ReleaseCard extends StatelessWidget {
  const ReleaseCard({super.key, required this.release, this.onTap});

  final Release release;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                release.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  if (release.released != null)
                    Chip(
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      padding: EdgeInsets.zero,
                      labelPadding: const EdgeInsets.symmetric(horizontal: 4),
                      label: Text(
                        release.released!,
                        style: const TextStyle(fontSize: 11),
                      ),
                    ),
                  if (release.platforms.isNotEmpty)
                    Chip(
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      padding: EdgeInsets.zero,
                      labelPadding: const EdgeInsets.symmetric(horizontal: 4),
                      label: Text(
                        release.platforms.join(', '),
                        style: const TextStyle(fontSize: 11),
                      ),
                    ),
                  if (release.official)
                    const Chip(
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      padding: EdgeInsets.zero,
                      labelPadding: EdgeInsets.symmetric(horizontal: 4),
                      label: Text('Official', style: TextStyle(fontSize: 11)),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
