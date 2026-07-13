import 'ext_link.dart';
import 'image_ref.dart';

/// A visual novel entry.
class Vn {
  const Vn({
    required this.id,
    this.title = '',
    this.alttitle,
    this.titles = const [],
    this.aliases = const [],
    this.olang,
    this.devstatus = 0,
    this.released,
    this.languages = const [],
    this.platforms = const [],
    this.image,
    this.length,
    this.lengthMinutes,
    this.lengthVotes,
    this.description,
    this.average,
    this.rating,
    this.votecount = 0,
    this.screenshots = const [],
    this.relations = const [],
    this.tags = const [],
    this.developers = const [],
    this.editions = const [],
    this.staff = const [],
    this.va = const [],
    this.extlinks = const [],
  });

  final String id;
  final String title;
  final String? alttitle;
  final List<VnTitle> titles;
  final List<String> aliases;
  final String? olang;
  final int devstatus;
  final String? released;
  final List<String> languages;
  final List<String> platforms;
  final ImageRef? image;
  final int? length;
  final int? lengthMinutes;
  final int? lengthVotes;
  final String? description;
  final num? average;
  final num? rating;
  final int votecount;
  final List<VnScreenshot> screenshots;
  final List<VnRelation> relations;
  final List<VnTag> tags;
  final List<VnDeveloper> developers;
  final List<VnEdition> editions;
  final List<VnStaff> staff;
  final List<VnVa> va;
  final List<ExtLink> extlinks;

