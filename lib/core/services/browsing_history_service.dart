import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/app_constants.dart';

/// A browsing history entry: a VN id plus the timestamp it was viewed.
class HistoryEntry {
  const HistoryEntry({
    required this.vnId,
    required this.viewedAt,
  });

  final String vnId;
  final int viewedAt;

  Map<String, dynamic> toJson() => {
        'vnId': vnId,
        'viewedAt': viewedAt,
      };

  factory HistoryEntry.fromJson(Map<String, dynamic> json) {
    return HistoryEntry(
      vnId: json['vnId'] as String? ?? '',
      viewedAt: json['viewedAt'] as int? ?? 0,
    );
  }
}

/// State notifier that owns the browsing history list.
///
/// History is persisted to [SharedPreferences] as a JSON array of
/// [HistoryEntry] objects. When a VN detail page is opened, [record] is
/// called which moves the entry to the front (most-recent-first order),
/// deduplicates, and trims to [AppConstants.browsingHistoryLimit].
class BrowsingHistoryService extends StateNotifier<List<HistoryEntry>> {
  BrowsingHistoryService() : super(const []) {
    _loadFuture = _load();
  }

  SharedPreferences? _prefs;
  late final Future<void> _loadFuture;

  Future<void> _load() async {
    _prefs = await SharedPreferences.getInstance();
    final raw = _prefs!.getString(AppConstants.browsingHistoryKey);
    if (raw != null) {
      final list = jsonDecode(raw) as List;
      state = list
          .map((e) => HistoryEntry.fromJson(e as Map<String, dynamic>))
          .toList();
    }
  }

  Future<void> _persist() async {
    await _prefs?.setString(
      AppConstants.browsingHistoryKey,
      jsonEncode(state.map((e) => e.toJson()).toList()),
    );
  }

  /// Records a VN view, moving it to the front of the history list.
  Future<void> record(String vnId) async {
    // Ensure the initial load has finished so we don't overwrite it.
    await _loadFuture;
    final now = DateTime.now().millisecondsSinceEpoch;
    final filtered =
        state.where((e) => e.vnId != vnId).toList(growable: true);
    filtered.insert(0, HistoryEntry(vnId: vnId, viewedAt: now));
    // Trim to the configured limit.
    if (filtered.length > AppConstants.browsingHistoryLimit) {
      filtered.removeRange(
          AppConstants.browsingHistoryLimit, filtered.length);
    }
    state = filtered;
    await _persist();
  }

  /// Removes a single entry from the history.
  Future<void> remove(String vnId) async {
    await _loadFuture;
    state = state.where((e) => e.vnId != vnId).toList();
    await _persist();
  }

  /// Clears the entire history.
  Future<void> clear() async {
    await _loadFuture;
    state = const [];
    await _persist();
  }
}

final browsingHistoryProvider =
    StateNotifierProvider<BrowsingHistoryService, List<HistoryEntry>>((ref) {
  return BrowsingHistoryService();
});
