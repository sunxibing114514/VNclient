/// A quote entry.
class Quote {
  const Quote({
    required this.id,
    this.quote = '',
    this.score = 0,
    this.vn,
    this.character,
  });

  final String id;
  final String quote;
  final int score;
  final QuoteVn? vn;
  final QuoteCharacter? character;

  factory Quote.fromJson(Map<String, dynamic> json) => Quote(
        id: json['id'] as String? ?? '',
        quote: json['quote'] as String? ?? '',
        score: json['score'] as int? ?? 0,
        vn: json['vn'] == null
            ? null
            : QuoteVn.fromJson(json['vn'] as Map<String, dynamic>),
        character: json['character'] == null
            ? null
            : QuoteCharacter.fromJson(
                json['character'] as Map<String, dynamic>),
      );
}

class QuoteVn {
  const QuoteVn({this.id = '', this.title = ''});

  final String id;
  final String title;

  factory QuoteVn.fromJson(Map<String, dynamic> json) => QuoteVn(
        id: json['id'] as String? ?? '',
        title: json['title'] as String? ?? '',
      );
}

class QuoteCharacter {
  const QuoteCharacter({this.id = '', this.name = ''});

  final String id;
  final String name;

  factory QuoteCharacter.fromJson(Map<String, dynamic> json) =>
      QuoteCharacter(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
      );
}
