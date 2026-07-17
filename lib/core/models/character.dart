import 'image_ref.dart';

/// A character entry.
class Character {
  const Character({
    required this.id,
    this.name = '',
    this.original,
    this.aliases = const [],
    this.description,
    this.image,
    this.bloodType,
    this.height,
    this.weight,
    this.bust,
    this.waist,
    this.hips,
    this.cup,
    this.age,
    this.birthday,
    this.sex,
    this.gender,
    this.vns = const [],
    this.traits = const [],
  });

  final String id;
  final String name;
  final String? original;
  final List<String> aliases;
  final String? description;
  final ImageRef? image;
  final String? bloodType;
  final int? height;
  final int? weight;
  final int? bust;
  final int? waist;
  final int? hips;
  final String? cup;
  final int? age;
  final List<int>? birthday;
  final List<String?>? sex;
  final List<String?>? gender;
  final List<CharacterVn> vns;
  final List<CharacterTrait> traits;

  factory Character.fromJson(Map<String, dynamic> json) {
    return Character(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      original: json['original'] as String?,
      aliases: (json['aliases'] as List? ?? [])
          .map((e) => e as String)
          .toList(),
      description: json['description'] as String?,
      image: json['image'] == null
          ? null
          : ImageRef.fromJson(json['image'] as Map<String, dynamic>),
      bloodType: json['blood_type'] as String?,
      height: json['height'] as int?,
      weight: json['weight'] as int?,
      bust: json['bust'] as int?,
      waist: json['waist'] as int?,
      hips: json['hips'] as int?,
      cup: json['cup'] as String?,
      age: json['age'] as int?,
      birthday: (json['birthday'] as List?)?.map((e) => e as int).toList(),
      sex: (json['sex'] as List?)?.map((e) => e as String?).toList(),
      gender: (json['gender'] as List?)?.map((e) => e as String?).toList(),
      vns: (json['vns'] as List? ?? [])
          .map((e) => CharacterVn.fromJson(e as Map<String, dynamic>))
          .toList(),
      traits: (json['traits'] as List? ?? [])
          .map((e) => CharacterTrait.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  String get roleDisplay => vns.isEmpty ? '' : vns.first.role;

  String get roleLabel {
    switch (roleDisplay) {
      case 'main':
        return 'Protagonist';
      case 'primary':
        return 'Main character';
      case 'side':
        return 'Side character';
      case 'appears':
        return 'Appears';
      default:
        return roleDisplay;
    }
  }
}

class CharacterVn {
  const CharacterVn({
    this.spoiler = 0,
    this.role = '',
    this.id = '',
    this.title = '',
    this.release,
  });

  final int spoiler;
  final String role;
  final String id;
  final String title;
  final CharacterVnRelease? release;

  factory CharacterVn.fromJson(Map<String, dynamic> json) => CharacterVn(
        spoiler: json['spoiler'] as int? ?? 0,
        role: json['role'] as String? ?? '',
        id: json['id'] as String? ?? '',
        title: json['title'] as String? ?? '',
        release: json['release'] == null
            ? null
            : CharacterVnRelease.fromJson(
                json['release'] as Map<String, dynamic>),
      );
}

class CharacterVnRelease {
  const CharacterVnRelease({this.id = '', this.title = ''});

  final String id;
  final String title;

  factory CharacterVnRelease.fromJson(Map<String, dynamic> json) =>
      CharacterVnRelease(
        id: json['id'] as String? ?? '',
        title: json['title'] as String? ?? '',
      );
}

class CharacterTrait {
  const CharacterTrait({
    this.id = '',
    this.name = '',
    this.spoiler = 0,
    this.lie = false,
    this.groupId,
    this.groupName,
    this.sexual = false,
  });

  final String id;
  final String name;
  final int spoiler;
  final bool lie;
  final String? groupId;
  final String? groupName;
  final bool sexual;

  factory CharacterTrait.fromJson(Map<String, dynamic> json) =>
      CharacterTrait(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        spoiler: json['spoiler'] as int? ?? 0,
        lie: json['lie'] as bool? ?? false,
        groupId: json['group_id'] as String?,
        groupName: json['group_name'] as String?,
        sexual: json['sexual'] as bool? ?? false,
      );
}