  factory Vn.fromJson(Map<String, dynamic> json) {
    return Vn(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      alttitle: json['alttitle'] as String?,
      titles: (json['titles'] as List? ?? [])
          .map((e) => VnTitle.fromJson(e as Map<String, dynamic>))
          .toList(),
      aliases: (json['aliases'] as List? ?? [])
          .map((e) => e as String)
          .toList(),
      olang: json['olang'] as String?,
      devstatus: json['devstatus'] as int? ?? 0,
      released: json['released'] as String?,
      languages: (json['languages'] as List? ?? [])
          .map((e) => e as String)
          .toList(),
      platforms: (json['platforms'] as List? ?? [])
          .map((e) => e as String)
          .toList(),
      image: json['image'] == null
          ? null
          : ImageRef.fromJson(json['image'] as Map<String, dynamic>),
      length: json['length'] as int?,
      lengthMinutes: json['length_minutes'] as int?,
      lengthVotes: json['length_votes'] as int?,
      description: json['description'] as String?,
      average: json['average'] as num?,
      rating: json['rating'] as num?,
      votecount: json['votecount'] as int? ?? 0,
      screenshots: (json['screenshots'] as List? ?? [])
          .map((e) => VnScreenshot.fromJson(e as Map<String, dynamic>))
          .toList(),
      relations: (json['relations'] as List? ?? [])
          .map((e) => VnRelation.fromJson(e as Map<String, dynamic>))
          .toList(),
      tags: (json['tags'] as List? ?? [])
          .map((e) => VnTag.fromJson(e as Map<String, dynamic>))
          .toList(),
      developers: (json['developers'] as List? ?? [])
          .map((e) => VnDeveloper.fromJson(e as Map<String, dynamic>))
          .toList(),
      editions: (json['editions'] as List? ?? [])
          .map((e) => VnEdition.fromJson(e as Map<String, dynamic>))
          .toList(),
      staff: (json['staff'] as List? ?? [])
          .map((e) => VnStaff.fromJson(e as Map<String, dynamic>))
          .toList(),
      va: (json['va'] as List? ?? [])
          .map((e) => VnVa.fromJson(e as Map<String, dynamic>))
          .toList(),
      extlinks: (json['extlinks'] as List? ?? [])
          .map((e) => ExtLink.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  String get devStatusLabel {
    switch (devstatus) {
      case 1:
        return 'In development';
      case 2:
        return 'Cancelled';
      default:
        return 'Finished';
    }
  }

  String get lengthLabel {
    switch (length) {
      case 1:
        return 'Very short';
      case 2:
        return 'Short';
      case 3:
        return 'Medium';
      case 4:
        return 'Long';
      case 5:
        return 'Very long';
      default:
        return 'Unknown';
    }
  }
}

class VnTitle {
  const VnTitle({
    this.lang = '',
    this.title = '',
    this.latin,
    this.official = false,
    this.main = false,
  });

  final String lang;
  final String title;
  final String? latin;
  final bool official;
  final bool main;

  factory VnTitle.fromJson(Map<String, dynamic> json) => VnTitle(
        lang: json['lang'] as String? ?? '',
        title: json['title'] as String? ?? '',
        latin: json['latin'] as String?,
        official: json['official'] as bool? ?? false,
        main: json['main'] as bool? ?? false,
      );
}

class VnTag {
  const VnTag({
    this.id = '',
    this.name = '',
    this.rating = 0,
    this.spoiler = 0,
    this.lie = false,
    this.category,
    this.searchable = true,
    this.applicable = true,
    this.vnCount,
  });

  final String id;
  final String name;
  final num rating;
  final int spoiler;
  final bool lie;
  final String? category;
  final bool searchable;
  final bool applicable;
  final int? vnCount;

  factory VnTag.fromJson(Map<String, dynamic> json) => VnTag(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        rating: (json['rating'] as num?)?.toDouble() ?? 0,
        spoiler: json['spoiler'] as int? ?? 0,
        lie: json['lie'] as bool? ?? false,
        category: json['category'] as String?,
        searchable: json['searchable'] as bool? ?? true,
        applicable: json['applicable'] as bool? ?? true,
        vnCount: json['vn_count'] as int?,
      );
}

class VnRelation {
  const VnRelation({
    this.id = '',
    this.relation = '',
    this.relationOfficial = false,
    this.title = '',
    this.alttitle,
    this.released,
  });

  final String id;
  final String relation;
  final bool relationOfficial;
  final String title;
  final String? alttitle;
  final String? released;

  factory VnRelation.fromJson(Map<String, dynamic> json) => VnRelation(
        id: json['id'] as String? ?? '',
        relation: json['relation'] as String? ?? '',
        relationOfficial: json['relation_official'] as bool? ?? false,
        title: json['title'] as String? ?? '',
        alttitle: json['alttitle'] as String?,
        released: json['released'] as String?,
      );
}

class VnDeveloper {
  const VnDeveloper({
    this.id = '',
    this.name = '',
    this.original,
    this.type,
  });

  final String id;
  final String name;
  final String? original;
  final String? type;

  factory VnDeveloper.fromJson(Map<String, dynamic> json) => VnDeveloper(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        original: json['original'] as String?,
        type: json['type'] as String?,
      );
}

class VnEdition {
  const VnEdition({
    this.eid,
    this.lang,
    this.name = '',
    this.official = false,
  });

  final int? eid;
  final String? lang;
  final String name;
  final bool official;

  factory VnEdition.fromJson(Map<String, dynamic> json) => VnEdition(
        eid: json['eid'] as int?,
        lang: json['lang'] as String?,
        name: json['name'] as String? ?? '',
        official: json['official'] as bool? ?? false,
      );
}

class VnStaff {
  const VnStaff({
    this.id = '',
    this.aid,
    this.name = '',
    this.original,
    this.role = '',
    this.note,
    this.eid,
  });

  final String id;
  final int? aid;
  final String name;
  final String? original;
  final String role;
  final String? note;
  final int? eid;

  factory VnStaff.fromJson(Map<String, dynamic> json) => VnStaff(
        id: json['id'] as String? ?? '',
        aid: json['aid'] as int?,
        name: json['name'] as String? ?? '',
        original: json['original'] as String?,
        role: json['role'] as String? ?? '',
        note: json['note'] as String?,
        eid: json['eid'] as int?,
      );
}

class VnVa {
  const VnVa({
    this.note,
    this.staff,
    this.character,
  });

  final String? note;
  final VnVaStaff? staff;
  final VnVaCharacter? character;

  factory VnVa.fromJson(Map<String, dynamic> json) => VnVa(
        note: json['note'] as String?,
        staff: json['staff'] == null
            ? null
            : VnVaStaff.fromJson(json['staff'] as Map<String, dynamic>),
        character: json['character'] == null
            ? null
            : VnVaCharacter.fromJson(json['character'] as Map<String, dynamic>),
      );
}

class VnVaStaff {
  const VnVaStaff({
    this.id = '',
    this.aid,
    this.name = '',
    this.original,
  });

  final String id;
  final int? aid;
  final String name;
  final String? original;

  factory VnVaStaff.fromJson(Map<String, dynamic> json) => VnVaStaff(
        id: json['id'] as String? ?? '',
        aid: json['aid'] as int?,
        name: json['name'] as String? ?? '',
        original: json['original'] as String?,
      );
}

class VnVaCharacter {
  const VnVaCharacter({
    this.id = '',
    this.name = '',
    this.original,
  });

  final String id;
  final String name;
  final String? original;

  factory VnVaCharacter.fromJson(Map<String, dynamic> json) => VnVaCharacter(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        original: json['original'] as String?,
      );
}

class VnScreenshot {
  const VnScreenshot({this.image, this.release});

  final ImageRef? image;
  final VnScreenshotRelease? release;

  factory VnScreenshot.fromJson(Map<String, dynamic> json) => VnScreenshot(
        image: json['image'] == null
            ? (json['url'] == null
                ? null
                : ImageRef.fromJson(json))
            : ImageRef.fromJson(json['image'] as Map<String, dynamic>),
        release: json['release'] == null
            ? null
            : VnScreenshotRelease.fromJson(
                json['release'] as Map<String, dynamic>),
      );
}

class VnScreenshotRelease {
  const VnScreenshotRelease({this.id = '', this.title = ''});

  final String id;
  final String title;

  factory VnScreenshotRelease.fromJson(Map<String, dynamic> json) =>
      VnScreenshotRelease(
        id: json['id'] as String? ?? '',
        title: json['title'] as String? ?? '',
      );
}
