/// Overall database statistics returned by `GET /stats`.
class Stats {
  const Stats({
    this.chars = 0,
    this.producers = 0,
    this.releases = 0,
    this.staff = 0,
    this.tags = 0,
    this.traits = 0,
    this.vn = 0,
  });

  final int chars;
  final int producers;
  final int releases;
  final int staff;
  final int tags;
  final int traits;
  final int vn;

  factory Stats.fromJson(Map<String, dynamic> json) => Stats(
        chars: json['chars'] as int? ?? 0,
        producers: json['producers'] as int? ?? 0,
        releases: json['releases'] as int? ?? 0,
        staff: json['staff'] as int? ?? 0,
        tags: json['tags'] as int? ?? 0,
        traits: json['traits'] as int? ?? 0,
        vn: json['vn'] as int? ?? 0,
      );
}
