import 'ext_link.dart';

/// A producer (company / individual / group) entry.
class Producer {
  const Producer({
    required this.id,
    this.name = '',
    this.original,
    this.aliases = const [],
    this.lang,
    this.type,
    this.description,
    this.extlinks = const [],
  });

  final String id;
  final String name;
  final String? original;
  final List<String> aliases;
  final String? lang;
  final String? type;
  final String? description;
  final List<ExtLink> extlinks;

  factory Producer.fromJson(Map<String, dynamic> json) {
    return Producer(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      original: json['original'] as String?,
      aliases: (json['aliases'] as List? ?? [])
          .map((e) => e as String)
          .toList(),
      lang: json['lang'] as String?,
      type: json['type'] as String?,
      description: json['description'] as String?,
      extlinks: (json['extlinks'] as List? ?? [])
          .map((e) => ExtLink.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  String get typeLabel {
    switch (type) {
      case 'co':
        return 'Company';
      case 'in':
        return 'Individual';
      case 'ng':
        return 'Amateur group';
      default:
        return type ?? 'Unknown';
    }
  }
}
