import '../../models/producer.dart';
import '../../models/query_result.dart';
import '../vndb_client.dart';
import 'base_endpoint.dart';

/// Encapsulates queries against the `/producer` endpoint.
class ProducerEndpoint extends BaseEndpoint<Producer> {
  ProducerEndpoint(super.client);

  static const String listFields = 'name, original, lang, type';
  static const String detailFields =
      'name, original, aliases, lang, type, description, extlinks{url,label,name,id}';

  @override
  String get path => '/producer';

  @override
  Producer fromJson(Map<String, dynamic> json) => Producer.fromJson(json);

  Future<Producer> getById(String id) async {
    final result = await query(
      filters: ['id', '=', id],
      fields: detailFields,
      results: 1,
    );
    if (result.results.isEmpty) {
      throw VndbApiException(404, 'Producer $id not found');
    }
    return result.results.first;
  }

  Future<QueryResult<Producer>> search(String term, {int page = 1}) {
    if (term.isEmpty) return list(page: page);
    return query(
      filters: ['search', '=', term],
      fields: listFields,
      sort: 'searchrank',
      page: page,
    );
  }

  /// Browse all producers, sorted by name.
  Future<QueryResult<Producer>> list({int page = 1, int results = 50}) {
    return query(
      fields: listFields,
      sort: 'name',
      results: results,
      page: page,
    );
  }
}
