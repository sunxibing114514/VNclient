import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/endpoints/vn_endpoint.dart';
import '../models/character.dart';
import '../models/list_entry.dart';
import '../models/query_result.dart';
import '../models/release.dart';
import '../models/staff.dart';
import '../models/vn.dart';
import 'auth_provider.dart';
import 'endpoints_provider.dart';

/// Fetches a single VN by id.
final vnDetailProvider =
    FutureProvider.autoDispose.family<Vn, String>((ref, id) {
  return ref.watch(vnEndpointProvider).getById(id);
});

/// Releases linked to a VN.
final releasesByVnProvider =
    FutureProvider.autoDispose.family<List<Release>, String>((ref, vnId) async {
  final result = await ref.watch(releaseEndpointProvider).byVn(vnId);
  return result.results;
});

/// Characters linked to a VN.
final charactersByVnProvider =
    FutureProvider.autoDispose.family<List<Character>, String>((ref, vnId) async {
  final result = await ref.watch(characterEndpointProvider).byVn(vnId);
  return result.results;
});

/// VNs credited to a staff member (used on the staff detail page).
/// Keyed by the staff id (sid string, e.g. `s81`).
final vnsByStaffProvider =
    FutureProvider.autoDispose.family<List<StaffVn>, String>((ref, staffId) {
  return ref.watch(vnEndpointProvider).byStaff(staffId);
});

/// The labels available to the current user.
final userLabelsProvider =
    FutureProvider.autoDispose<List<UlistLabelDef>>((ref) async {
  final auth = ref.watch(authNotifierProvider);
  final userId = auth.user?.id;
  if (userId == null) return [];
  return ref.watch(listEndpointProvider).getLabels(userId);
});

/// Fetches the current user's list with an optional label filter.
final userListProvider = FutureProvider.autoDispose
    .family<QueryResult<UlistEntry>, UserListQuery>((ref, query) {
  final auth = ref.watch(authNotifierProvider);
  final userId = auth.user?.id;
  if (userId == null) {
    throw StateError('Not authenticated');
  }
  return ref.watch(listEndpointProvider).getList(
        userId,
        labelId: query.labelId,
        sort: query.sort,
        reverse: query.reverse,
        page: query.page,
        results: query.results,
      );
});

/// Parameters for [userListProvider].
class UserListQuery {
  const UserListQuery({
    this.labelId,
    this.sort = 'vote',
    this.reverse = true,
    this.page = 1,
    this.results = 50,
  });

  final int? labelId;
  final String sort;
  final bool reverse;
  final int page;
  final int results;

  @override
  bool operator ==(Object other) =>
      other is UserListQuery &&
      other.labelId == labelId &&
      other.sort == sort &&
      other.reverse == reverse &&
      other.page == page &&
      other.results == results;

  @override
  int get hashCode => Object.hash(labelId, sort, reverse, page, results);
}

/// Generic paginated VN search provider for the search page.
final vnSearchProvider = FutureProvider.autoDispose
    .family<QueryResult<Vn>, VnSearchQuery>((ref, query) {
  return ref.watch(vnEndpointProvider).query(
        filters: query.filters,
        fields: VnEndpoint.listFields,
        sort: query.sort,
        reverse: query.reverse,
        results: query.results,
        page: query.page,
        compactFilters: query.compactFilters,
        normalizedFilters: query.normalizedFilters,
      );
});

class VnSearchQuery {
  const VnSearchQuery({
    this.filters,
    this.sort = 'searchrank',
    this.reverse = false,
    this.results = 20,
    this.page = 1,
    this.compactFilters = false,
    this.normalizedFilters = false,
  });

  final Object? filters;
  final String sort;
  final bool reverse;
  final int results;
  final int page;
  final bool compactFilters;
  final bool normalizedFilters;

  @override
  bool operator ==(Object other) =>
      other is VnSearchQuery &&
      other.sort == sort &&
      other.reverse == reverse &&
      other.results == results &&
      other.page == page &&
      other.compactFilters == compactFilters &&
      other.normalizedFilters == normalizedFilters &&
      _filtersEqual(other.filters);

  bool _filtersEqual(Object? other) {
    if (filters == null && other == null) return true;
    return filters == other;
  }

  @override
  int get hashCode => Object.hash(
        filters,
        sort,
        reverse,
        results,
        page,
        compactFilters,
        normalizedFilters,
      );
}
