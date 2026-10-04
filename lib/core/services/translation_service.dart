import 'package:dio/dio.dart';

/// The result of a VN description translation attempt.
class DescriptionTranslation {
  const DescriptionTranslation({
    required this.text,
    required this.humanTranslated,
  });

  /// The translated (Chinese) description text.
  final String text;

  /// True when the text came from the community human-translation mirror
  /// (vndbtran); false when it was machine-translated via MyMemory.
  final bool humanTranslated;

  String get sourceLabel =>
      humanTranslated ? '社区翻译' : 'MyMemory API 机器翻译';
}

/// A client for the community human-translation mirror of VN descriptions:
/// `https://vndbtran.hjymoon.bbroot.com/000001.json`.
///
/// The mirror stores 500 VNs per JSON shard. Each shard is a JSON array of
/// entries shaped like `{"v": "<vn id>", "translate": "<Chinese description>"}`.
/// Shard files are zero-padded to 6 digits; a VN with numeric id `n` lives in
/// shard `((n - 1) ~/ 500) + 1`. Missing shards (HTTP 404) and misses are
/// cached so repeated lookups are cheap.
class VndbtranService {
  VndbtranService()
      : _dio = Dio(
          BaseOptions(
            baseUrl: 'https://vndbtran.hjymoon.bbroot.com',
            connectTimeout: const Duration(seconds: 15),
            receiveTimeout: const Duration(seconds: 30),
            headers: {'Accept': 'application/json'},
          ),
        );

  final Dio _dio;

  /// Number of VNs stored per JSON shard.
  static const int perShard = 500;

  /// shard index -> parsed entries (keyed by numeric VN id), or null when the
  /// shard is known to be unavailable (404 / network error).
  final Map<int, Map<String, String>?> _shardCache = {};

  /// vn id (e.g. "v17") -> cached hit translation.
  final Map<String, String> _hitCache = {};

  int? _vnNumber(String vnId) {
    final trimmed = vnId.trim();
    if (!trimmed.startsWith('v')) return null;
    return int.tryParse(trimmed.substring(1));
  }

  /// Looks up the community human translation for [vnId].
  /// Returns null when the VN is not present in the mirror.
  Future<String?> lookup(String vnId) async {
    final n = _vnNumber(vnId);
    if (n == null) return null;

    final cachedHit = _hitCache[vnId];
    if (cachedHit != null) return cachedHit;

    final shard = ((n - 1) ~/ perShard) + 1;
    final shardFile =
        shard.toString().padLeft(6, '0');

    Map<String, String>? shardMap;
    if (_shardCache.containsKey(shard)) {
      shardMap = _shardCache[shard];
    } else {
      shardMap = await _downloadShard(shardFile);
      _shardCache[shard] = shardMap;
    }

    final hit = shardMap?[n.toString()];
    if (hit != null && hit.trim().isNotEmpty) {
      _hitCache[vnId] = hit;
      return hit;
    }
    return null;
  }

  Future<Map<String, String>?> _downloadShard(String shardFile) async {
    try {
      final response = await _dio.get<List<dynamic>>('/$shardFile.json');
      final list = response.data;
      if (list == null) return null;
      final map = <String, String>{};
      for (final entry in list) {
        if (entry is Map<String, dynamic>) {
          final v = entry['v']?.toString();
          final t = entry['translate']?.toString();
          if (v == null || t == null) continue;
          // Normalize "v17" / "17" forms to the bare number.
          final key = v.startsWith('v') ? v.substring(1) : v;
          map[key] = t;
        }
      }
      return map;
    } on DioException {
      // 404 (shard not published yet) or transient network error.
      return null;
    } catch (_) {
      return null;
    }
  }
}

/// A simple translation service using the MyMemory API.
///
/// API spec: https://mymemory.translated.net/doc/spec.php
/// Endpoint: GET https://api.mymemory.translated.net/get?q=TEXT&langpair=src|tgt
///
/// The free tier limits queries to 500 bytes per request, so long texts are
/// split into chunks and translated individually, then rejoined.
class TranslationService {
  TranslationService()
      : _dio = Dio(
          BaseOptions(
            baseUrl: 'https://api.mymemory.translated.net',
            connectTimeout: const Duration(seconds: 15),
            receiveTimeout: const Duration(seconds: 30),
          ),
        ),
        _vndbtran = VndbtranService();

