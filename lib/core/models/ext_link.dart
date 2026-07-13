/// A generic external link entry.
class ExtLink {
  const ExtLink({this.url = '', this.label = '', this.name, this.id});

  final String url;
  final String label;
  final String? name;
  final String? id;

  factory ExtLink.fromJson(Map<String, dynamic> json) => ExtLink(
        url: json['url'] as String? ?? '',
        label: json['label'] as String? ?? '',
        name: json['name'] as String?,
        id: json['id']?.toString(),
      );
}
