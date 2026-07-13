import '../api/vndb_client.dart';

/// Generic wrapper for a Kana POST query response.
class QueryResult<T> {
  QueryResult({
    required this.results,
    required this.more,
    this.count,
    this.compactFilters,
    this.normalizedFilters,
  });

  final List<T> results;
  final bool more;
  final int? count;
  final String? compactFilters;
  final List<dynamic>? normalizedFilters;

  factory QueryResult.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    final list = (json['results'] as List? ?? [])
        .map((e) => fromJson(e as Map<String, dynamic>))
        .toList();
    return QueryResult<T>(
      results: list,
      more: json['more'] as bool? ?? false,
      count: json['count'] as int?,
      compactFilters: json['compact_filters'] as String?,
      normalizedFilters: json['normalized_filters'] as List?,
    );
  }
}

/// Parameters for a Kana POST query.
class QueryParams {
  const QueryParams({
    this.filters,
    this.fields = '',
    this.sort,
    this.reverse = false,
    this.results = 20,
    this.page = 1,
    this.user,
    this.count = false,
    this.compactFilters = false,
    this.normalizedFilters = false,
  });

  /// Either a JSON filter array/tree or a compact filter string.
  final Object? filters;
  final String fields;
  final String? sort;
  final bool reverse;
  final int results;
  final int page;
  final String? user;
  final bool count;
  final bool compactFilters;
  final bool normalizedFilters;

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      if (filters != null) 'filters': filters,
      if (fields.isNotEmpty) 'fields': fields,
      if (sort != null) 'sort': sort,
      'reverse': reverse,
      'results': results,
      'page': page,
      if (user != null) 'user': user,
      'count': count,
      'compact_filters': compactFilters,
      'normalized_filters': normalizedFilters,
    };
    return map;
  }
}

/// Re-export of the API exception for convenience.
typedef ApiException = VndbApiException;
