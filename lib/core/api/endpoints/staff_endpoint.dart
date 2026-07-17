import '../../models/query_result.dart';
import '../../models/staff.dart';
import '../vndb_client.dart';
import 'base_endpoint.dart';

/// Encapsulates queries against the `/staff` endpoint.
class StaffEndpoint extends BaseEndpoint<Staff> {
  StaffEndpoint(super.client);

  static const String listFields = 'aid, ismain, name, original, lang, gender';

  static const String detailFields =
      'aid, ismain, name, original, lang, gender, description,'
      'aliases{aid,name,latin,ismain}, extlinks{url,label}';

  @override
  String get path => '/staff';

  @override
  Staff fromJson(Map<String, dynamic> json) => Staff.fromJson(json);

  @override
  String get defaultSort => 'name';

  Future<Staff> getById(String id) async {
    final result = await query(
      filters: ['and', ['ismain', '=', 1], ['id', '=', id]],
      fields: detailFields,
      results: 1,
    );
    if (result.results.isEmpty) {
      throw VndbApiException(404, 'Staff $id not found');
    }
    return result.results.first;
  }

  Future<QueryResult<Staff>> search(String term, {int page = 1}) {
    if (term.isEmpty) return list(page: page);
    return query(
      filters: ['and', ['ismain', '=', 1], ['search', '=', term]],
      fields: listFields,
      sort: 'searchrank',
      page: page,
    );
  }

  /// Browse all main staff entries, sorted by name.
  Future<QueryResult<Staff>> list({int page = 1, int results = 50}) {
    return query(
      filters: ['ismain', '=', 1],
      fields: listFields,
      sort: 'name',
      results: results,
      page: page,
    );
  }
}
