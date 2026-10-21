import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/app_constants.dart';

class Announcement {
  const Announcement({
    required this.id,
    required this.title,
    required this.content,
    required this.date,
    required this.pinned,
  });

  final String id;
  final String title;
  final String content;
  final String date;
  final bool pinned;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'content': content,
        'date': date,
        'pinned': pinned,
      };

  factory Announcement.fromJson(Map<String, dynamic> json) {
    return Announcement(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      content: json['content'] as String? ?? '',
      date: json['date'] as String? ?? '',
      pinned: json['pinned'] as bool? ?? false,
    );
  }
}

class AnnouncementState {
  const AnnouncementState({
    this.items = const [],
    this.seenIds = const <String>{},
    this.fetching = false,
  });

  final List<Announcement> items;
  final Set<String> seenIds;
  final bool fetching;

  bool get hasUnseen => items.any((a) => !seenIds.contains(a.id));
  int get unseenCount => items.where((a) => !seenIds.contains(a.id)).length;

  AnnouncementState copyWith({
    List<Announcement>? items,
    Set<String>? seenIds,
    bool? fetching,
  }) {
    return AnnouncementState(
      items: items ?? this.items,
      seenIds: seenIds ?? this.seenIds,
      fetching: fetching ?? this.fetching,
    );
  }
}

class AnnouncementService extends StateNotifier<AnnouncementState> {
  AnnouncementService(this._dio) : super(const AnnouncementState()) {
    _loaded = _load();
  }

  final Dio _dio;
  SharedPreferences? _prefs;
  late final Future<void> _loaded;
  bool _fetching = false;

  static List<Announcement> _parseItems(Object? data) {
    Map<String, dynamic>? root;
    if (data is String) {
      var text = data;
      if (text.startsWith('\uFEFF')) text = text.substring(1);
      try {
        final decoded = jsonDecode(text);
        if (decoded is Map<String, dynamic>) root = decoded;
      } catch (_) {
        final cleaned = _stripJsonComments(text);
        if (cleaned != text) {
          try {
            final decoded = jsonDecode(cleaned);
            if (decoded is Map<String, dynamic>) root = decoded;
          } catch (_) {}
        }
      }
    } else if (data is Map<String, dynamic>) {
      root = data;
    }
    if (root == null) return const [];
    final raw = root['announcements'];
    if (raw is! List) return const [];
    final items = <Announcement>[];
    for (final e in raw) {
      if (e is! Map<String, dynamic>) continue;
      final item = Announcement.fromJson(e);
      if (item.id.isEmpty || item.title.isEmpty) continue;
      items.add(item);
    }
    items.sort((a, b) {
      if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
      final byDate = b.date.compareTo(a.date);
      if (byDate != 0) return byDate;
      return b.id.compareTo(a.id);
    });
    return items;
  }

  static String _stripJsonComments(String source) {
    final sb = StringBuffer();
    var inString = false;
    var escaped = false;
    for (var i = 0; i < source.length; i++) {
      final c = source[i];
      if (escaped) {
        sb.write(c);
        escaped = false;
        continue;
      }
      if (inString) {
        if (c == '\\') {
          sb.write(c);
          escaped = true;
        } else {
          if (c == '"') inString = false;
          sb.write(c);
        }
        continue;
      }
      if (c == '"') {
        inString = true;
        sb.write(c);
        continue;
      }
      if (c == '/' && i + 1 < source.length) {
        final next = source[i + 1];
        if (next == '/') {
          while (i < source.length && source.codeUnitAt(i) != 10) {
            i++;
          }
          sb.write('\n');
          continue;
        }
        if (next == '*') {
          i += 2;
          while (i + 1 < source.length &&
              !(source[i] == '*' && source[i + 1] == '/')) {
            i++;
          }
          i++;
          sb.write(' ');
          continue;
        }
      }
      sb.write(c);
    }
    return sb.toString();
  }

  Future<void> _load() async {
    _prefs = await SharedPreferences.getInstance();
    final seenRaw =
        _prefs!.getStringList(AppConstants.announcementsSeenKey) ?? [];
    final cachedRaw = _prefs!.getString(AppConstants.announcementsCacheKey);
    var items = const <Announcement>[];
    if (cachedRaw != null) {
      items = _parseItems(cachedRaw);
    }
    state = AnnouncementState(
      items: items,
      seenIds: seenRaw.toSet(),
    );
    unawaited(refresh());
  }

  Future<void> refresh() async {
    await _loaded;
    if (_fetching) return;
    _fetching = true;
    state = state.copyWith(fetching: true);
    try {
      final response = await _dio.get<dynamic>(
        AppConstants.announcementsUrl,
        options: Options(
          responseType: ResponseType.plain,
          sendTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 15),
        ),
      );
      final items = _parseItems(response.data);
      await _prefs?.setString(
        AppConstants.announcementsCacheKey,
        jsonEncode({'announcements': items.map((e) => e.toJson()).toList()}),
      );
      state = state.copyWith(items: items, fetching: false);
    } catch (_) {
      state = state.copyWith(fetching: false);
    } finally {
      _fetching = false;
    }
  }

  Future<void> markAllSeen() async {
    await _loaded;
    if (state.items.isEmpty) return;
    final seen = <String>{...state.seenIds, ...state.items.map((e) => e.id)};
    if (seen.length == state.seenIds.length) return;
    state = state.copyWith(seenIds: seen);
    await _prefs
        ?.setStringList(AppConstants.announcementsSeenKey, seen.toList());
  }
}

final announcementServiceProvider =
    StateNotifierProvider<AnnouncementService, AnnouncementState>((ref) {
  return AnnouncementService(Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 15),
  )));
});
