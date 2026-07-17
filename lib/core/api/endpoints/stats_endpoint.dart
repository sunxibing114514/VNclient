import '../../models/stats.dart';
import '../vndb_client.dart';

/// Encapsulates the `GET /stats` endpoint.
class StatsEndpoint {
  StatsEndpoint(this.client);

  final VndbClient client;

  Future<Stats> getStats() async {
    final json = await client.get('/stats');
    return Stats.fromJson(json);
  }
}
