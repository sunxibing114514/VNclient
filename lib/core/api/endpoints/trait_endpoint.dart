import '../../models/query_result.dart';
import '../../models/trait.dart';
import '../vndb_client.dart';
import 'base_endpoint.dart';

/// Encapsulates queries against the `/trait` endpoint.
class TraitEndpoint extends BaseEndpoint<Trait> {
  TraitEndpoint(super.client);

  static const String listFields =
      'name, group_id, group_name, searchable, applicable, sexual, char_count';
  static const String detailFields =
      'name, aliases, description, searchable, applicable, sexual, group_id,'
      'group_name, char_count';

  @override
  String get path => '/trait';

  @override
  Trait fromJson(Map<String, dynamic> json) => Trait.fromJson(json);

  @override
  String get defaultSort => 'name';

  Future<Trait> getById(String id) async {
    final result = await query(
      filters: ['id', '=', id],
      fields: detailFields,
      results: 1,
    );
    if (result.results.isEmpty) {
      throw VndbApiException(404, 'Trait $id not found');
    }
    return result.results.first;
  }

  Future<QueryResult<Trait>> search(String term, {int page = 1}) {
    return query(
      filters: term.isEmpty ? [] : ['search', '=', term],
      fields: listFields,
      sort: 'searchrank',
      page: page,
    );
  }

  Future<QueryResult<Trait>> list({
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
