import 'dart:math' as math;

import '../../models/query_result.dart';
import '../../models/staff.dart';
import '../../models/vn.dart';
import '../vndb_client.dart';
import 'base_endpoint.dart';

/// Encapsulates queries against the `/vn` endpoint.
class VnEndpoint extends BaseEndpoint<Vn> {
  VnEndpoint(super.client);

  /// Fields used for list/search views.
  static const String listFields =
      'title, alttitle, released, image{id,url,thumbnail,thumbnail_dims,sexual,violence},'
      'languages, platforms, devstatus, rating, votecount, length, length_minutes';

  /// Full set of fields used on the VN detail page.
  static const String detailFields =
      'title, alttitle, titles{lang,title,latin,official,main}, aliases, olang, devstatus,'
      'released, languages, platforms, image{id,url,dims,thumbnail,thumbnail_dims,sexual,violence,votecount},'
      'length, length_minutes, length_votes, description, average, rating, votecount,'
      'screenshots{id,url,thumbnail,thumbnail_dims,dims,sexual,violence},'
      'relations{id,relation,relation_official,title,alttitle,released},'
      'tags{id,name,rating,spoiler,lie,category},'
      'developers{id,name,original,type}, editions{eid,lang,name,official},'
      'staff{id,aid,name,original,role,note,eid},'
      'va{note,staff{id,aid,name,original},character{id,name,original}},'
      'extlinks{url,label,name,id}';

  @override
  String get path => '/vn';

  @override
  Vn fromJson(Map<String, dynamic> json) => Vn.fromJson(json);

  /// Fetches a single VN by its vndbid (e.g. `v17`).
  Future<Vn> getById(String id) async {
    final result = await query(
      filters: ['id', '=', id],
      fields: detailFields,
      results: 1,
    );
    if (result.results.isEmpty) {
      throw VndbApiException(404, 'Visual novel $id not found');
    }
    return result.results.first;
  }

  /// Free-text search across VN titles, aliases and release titles.
  Future<QueryResult<Vn>> search(
    String term, {
    int page = 1,
    int results = 20,
    String sort = 'searchrank',
  }) {
    return query(
      filters: term.isEmpty ? [] : ['search', '=', term],
      fields: listFields,
      sort: sort,
      results: results,
      page: page,
    );
  }

  /// Returns a random VN using the documented id-gap algorithm.
  ///
  /// First the highest id is fetched (cached implicitly by the caller), then
  /// a random id is chosen and the nearest increasing entry is returned.
  Future<Vn> random() async {
    // 1. Determine the highest VN id.
    final maxResult = await query(
      fields: 'id',
      sort: 'id',
      reverse: true,
      results: 1,
    );
    if (maxResult.results.isEmpty) {
      throw VndbApiException(404, 'No visual novels found');
    }
    final maxId = maxResult.results.first.id;
    final maxNum = int.tryParse(maxId.replaceAll(RegExp(r'^v'), '')) ?? 1;
    final randomNum = _random.nextInt(maxNum) + 1;
    final candidate = 'v$randomNum';

    // 2. Fetch the nearest VN with id >= candidate.
    final result = await query(
      filters: ['id', '>=', candidate],
      fields: listFields,
      sort: 'id',
      results: 1,
    );
    if (result.results.isNotEmpty) return result.results.first;

    // 3. Fallback: nearest VN with id <= candidate (handles tail edge case).
    final fallback = await query(
      filters: ['id', '<=', candidate],
      fields: listFields,
      sort: 'id',
      reverse: true,
      results: 1,
    );
    if (fallback.results.isNotEmpty) return fallback.results.first;
    throw VndbApiException(404, 'Random visual novel not available');
  }

  /// Returns VNs tagged with the given tag id.
  Future<QueryResult<Vn>> byTag(
    String tagId,
    {
    int page = 1,
    int results = 20,
    String sort = 'rating',
  }) {
    return query(
      filters: ['tag', '=', tagId],
      fields: listFields,
      sort: sort,
      reverse: true,
      results: results,
      page: page,
    );
  }

  /// Returns VNs matching ANY of the given tag ids, sorted by rating.
  /// Used for the "猜你喜欢" recommendation feature.
  Future<QueryResult<Vn>> byTags(
    List<String> tagIds, {
    int results = 20,
    int page = 1,
  }) {
    if (tagIds.isEmpty) {
      return query(
        filters: [],
        fields: listFields,
        sort: 'rating',
        reverse: true,
        results: results,
        page: page,
      );
    }
    final orFilters = ['or', ...tagIds.map((id) => ['tag', '=', id])];
    return query(
      filters: orFilters,
      fields: listFields,
      sort: 'rating',
      reverse: true,
      results: results,
      page: page,
    );
  }

  /// Recently added VNs (highest id first) — represents database changes.
  Future<QueryResult<Vn>> getRecent({int limit = 10}) {
    return query(
      fields: listFields,
      sort: 'id',
      reverse: true,
      results: limit,
      page: 1,
    );
  }

  /// Returns VNs credited to a given staff member (identified by staff id
  /// `sid`, e.g. `s81`), with the staff's role extracted from each VN's
  /// `staff` array.
  ///
  /// The `/vn` endpoint's `staff` filter requires a nested filter array of the
  /// form `['staff', '=', ['id', '=', sid]]` — a plain value such as an
  /// integer aid is rejected with "Invalid query".
  Future<List<StaffVn>> byStaff(String staffId) async {
    const fields = 'title, staff{id,aid,role,note}';
    final result = await query(
      filters: ['staff', '=', ['id', '=', staffId]],
      fields: fields,
      sort: 'rating',
      reverse: true,
      results: 100,
      page: 1,
    );
    return result.results.map((vn) {
      String role = '';
      String? note;
      for (final s in vn.staff) {
        if (s.id == staffId) {
          role = s.role;
          note = s.note;
          break;
        }
      }
      return StaffVn(id: vn.id, role: role, title: vn.title, note: note);
    }).toList();
  }

  static final _random = math.Random();
}
