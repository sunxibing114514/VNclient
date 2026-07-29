import 'package:dio/dio.dart';

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
        );

  final Dio _dio;

  /// Maximum text length per request (bytes). The MyMemory free tier allows
  /// 500 bytes; we use 400 to leave room for URL-encoding overhead.
  static const int _maxChunkLength = 400;

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
