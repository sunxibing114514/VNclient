import 'vn.dart';

/// A user list (ulist) entry.
class UlistEntry {
  const UlistEntry({
    required this.id,
    this.added,
    this.voted,
    this.lastmod,
    this.vote,
    this.started,
    this.finished,
    this.notes,
    this.labels = const [],
    this.vn,
    this.releases = const [],
  });

  final String id;
  final int? added;
  final int? voted;
  final int? lastmod;
  final int? vote;
  final String? started;
  final String? finished;
  final String? notes;
  final List<UlistLabel> labels;
  final Vn? vn;
  final List<UlistRelease> releases;

  factory UlistEntry.fromJson(Map<String, dynamic> json) {
    return UlistEntry(
      id: json['id'] as String? ?? '',
      added: json['added'] as int?,
      voted: json['voted'] as int?,
      lastmod: json['lastmod'] as int?,
      vote: json['vote'] as int?,
      started: json['started'] as String?,
      finished: json['finished'] as String?,
      notes: json['notes'] as String?,
      labels: (json['labels'] as List? ?? [])
          .map((e) => UlistLabel.fromJson(e as Map<String, dynamic>))
          .toList(),
      vn: json['vn'] == null
          ? null
          : Vn.fromJson(json['vn'] as Map<String, dynamic>),
      releases: (json['releases'] as List? ?? [])
          .map((e) => UlistRelease.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  /// Vote scaled to 0-10 (the API stores 10-100).
  double get voteRating => vote == null ? 0 : vote! / 10.0;
}

class UlistLabel {
  const UlistLabel({this.id = 0, this.label = ''});

  final int id;
  final String label;

  factory UlistLabel.fromJson(Map<String, dynamic> json) => UlistLabel(
        id: json['id'] as int? ?? 0,
        label: json['label'] as String? ?? '',
      );
}

class UlistRelease {
  const UlistRelease({this.id = '', this.listStatus = 0, this.title = ''});

  final String id;
  final int listStatus;
  final String title;

  factory UlistRelease.fromJson(Map<String, dynamic> json) => UlistRelease(
        id: json['id'] as String? ?? '',
        listStatus: json['list_status'] as int? ?? 0,
        title: json['title'] as String? ?? '',
      );

  String get statusLabel {
    switch (listStatus) {
      case 1:
        return 'Pending';
      case 2:
        return 'Obtained';
      case 3:
        return 'On loan';
      case 4:
        return 'Deleted';
      default:
        return 'Unknown';
    }
  }
}

/// A label definition returned by `GET /ulist_labels`.
class UlistLabelDef {
  const UlistLabelDef({
    this.id = 0,
    this.label = '',
    this.private = false,
    this.count = 0,
  });

  final int id;
  final String label;
  final bool private;
  final int count;

  factory UlistLabelDef.fromJson(Map<String, dynamic> json) => UlistLabelDef(
        id: json['id'] as int? ?? 0,
        label: json['label'] as String? ?? '',
        private: json['private'] as bool? ?? false,
        count: json['count'] as int? ?? 0,
      );
}
