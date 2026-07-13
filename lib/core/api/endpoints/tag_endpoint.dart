import '../../models/query_result.dart';
import '../../models/tag.dart';
import '../vndb_client.dart';
import 'base_endpoint.dart';

/// Encapsulates queries against the `/tag` endpoint.
class TagEndpoint extends BaseEndpoint<Tag> {
  TagEndpoint(super.client);

  static const String listFields =
      'name, category, searchable, applicable, vn_count';
  static const String detailFields =
      'name, aliases, description, category, searchable, applicable, vn_count';

  @override
  String get path => '/tag';

  @override
  Tag fromJson(Map<String, dynamic> json) => Tag.fromJson(json);

  Future<Tag> getById(String id) async {
    final result = await query(
      filters: ['id', '=', id],
      fields: detailFields,
      results: 1,
    );
    if (result.results.isEmpty) {
      throw VndbApiException(404, 'Tag $id not found');
    }
    return result.results.first;
  }

  Future<QueryResult<Tag>> search(String term, {int page = 1}) {
    return query(
      filters: term.isEmpty ? [] : ['search', '=', term],
      fields: listFields,
      sort: 'searchrank',
      page: page,
    );
  }

  Future<QueryResult<Tag>> list({
    int page = 1,
    int results = 50,
    String sort = 'name',
  }) {
    return query(
      fields: listFields,
      sort: sort,
      results: results,
      page: page,
    );
  }
}
