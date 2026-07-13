import '../../models/user_info.dart';
import '../vndb_client.dart';

/// Encapsulates the `GET /user` lookup endpoint.
class UserEndpoint {
  UserEndpoint(this.client);

  final VndbClient client;

  /// Looks up one or more users by id or username.
  ///
  /// Returns a map keyed by the original query strings, with `null` values
  /// when no user matches.
  Future<Map<String, UserRecord?>> lookup(
    List<String> queries, {
    String fields = '',
  }) async {
    if (queries.isEmpty) return {};
    final params = <String, dynamic>{
      for (final q in queries) 'q': q,
      if (fields.isNotEmpty) 'fields': fields,
    };
    final json = await client.get('/user', queryParameters: params);
    return json.map(
      (key, value) => MapEntry(
        key,
        value == null ? null : UserRecord.fromJson(value as Map<String, dynamic>),
      ),
    );
  }

  /// Convenience: look up a single user.
  Future<UserRecord?> get(String idOrUsername, {String fields = ''}) async {
    final result = await lookup([idOrUsername], fields: fields);
    return result[idOrUsername];
  }
}
