import '../../models/query_result.dart';
import '../../models/release.dart';
import '../vndb_client.dart';
import 'base_endpoint.dart';

/// Encapsulates queries against the `/release` endpoint.
class ReleaseEndpoint extends BaseEndpoint<Release> {
  ReleaseEndpoint(super.client);

  static const String listFields =
      'title, alttitle, released, platforms, languages{lang,mtl,main},'
      'minage, official, freeware, patch, images{id,url,thumbnail,thumbnail_dims},'
      'extlinks{url,label,name,id}';

  static const String detailFields =
      'title, alttitle, languages{lang,title,latin,mtl,main}, platforms,'
      'media{medium,qty}, vns{rtype,id,title}, producers{id,name,original,developer,publisher,type},'
      'images{id,url,thumbnail,thumbnail_dims,dims,type}, released, minage, patch, freeware,'
      'uncensored, official, has_ero, resolution, engine, voiced, notes, gtin, catalog,'
      'extlinks{url,label,name,id}';

  @override
  String get path => '/release';

  @override
  Release fromJson(Map<String, dynamic> json) => Release.fromJson(json);

  @override
  String get defaultSort => 'released';

  /// Fetches a single release by id.
  Future<Release> getById(String id) async {
    final result = await query(
      filters: ['id', '=', id],
      fields: detailFields,
      results: 1,
    );
    if (result.results.isEmpty) {
      throw VndbApiException(404, 'Release $id not found');
    }
    return result.results.first;
  }

  /// Releases linked to the given VN, sorted oldest-first.
  Future<QueryResult<Release>> byVn(
    String vnId, {
    int page = 1,
    int results = 100,
  }) {
    return query(
      filters: ['vn', '=', ['id', '=', vnId]],
      fields: detailFields,
      sort: 'released',
      results: results,
      page: page,
    );
  }

  /// Releases with a future (or TBA) release date — the "Upcoming" list.
  Future<QueryResult<Release>> getUpcoming({int limit = 10}) {
    return query(
      filters: ['or', ['released', '>', 'today'], ['released', '=', 'TBA']],
      fields: listFields,
      sort: 'released',
      results: limit,
      page: 1,
    );
  }

  /// Releases with a past release date, sorted newest-first.
  Future<QueryResult<Release>> getJustReleased({int limit = 10}) {
    return query(
      filters: ['released', '<', 'today'],
      fields: listFields,
      sort: 'released',
      reverse: true,
      results: limit,
      page: 1,
    );
  }

  /// Free-text search.
  Future<QueryResult<Release>> search(
    String term, {
    int page = 1,
    int results = 20,
  }) {
    if (term.isEmpty) return list(page: page, results: results);
    return query(
      filters: ['search', '=', term],
      fields: listFields,
      sort: 'searchrank',
      results: results,
      page: page,
    );
  }

  /// Browse all releases, newest first.
  Future<QueryResult<Release>> list({
    int page = 1,
    int results = 20,
  }) {
    return query(
      filters: ['released', '<', 'today'],
      fields: listFields,
      sort: 'released',
      reverse: true,
      results: results,
      page: page,
    );
  }
}