  final Dio _dio;
  final VndbtranService _vndbtran;

  /// Maximum text length per request (bytes). The MyMemory free tier allows
  /// 500 bytes; we use 400 to leave room for URL-encoding overhead.
  static const int _maxChunkLength = 400;

  /// Translates a VN description to Chinese.
  ///
  /// First consults the community human-translation mirror (vndbtran, 500
  /// VNs per JSON shard); when the VN isn't found there, falls back to
  /// machine translation via MyMemory. The human-translation mirror holds
  /// Chinese text, so it is only consulted when [useHumanTranslation] is
  /// true — i.e. when the app language is set to Chinese.
  Future<DescriptionTranslation> translateVnDescription(
    String vnId,
    String description, {
    bool useHumanTranslation = true,
  }) async {
    if (useHumanTranslation) {
      try {
        final human = await _vndbtran.lookup(vnId);
        if (human != null && human.trim().isNotEmpty) {
          return DescriptionTranslation(text: human, humanTranslated: true);
        }
      } catch (_) {
        // Mirror unavailable — fall through to machine translation.
      }
    }
    final machine = await translate(
      description,
      sourceLang: 'en',
      targetLang: 'zh',
    );
    return DescriptionTranslation(text: machine, humanTranslated: false);
  }

  /// Translates [text] from [sourceLang] to [targetLang].
  ///
  /// [sourceLang] and [targetLang] are ISO-639-1 codes (e.g. 'en', 'zh',
  /// 'ja'). For long texts the input is split on sentence/paragraph
  /// boundaries and each chunk is translated separately.
  Future<String> translate(
    String text, {
    String sourceLang = 'en',
    String targetLang = 'zh',
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return '';

    final chunks = _splitText(trimmed);
    final translations = <String>[];
    for (final chunk in chunks) {
      final translated = await _translateChunk(
        chunk,
        sourceLang,
        targetLang,
      );
      translations.add(translated);
    }
    return translations.join(' ');
  }

  /// Splits [text] into chunks no longer than [_maxChunkLength] characters,
  /// preferring to break at paragraph boundaries, then sentence boundaries.
  List<String> _splitText(String text) {
    if (text.length <= _maxChunkLength) return [text];

    final chunks = <String>[];
    // Split on double newlines (paragraphs) first.
    final paragraphs = text.split(RegExp(r'\n\s*\n'));
    final buffer = StringBuffer();

    void flushBuffer() {
      if (buffer.isNotEmpty) {
        chunks.add(buffer.toString().trim());
        buffer.clear();
      }
    }

    for (final para in paragraphs) {
      if (para.length <= _maxChunkLength) {
        if ((buffer.length + para.length + 2) > _maxChunkLength) {
          flushBuffer();
        }
        if (buffer.isNotEmpty) buffer.write('\n\n');
        buffer.write(para);
        continue;
      }
      // Paragraph too long: split on sentence boundaries.
      flushBuffer();
      final sentences = para.split(RegExp(r'(?<=[.!?。！？])\s+'));
      for (final sentence in sentences) {
        if (sentence.length <= _maxChunkLength) {
          if ((buffer.length + sentence.length + 1) > _maxChunkLength) {
            flushBuffer();
          }
          if (buffer.isNotEmpty) buffer.write(' ');
          buffer.write(sentence);
          continue;
        }
        // Sentence still too long: hard-split.
        flushBuffer();
        for (var i = 0; i < sentence.length; i += _maxChunkLength) {
          final end = (i + _maxChunkLength > sentence.length)
              ? sentence.length
              : i + _maxChunkLength;
          chunks.add(sentence.substring(i, end));
        }
      }
    }
    flushBuffer();
    return chunks;
  }

  Future<String> _translateChunk(
    String chunk,
    String sourceLang,
    String targetLang,
  ) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/get',
        queryParameters: {
          'q': chunk,
          'langpair': '$sourceLang|$targetLang',
        },
      );
      final data = response.data;
      if (data == null) return chunk;
      final responseData = data['responseData'] as Map<String, dynamic>?;
      if (responseData == null) return chunk;
      final translated = responseData['translatedText'];
      if (translated == null) return chunk;
      return translated.toString();
    } catch (_) {
      // On error, return the original chunk so partial results still show.
      return chunk;
    }
  }
}
