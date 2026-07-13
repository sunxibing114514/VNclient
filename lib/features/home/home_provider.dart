import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/release.dart';
import '../../core/models/stats.dart';
import '../../core/models/vn.dart';
import '../../core/providers/endpoints_provider.dart';

/// Aggregated home-page data: database stats, recent VNs, upcoming &
/// just-released lists.
class HomeData {
  const HomeData({
    required this.stats,
    required this.recentVns,
    required this.upcoming,
    required this.justReleased,
  });

  final Stats stats;
  final List<Vn> recentVns;
  final List<Release> upcoming;
  final List<Release> justReleased;
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
