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
