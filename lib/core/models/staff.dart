/// A staff (person) entry.
class Staff {
  const Staff({
    required this.id,
    this.aid,
    this.ismain = false,
    this.name = '',
    this.original,
    this.lang,
    this.gender,
    this.description,
    this.extlinks = const [],
    this.aliases = const [],
    this.vns = const [],
  });

  final String id;
  final int? aid;
  final bool ismain;
  final String name;
  final String? original;
  final String? lang;
  final String? gender;
  final String? description;
  final List<StaffExtLink> extlinks;
  final List<StaffAlias> aliases;
  final List<StaffVn> vns;

  factory Staff.fromJson(Map<String, dynamic> json) {
    return Staff(
      id: json['id'] as String? ?? '',
      aid: json['aid'] as int?,
      ismain: json['ismain'] as bool? ?? false,
      name: json['name'] as String? ?? '',
      original: json['original'] as String?,
      lang: json['lang'] as String?,
      gender: json['gender'] as String?,
      description: json['description'] as String?,
      extlinks: (json['extlinks'] as List? ?? [])
          .map((e) => StaffExtLink.fromJson(e as Map<String, dynamic>))
          .toList(),
      aliases: (json['aliases'] as List? ?? [])
          .map((e) => StaffAlias.fromJson(e as Map<String, dynamic>))
          .toList(),
      vns: (json['vns'] as List? ?? [])
          .map((e) => StaffVn.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  String get genderLabel {
    switch (gender) {
      case 'm':
        return 'Male';
      case 'f':
        return 'Female';
      default:
        return 'Unknown';
    }
  }
}

/// A VN credited to a staff member.
class StaffVn {
  const StaffVn({this.id = '', this.role = '', this.title = '', this.note});

  final String id;
  final String role;
  final String title;
  final String? note;

  factory StaffVn.fromJson(Map<String, dynamic> json) => StaffVn(
        id: json['id'] as String? ?? '',
        role: json['role'] as String? ?? '',
        title: json['title'] as String? ?? '',
        note: json['note'] as String?,
      );
}

class StaffAlias {
  const StaffAlias({this.aid, this.name = '', this.latin, this.ismain = false});

  final int? aid;
  final String name;
  final String? latin;
  final bool ismain;

  factory StaffAlias.fromJson(Map<String, dynamic> json) => StaffAlias(
        aid: json['aid'] as int?,
        name: json['name'] as String? ?? '',
        latin: json['latin'] as String?,
        ismain: json['ismain'] as bool? ?? false,
      );
}

class StaffExtLink {
  const StaffExtLink({this.url = '', this.label = ''});

  final String url;
  final String label;

  factory StaffExtLink.fromJson(Map<String, dynamic> json) => StaffExtLink(
        url: json['url'] as String? ?? '',
        label: json['label'] as String? ?? '',
      );
}
