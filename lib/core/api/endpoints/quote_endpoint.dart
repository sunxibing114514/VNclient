import '../../models/query_result.dart';
import '../../models/quote.dart';
import '../vndb_client.dart';
import 'base_endpoint.dart';

/// Encapsulates queries against the `/quote` endpoint.
class QuoteEndpoint extends BaseEndpoint<Quote> {
  QuoteEndpoint(super.client);

  static const String listFields = 'quote, score, vn{id,title}, character{id,name}';

  @override
  String get path => '/quote';

  @override
  Quote fromJson(Map<String, dynamic> json) => Quote.fromJson(json);

  /// A single random quote, as used on the website footer.
  Future<Quote> random() async {
    final result = await query(
      filters: ['random', '=', 1],
      fields: listFields,
      results: 1,
    );
    if (result.results.isEmpty) {
      throw VndbApiException(404, 'No quotes available');
    }
    return result.results.first;
  }

  /// All quotes for a visual novel, ordered by score (desc).
  Future<QueryResult<Quote>> byVn(String vnId) {
    return query(
      filters: ['vn', '=', ['id', '=', vnId]],
      fields: listFields,
      sort: 'score',
      reverse: true,
    );
  }
}
