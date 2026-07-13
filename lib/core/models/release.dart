import 'ext_link.dart';
import 'image_ref.dart';

/// A release entry.
class Release {
  const Release({
    required this.id,
    this.title = '',
    this.alttitle,
    this.languages = const [],
    this.platforms = const [],
    this.media = const [],
    this.vns = const [],
    this.producers = const [],
    this.images = const [],
    this.released,
    this.minage,
    this.patch = false,
    this.freeware = false,
    this.uncensored,
    this.official = true,
    this.hasEro = false,
    this.resolution,
    this.engine,
    this.voiced,
    this.notes,
    this.gtin,
    this.catalog,
    this.extlinks = const [],
  });

  final String id;
  final String title;
  final String? alttitle;
  final List<ReleaseLanguage> languages;
  final List<String> platforms;
  final List<ReleaseMedia> media;
  final List<ReleaseVn> vns;
  final List<ReleaseProducer> producers;
  final List<ReleaseImage> images;
  final String? released;
  final int? minage;
  final bool patch;
  final bool freeware;
  final bool? uncensored;
  final bool official;
  final bool hasEro;
  final Object? resolution;
  final String? engine;
  final int? voiced;
  final String? notes;
  final String? gtin;
  final String? catalog;
  final List<ExtLink> extlinks;

  factory Release.fromJson(Map<String, dynamic> json) {
    return Release(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      alttitle: json['alttitle'] as String?,
      languages: (json['languages'] as List? ?? [])
          .map((e) => ReleaseLanguage.fromJson(e as Map<String, dynamic>))
          .toList(),
      platforms: (json['platforms'] as List? ?? [])
          .map((e) => e as String)
          .toList(),
      media: (json['media'] as List? ?? [])
          .map((e) => ReleaseMedia.fromJson(e as Map<String, dynamic>))
          .toList(),
      vns: (json['vns'] as List? ?? [])
          .map((e) => ReleaseVn.fromJson(e as Map<String, dynamic>))
          .toList(),
      producers: (json['producers'] as List? ?? [])
          .map((e) => ReleaseProducer.fromJson(e as Map<String, dynamic>))
          .toList(),
      images: (json['images'] as List? ?? [])
          .map((e) => ReleaseImage.fromJson(e as Map<String, dynamic>))
          .toList(),
      released: json['released'] as String?,
      minage: json['minage'] as int?,
      patch: json['patch'] as bool? ?? false,
      freeware: json['freeware'] as bool? ?? false,
      uncensored: json['uncensored'] as bool?,
      official: json['official'] as bool? ?? true,
      hasEro: json['has_ero'] as bool? ?? false,
      resolution: json['resolution'],
      engine: json['engine'] as String?,
      voiced: json['voiced'] as int?,
      notes: json['notes'] as String?,
      gtin: json['gtin'] as String?,
      catalog: json['catalog'] as String?,
      extlinks: (json['extlinks'] as List? ?? [])
          .map((e) => ExtLink.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  String get voicedLabel {
    switch (voiced) {
      case 1:
        return 'Not voiced';
      case 2:
        return 'Only ero scenes voiced';
      case 3:
        return 'Partially voiced';
      case 4:
        return 'Fully voiced';
      default:
        return 'Unknown';
    }
  }
}

class ReleaseLanguage {
  const ReleaseLanguage({
    this.lang = '',
    this.title,
    this.latin,
    this.mtl = false,
    this.main = false,
  });

  final String lang;
  final String? title;
  final String? latin;
  final bool mtl;
  final bool main;

  factory ReleaseLanguage.fromJson(Map<String, dynamic> json) =>
      ReleaseLanguage(
        lang: json['lang'] as String? ?? '',
        title: json['title'] as String?,
        latin: json['latin'] as String?,
        mtl: json['mtl'] as bool? ?? false,
        main: json['main'] as bool? ?? false,
      );
}

class ReleaseMedia {
  const ReleaseMedia({this.medium = '', this.qty = 0});

  final String medium;
  final int qty;

  factory ReleaseMedia.fromJson(Map<String, dynamic> json) => ReleaseMedia(
        medium: json['medium'] as String? ?? '',
        qty: json['qty'] as int? ?? 0,
      );
}

class ReleaseVn {
  const ReleaseVn({this.rtype = '', this.id = '', this.title = ''});

  final String rtype;
  final String id;
  final String title;

  factory ReleaseVn.fromJson(Map<String, dynamic> json) => ReleaseVn(
        rtype: json['rtype'] as String? ?? '',
        id: json['id'] as String? ?? '',
        title: json['title'] as String? ?? '',
      );
}

class ReleaseProducer {
  const ReleaseProducer({
    this.id = '',
    this.name = '',
    this.original,
    this.developer = false,
    this.publisher = false,
    this.type,
  });

  final String id;
  final String name;
  final String? original;
  final bool developer;
  final bool publisher;
  final String? type;

  factory ReleaseProducer.fromJson(Map<String, dynamic> json) =>
      ReleaseProducer(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        original: json['original'] as String?,
        developer: json['developer'] as bool? ?? false,
        publisher: json['publisher'] as bool? ?? false,
        type: json['type'] as String?,
      );
}

class ReleaseImage {
  const ReleaseImage({this.image, this.type, this.photo = false});

  final ImageRef? image;
  final String? type;
  final bool photo;

  factory ReleaseImage.fromJson(Map<String, dynamic> json) => ReleaseImage(
        image: json['url'] == null
            ? null
            : ImageRef.fromJson(
                json.containsKey('image')
                    ? json['image'] as Map<String, dynamic>
                    : json,
              ),
        type: json['type'] as String?,
        photo: json['photo'] as bool? ?? false,
      );
}
