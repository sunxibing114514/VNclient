import 'package:flutter/material.dart';

/// A compact 5-star rating display backed by a 0-100 score.
class RatingBar extends StatelessWidget {
  const RatingBar({
    super.key,
    required this.rating,
    this.votes,
    this.starSize = 16,
    this.showValue = true,
  });

  /// Rating on the 10-100 scale (null when no votes).
  final num? rating;
  final int? votes;
  final double starSize;
  final bool showValue;

  @override
  Widget build(BuildContext context) {
    if (rating == null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.star_border, size: starSize, color: Colors.grey),
          const SizedBox(width: 4),
          Text(
            '暂无评分',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      );
    }
    final stars = (rating! / 20).clamp(0, 5);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 0; i < 5; i++)
          Icon(
            i < stars.floor()
                ? Icons.star
                : (i < stars ? Icons.star_half : Icons.star_border),
            size: starSize,
            color: const Color(0xFFf59e0b),
          ),
        if (showValue) ...[
          const SizedBox(width: 6),
          Text(
            (rating! / 10).toStringAsFixed(1),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (votes != null) ...[
            const SizedBox(width: 4),
            Text(
              '($votes)',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ],
    );
  }
}
