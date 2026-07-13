import '../../models/list_entry.dart';
import '../../models/query_result.dart';
import '../../models/vn.dart';
import 'base_endpoint.dart';

/// Encapsulates the `/ulist` query endpoint plus the `PATCH`/`DELETE` mutations
/// and the `GET /ulist_labels` label list.
class ListEndpoint extends BaseEndpoint<UlistEntry> {
  ListEndpoint(super.client);

  static const String listFields =
      'id, added, voted, lastmod, vote, started, finished, notes,'
      'labels{id,label},'
      'vn{title, alttitle, released, image{id,url,thumbnail,thumbnail_dims},'
      'languages, platforms, devstatus, rating, votecount},'
      'releases{id,list_status,title}';

  @override
  String get path => '/ulist';

  @override
  UlistEntry fromJson(Map<String, dynamic> json) => UlistEntry.fromJson(json);

  /// Fetches a user's list.
  ///
  /// [labelId] optionally restricts results to a single label (e.g. `7` for
  /// voted entries, `5` for the wishlist).
  Future<QueryResult<UlistEntry>> getList(
    String userId, {
    int? labelId,
    String sort = 'vote',
    bool reverse = true,
    int page = 1,
    int results = 50,
    Object? extraFilters,
  }) {
    Object filters;
    if (labelId != null) {
      filters = extraFilters == null
          ? ['label', '=', labelId]
          : ['and', ['label', '=', labelId], extraFilters];
    } else {
      filters = extraFilters ?? [];
    }
    return query(
      filters: filters,
      fields: listFields,
      sort: sort,
      reverse: reverse,
      results: results,
      page: page,
      user: userId,
    );
  }

  /// Fetches the user's list labels.
  Future<List<UlistLabelDef>> getLabels(String? userId) async {
    final params = <String, dynamic>{
      if (userId != null) 'user': userId,
      'fields': 'count',
    };
    final json = await client.get('/ulist_labels', queryParameters: params);
    final list = (json['labels'] as List? ?? [])
        .map((e) => UlistLabelDef.fromJson(e as Map<String, dynamic>))
        .toList();
    return list;
  }

  /// Creates or updates a list entry for [vnId].
  Future<void> patchList(
    String vnId, {
    int? vote,
    String? notes,
    String? started,
    String? finished,
    List<int>? labels,
    List<int>? labelsSet,
    List<int>? labelsUnset,
  }) async {
    final body = <String, dynamic>{};
    if (vote != null) body['vote'] = vote;
    if (notes != null) body['notes'] = notes;
    if (started != null) body['started'] = started;
    if (finished != null) body['finished'] = finished;
    if (labels != null) body['labels'] = labels;
    if (labelsSet != null) body['labels_set'] = labelsSet;
    if (labelsUnset != null) body['labels_unset'] = labelsUnset;
    await client.patch('/ulist/$vnId', body: body);
  }

  /// Removes [vnId] from the user's list.
  Future<void> deleteList(String vnId) async {
    await client.delete('/ulist/$vnId');
  }

  /// Updates a release's status in the user's release list.
  Future<void> patchRelease(String releaseId, {int status = 0}) async {
    await client.patch('/rlist/$releaseId', body: {'status': status});
  }

  /// Removes a release from the user's release list.
  Future<void> deleteRelease(String releaseId) async {
    await client.delete('/rlist/$releaseId');
  }
}

/// Re-export so callers can construct the endpoint with the shared client.
typedef VnListEntry = UlistEntry;

/// Stand-alone helper exposing the type to callers that import [Vn] too.
typedef VnListResult = QueryResult<Vn>;
