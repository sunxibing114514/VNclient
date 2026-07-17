import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../core/models/release.dart';
import '../../core/models/stats.dart';
import '../../core/models/vn.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/providers/endpoints_provider.dart';

/// A counter that is bumped each time the user wants new random
/// recommendations. Watching it inside [recommendationsProvider] ensures the
/// provider re-runs (and thus re-shuffles) on every refresh.
final recommendationsSeedProvider = StateProvider<int>((ref) => 0);

/// Aggregated home-page data: database stats, recent VNs, upcoming &
/// just-released lists.
class HomeData {
  const HomeData({
    required this.stats,
    required this.recentVns,
    required this.upcoming,
    required this.justReleased,
    this.recommendations = const [],
  });

  final Stats stats;
  final List<Vn> recentVns;
  final List<Release> upcoming;
  final List<Release> justReleased;
  final List<Vn> recommendations;
}

final homeDataProvider = FutureProvider.autoDispose<HomeData>((ref) async {
  final stats = ref.watch(statsEndpointProvider);
  final releases = ref.watch(releaseEndpointProvider);
  final vns = ref.watch(vnEndpointProvider);

  final results = await Future.wait<dynamic>([
    stats.getStats(),
    vns.getRecent(limit: 10),
    releases.getUpcoming(limit: 10),
    releases.getJustReleased(limit: 10),
  ]);

  return HomeData(
    stats: results[0] as Stats,
    recentVns: (results[1] as dynamic).results as List<Vn>,
    upcoming: (results[2] as dynamic).results as List<Release>,
    justReleased: (results[3] as dynamic).results as List<Release>,
  );
});

/// Recommendations based on the tags of the user's wishlist & finished VNs.
/// Aggregates the top tags from those list entries and queries for VNs
/// sharing those tags, then **shuffles** the pool so every refresh returns a
/// different random subset — excluding entries the user already has.
final recommendationsProvider =
    FutureProvider.autoDispose<List<Vn>>((ref) async {
  // Watch the seed so bumping it triggers a fresh shuffle.
  ref.watch(recommendationsSeedProvider);
  final rng = Random();

  final auth = ref.watch(authNotifierProvider);
  if (!auth.isAuthenticated) return const [];
  final userId = auth.user?.id;
  if (userId == null) return const [];

  final listEndpoint = ref.watch(listEndpointProvider);
  final vnEndpoint = ref.watch(vnEndpointProvider);

  // Collect VN ids and tag ids from wishlist (5) and finished (2) labels.
  final ownedVnIds = <String>{};
  final tagScores = <String, num>{};

  for (final labelId in [
    AppConstants.labelWishlist,
    AppConstants.labelFinished,
  ]) {
    try {
      final res = await listEndpoint.getList(
        userId,
        labelId: labelId,
        results: 50,
      );
      for (final entry in res.results) {
        final vn = entry.vn;
        if (vn == null) continue;
        ownedVnIds.add(vn.id);
        for (final tag in vn.tags) {
          tagScores[tag.id] = (tagScores[tag.id] ?? 0) + tag.rating;
        }
      }
    } catch (_) {
      // ignore — recommendations are best-effort
    }
  }

  if (tagScores.isEmpty) return const [];

  // Pick the top tag ids by aggregate score, then shuffle the tag order so
  // different tags take priority on each refresh.
  final sortedTags = tagScores.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  final topTags = sortedTags.take(8).map((e) => e.key).toList();
  topTags.shuffle(rng);

  // Fetch a larger pool (100) so we have enough material to randomise.
  try {
    final result = await vnEndpoint.byTags(topTags, results: 100);
    final pool = result.results.where((vn) => !ownedVnIds.contains(vn.id)).toList();
    // Completely shuffle the pool and pick 10.
    pool.shuffle(rng);
    return pool.take(10).toList();
  } catch (_) {
    return const [];
  }
});
