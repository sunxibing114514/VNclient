/// Information about the authenticated user, returned by `/authinfo`.
class UserInfo {
  const UserInfo({
    this.id = '',
    this.username = '',
    this.permissions = const [],
  });

  final String id;
  final String username;
  final List<String> permissions;

  factory UserInfo.fromJson(Map<String, dynamic> json) => UserInfo(
        id: json['id'] as String? ?? '',
        username: json['username'] as String? ?? '',
        permissions: (json['permissions'] as List? ?? [])
            .map((e) => e as String)
            .toList(),
      );

  bool get canReadList => permissions.contains('listread');
  bool get canWriteList => permissions.contains('listwrite');
  bool get isAuthenticated => id.isNotEmpty;
}

/// A user record returned by `GET /user`.
class UserRecord {
  const UserRecord({
    this.id = '',
    this.username = '',
    this.lengthvotes,
    this.lengthvotesSum,
  });

  final String id;
  final String username;
  final int? lengthvotes;
  final int? lengthvotesSum;

  factory UserRecord.fromJson(Map<String, dynamic> json) => UserRecord(
        id: json['id'] as String? ?? '',
        username: json['username'] as String? ?? '',
        lengthvotes: json['lengthvotes'] as int?,
        lengthvotesSum: json['lengthvotes_sum'] as int?,
      );
}
