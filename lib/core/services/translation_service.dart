import 'dart:convert';

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
/// `https://vndbtran.hjymoon.bbroot.com/?v=17`.
///
/// 社区翻译通过镜像站的 `?v=<编号>` 查询接口获取:
///  - 主请求 `GET /?v=17`, 接口返回纯文本: 命中为译文正文, 未命中为
///    `错误：...` 文本 (其 `&mode=json` 变体返回同样的数据, 此处同样支持)。
///  - 兼容回退: 镜像站当前为纯静态托管, 对 `?v=x` 返回的是 HTML 查询页,
///    纯文本由页面 JS 在浏览器端渲染。此时使用该页面对 `?v=x` 的同一取数
///    方法 (编号寻址): 编号 n 位于第 `((n - 1) ~/ 500) + 1` 个分片文件
///    `000NNN.json` (每片 500 条, 条目形如 `{"v":"17","translate":"..."}`),
///    拉取该分片并取出对应编号的条目, 与页面查询结果一致。
///
/// 命中与未命中均缓存, 重复查询开销很小。
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

  /// Number of VNs stored per JSON shard (编号寻址, used by the fallback).
  static const int perShard = 500;

  /// shard index -> parsed entries (keyed by numeric VN id), or null when the
  /// shard is known to be unavailable (404 / network error).
  final Map<int, Map<String, String>?> _shardCache = {};

  /// vn id (e.g. "v17") -> cached hit translation.
  final Map<String, String> _hitCache = {};

  /// vn ids with a confirmed miss (the mirror has no translation for them).
  final Set<String> _missCache = {};

  int? _vnNumber(String vnId) {
    final trimmed = vnId.trim();
    if (!trimmed.startsWith('v')) return null;
    return int.tryParse(trimmed.substring(1));
  }

  /// Looks up the community human translation for [vnId] through the
  /// mirror's `?v=x` query interface.
  ///
  /// Returns null when the VN is not present in the mirror (or the mirror
  /// is unreachable).
  Future<String?> lookup(String vnId) async {
    final n = _vnNumber(vnId);
    if (n == null) return null;

    final cachedHit = _hitCache[vnId];
    if (cachedHit != null) return cachedHit;
    if (_missCache.contains(vnId)) return null;

    // Primary: the mirror's plain-text query interface, e.g. /?v=17.
    final viaInterface = await _queryInterface(n);
    if (viaInterface != null) {
      if (viaInterface.isEmpty) {
        _missCache.add(vnId); // confirmed miss
        return null;
      }
      _hitCache[vnId] = viaInterface;
      return viaInterface;
    }

    // Fallback: the static mirror answers /?v=x with its HTML query page
    // (the plain text is rendered by the page's own script in a browser),
    // so use the exact method that page uses for a `?v=x` query: the
    // 编号寻址 shard-file lookup.
    final viaShard = await _lookupViaShardFile(n);
    if (viaShard == null) {
      // Mirror unreachable — don't cache, the next lookup can retry.
      return null;
    }
    if (viaShard.isEmpty) {
      _missCache.add(vnId); // confirmed miss
      return null;
    }
    _hitCache[vnId] = viaShard;
    return viaShard;
  }

  /// Queries the `?v=<n>` plain-text interface.
  ///
  /// The interface answers in plain text: the translation itself on a hit,
  /// or an `错误：...` message on a miss. (Its `&mode=json` variant wraps
  /// the same data as JSON — that shape is understood here too.)
  ///
  /// Returns the translation on a hit, an empty string on a confirmed miss,
  /// and null when the interface could not be used (e.g. the static mirror
  /// answered with its HTML page, or the request failed).
  Future<String?> _queryInterface(int n) async {
    try {
      final response = await _dio.get<String>(
        '/',
        queryParameters: {'v': n.toString()},
        options: Options(responseType: ResponseType.plain),
      );
      final body = (response.data ?? '').trim();
      // Plain-text interface: an empty answer is a miss.
      if (body.isEmpty) return '';
      final head = body.length <= 16
          ? body.toLowerCase()
          : body.substring(0, 16).toLowerCase();
      if (head.startsWith('<!doctype') || head.startsWith('<html')) {
        // The static mirror returned its HTML query page — the plain text
        // is rendered client-side by the page's own script in a browser.
        return null;
      }
      if (body.startsWith('错误：') || body.startsWith('错误:')) {
        // The interface's documented error output — a miss.
        return '';
      }
      if (body.startsWith('{') || body.startsWith('[')) {
        // Defensive: also understand the &mode=json answer shape
        // ({"v": ..., "translate": ...} / {"v": ..., "error": ...}).
        final data = jsonDecode(body);
        if (data is! Map<String, dynamic>) return null;
        if (data.containsKey('error')) return '';
        final translate = data['translate']?.toString();
        if (translate == null || translate.trim().isEmpty) return '';
        return translate;
      }
      // Plain text: the translation itself (the `?v=x` output).
      return body;
    } on DioException {
      return null;
    } catch (_) {
      return null;
    }
  }

  /// 编号寻址 shard-file lookup — the method the mirror's own page uses to
  /// answer a `?v=x` query. A VN with numeric id `n` lives in shard
  /// `((n - 1) ~/ 500) + 1`, stored as a zero-padded `000NNN.json` file.
  ///
  /// Returns the translation on a hit, an empty string on a confirmed miss,
  /// and null when the shard could not be fetched.
  Future<String?> _lookupViaShardFile(int n) async {
    final shard = ((n - 1) ~/ perShard) + 1;

    Map<String, String>? shardMap;
    if (_shardCache.containsKey(shard)) {
      shardMap = _shardCache[shard];
    } else {
      shardMap = await _downloadShard(shard.toString().padLeft(6, '0'));
      _shardCache[shard] = shardMap;
    }
    if (shardMap == null) return null;
    final hit = shardMap[n.toString()];
    if (hit == null || hit.trim().isEmpty) return '';
    return hit;
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
