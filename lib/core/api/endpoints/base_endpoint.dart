import '../vndb_client.dart';
import '../../models/query_result.dart';

/// Base class for all database-query endpoints.
///
/// Subclasses provide a [path] (e.g. `/vn`) and a [fromJson] factory that
/// converts a raw result object into a typed model.
abstract class BaseEndpoint<T> {
  BaseEndpoint(this.client);

  final VndbClient client;

  /// The API path, e.g. `/vn`.
  String get path;

  /// Converts a raw JSON object into a model [T].
  T fromJson(Map<String, dynamic> json);

  /// Fallback sort used when "searchrank" is requested but the active
  /// filters do not contain a `search` term. Subclasses may override to
  /// pick a more appropriate default (e.g. "released" for releases).
  String get defaultSort => 'id';

  /// Returns true when [filters] satisfies the VNDB constraint for the
  /// "searchrank" sort: the top-level filter must be a `search`, or an
  /// `and` containing exactly one `search`.
  static bool filtersSupportSearchrank(Object? filters) {
    if (filters == null) return false;
    // Compact filter strings are opaque to us; assume they don't.
    if (filters is! List) return false;
    if (filters.isEmpty) return false;
    final head = filters.first;
    if (head is! String) return false;
    if (head == 'search') return true;
    if (head == 'and') {
      int searchCount = 0;
      for (var i = 1; i < filters.length; i++) {
        final part = filters[i];
        if (part is List &&
            part.isNotEmpty &&
            part.first == 'search') {
          searchCount++;
          if (searchCount > 1) return false;
        }
      }
      return searchCount == 1;
    }
    return false;
  }

  /// Runs a query against [path] and returns a typed [QueryResult].
  Future<QueryResult<T>> query({
    Object? filters,
    String fields = '',
    String? sort,
    bool reverse = false,
    int results = 20,
    int page = 1,
    String? user,
    bool count = false,
    bool compactFilters = false,
    bool normalizedFilters = false,
  }) async {
    // The VNDB API only accepts the "searchrank" sort when the top-level
    // filter is a "search", or an "and" containing at most one "search".
    // Falling back to a safe default avoids a 400 error for browse-only
    // queries that have no search term.
    if (sort == 'searchrank' && !filtersSupportSearchrank(filters)) {
      sort = defaultSort;
    }
    final params = QueryParams(
      filters: filters,
      fields: fields,
      sort: sort,
      reverse: reverse,
      results: results,
      page: page,
      user: user,
      count: count,
      compactFilters: compactFilters,
      normalizedFilters: normalizedFilters,
    );
    final json = await client.post(path, body: params.toJson());
    return QueryResult.fromJson(json, fromJson);
  }
}
