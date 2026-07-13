import '../../models/character.dart';
import '../../models/query_result.dart';
import '../vndb_client.dart';
import 'base_endpoint.dart';

/// Encapsulates queries against the `/character` endpoint.
class CharacterEndpoint extends BaseEndpoint<Character> {
  CharacterEndpoint(super.client);

  static const String listFields =
      'name, original, image{id,url,dims,sexual,violence},'
      'vns{role,id,title}';

  static const String detailFields =
      'name, original, aliases, description, image{id,url,dims,sexual,violence},'
      'blood_type, height, weight, bust, waist, hips, cup, age, birthday, sex, gender,'
      'vns{spoiler,role,id,title,release{id,title}},'
      'traits{id,name,spoiler,lie,group_id,group_name,sexual}';

  @override
  String get path => '/character';

  @override
  Character fromJson(Map<String, dynamic> json) => Character.fromJson(json);

  Future<Character> getById(String id) async {
    final result = await query(
      filters: ['id', '=', id],
      fields: detailFields,
      results: 1,
    );
    if (result.results.isEmpty) {
      throw VndbApiException(404, 'Character $id not found');
    }
    return result.results.first;
  }

  Future<QueryResult<Character>> byVn(String vnId, {int results = 50}) {
    return query(
      filters: ['vn', '=', ['id', '=', vnId]],
      fields: listFields,
      results: results,
    );
  }

  Future<QueryResult<Character>> byTrait(
    String traitId, {
    int page = 1,
    int results = 20,
  }) {
    return query(
      filters: ['trait', '=', traitId],
      fields: listFields,
      sort: 'name',
      results: results,
      page: page,
    );
  }

  Future<QueryResult<Character>> search(String term, {int page = 1}) {
    if (term.isEmpty) return list(page: page);
    return query(
      filters: ['search', '=', term],
      fields: listFields,
      sort: 'searchrank',
      page: page,
    );
  }

  /// Browse all characters, sorted by name.
  Future<QueryResult<Character>> list({
    int page = 1,
    int results = 50,
  }) {
    return query(
      fields: listFields,
      sort: 'name',
      results: results,
      page: page,
    );
  }
}
