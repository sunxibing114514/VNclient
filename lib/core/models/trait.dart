/// A trait entry.
class Trait {
  const Trait({
    required this.id,
    this.name = '',
    this.aliases = const [],
    this.description,
    this.searchable = true,
    this.applicable = true,
    this.sexual = false,
    this.groupId,
    this.groupName,
    this.charCount = 0,
  });

  final String id;
  final String name;
  final List<String> aliases;
  final String? description;
  final bool searchable;
  final bool applicable;
  final bool sexual;
  final String? groupId;
  final String? groupName;
  final int charCount;

  factory Trait.fromJson(Map<String, dynamic> json) => Trait(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        aliases: (json['aliases'] as List? ?? [])
            .map((e) => e as String)
            .toList(),
        description: json['description'] as String?,
        searchable: json['searchable'] as bool? ?? true,
        applicable: json['applicable'] as bool? ?? true,
        sexual: json['sexual'] as bool? ?? false,
        groupId: json['group_id'] as String?,
        groupName: json['group_name'] as String?,
        charCount: json['char_count'] as int? ?? 0,
      );
}
