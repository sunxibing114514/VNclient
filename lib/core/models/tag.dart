/// A tag entry.
class Tag {
  const Tag({
    required this.id,
    this.name = '',
    this.aliases = const [],
    this.description,
    this.category,
    this.searchable = true,
    this.applicable = true,
    this.vnCount = 0,
  });

  final String id;
  final String name;
  final List<String> aliases;
  final String? description;
  final String? category;
  final bool searchable;
  final bool applicable;
  final int vnCount;

  factory Tag.fromJson(Map<String, dynamic> json) => Tag(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        aliases: (json['aliases'] as List? ?? [])
            .map((e) => e as String)
            .toList(),
        description: json['description'] as String?,
        category: json['category'] as String?,
        searchable: json['searchable'] as bool? ?? true,
        applicable: json['applicable'] as bool? ?? true,
        vnCount: json['vn_count'] as int? ?? 0,
      );

  String get categoryLabel {
    switch (category) {
      case 'cont':
        return 'Content';
      case 'ero':
        return 'Sexual content';
      case 'tech':
        return 'Technical';
      default:
        return category ?? 'Other';
    }
  }
}
