import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/endpoints/vn_endpoint.dart';
import '../constants/app_constants.dart';
import '../providers/endpoints_provider.dart';

/// A producer the user follows. Tracks the timestamp of the last new-work
/// check so that only releases dated after that point generate notifications.
class FollowedProducer {
  const FollowedProducer({
    required this.id,
    required this.name,
    this.lastSeenAt = 0,
    this.followedAt = 0,
  });

  final String id;
  final String name;
  /// MillisecondsSinceEpoch of the last check for new works. When the user
  /// first follows a producer this is set to "now"; after each check it is
  /// updated to the check time so subsequent checks only surface newer
  /// releases.
  final int lastSeenAt;
  final int followedAt;

  FollowedProducer copyWith({
    String? name,
    int? lastSeenAt,
    int? followedAt,
  }) {
    return FollowedProducer(
      id: id,
      name: name ?? this.name,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
      followedAt: followedAt ?? this.followedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'lastSeenAt': lastSeenAt,
        'followedAt': followedAt,
      };

  factory FollowedProducer.fromJson(Map<String, dynamic> json) {
    return FollowedProducer(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      lastSeenAt: json['lastSeenAt'] as int? ?? 0,
      followedAt: json['followedAt'] as int? ?? 0,
    );
  }
}

/// A notification about a new work from a followed producer.
class ProducerNotification {
  const ProducerNotification({
    required this.id,
    required this.producerId,
    required this.producerName,
    required this.vnId,
    required this.vnTitle,
    this.released,
    this.createdAt = 0,
    this.read = false,
  });

  /// Unique id: `notif_<vnId>`.
  final String id;
  final String producerId;
  final String producerName;
  final String vnId;
  final String vnTitle;
  final String? released;
  final int createdAt;
  final bool read;

  ProducerNotification copyWith({bool? read}) {
    return ProducerNotification(
      id: id,
      producerId: producerId,
      producerName: producerName,
      vnId: vnId,
      vnTitle: vnTitle,
      released: released,
      createdAt: createdAt,
      read: read ?? this.read,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'producerId': producerId,
        'producerName': producerName,
        'vnId': vnId,
        'vnTitle': vnTitle,
        'released': released,
        'createdAt': createdAt,
        'read': read,
      };

  factory ProducerNotification.fromJson(Map<String, dynamic> json) {
    return ProducerNotification(
      id: json['id'] as String? ?? '',
      producerId: json['producerId'] as String? ?? '',
      producerName: json['producerName'] as String? ?? '',
      vnId: json['vnId'] as String? ?? '',
      vnTitle: json['vnTitle'] as String? ?? '',
      released: json['released'] as String?,
      createdAt: json['createdAt'] as int? ?? 0,
      read: json['read'] as bool? ?? false,
    );
  }
}

/// Formats a millisecond timestamp as `YYYY-MM-DD` for the VNDB `released`
/// filter, which accepts partial date strings.
String _millisToDateStr(int millis) {
  final dt = DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true);
  final y = dt.year.toString();
  final m = dt.month.toString().padLeft(2, '0');
  final d = dt.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}

/// Formats a millisecond timestamp as `YYYY-MM-DD HH:mm` for display.
String _millisToDisplay(int millis) {
  final dt = DateTime.fromMillisecondsSinceEpoch(millis);
  final y = dt.year.toString();
  final m = dt.month.toString().padLeft(2, '0');
  final d = dt.day.toString().padLeft(2, '0');
  final h = dt.hour.toString().padLeft(2, '0');
  final min = dt.minute.toString().padLeft(2, '0');
  return '$y-$m-$d $h:$min';
}

/// State notifier owning the followed-producers list and the notifications.
///
/// Both collections are persisted to [SharedPreferences] as JSON. The new-work
/// check queries the `/vn` endpoint with a `developer` filter combined with a
/// `released >= lastSeenAt` date filter, generating a notification for each VN
/// released after the previously recorded check time. After a successful check
/// the timestamp is advanced to "now" so the next check only surfaces newer
/// releases.
class FollowService extends StateNotifier<FollowState> {
  FollowService(this._vnEndpoint) : super(const FollowState()) {
    _load();
  }

  final VnEndpoint _vnEndpoint;
  SharedPreferences? _prefs;
  bool _checking = false;

  Future<void> _load() async {
    _prefs = await SharedPreferences.getInstance();
    final followedRaw = _prefs!.getString(AppConstants.followedProducersKey);
    final notifRaw = _prefs!.getString(AppConstants.producerNotificationsKey);
    final followed = <FollowedProducer>[];
    if (followedRaw != null) {
      final list = jsonDecode(followedRaw) as List;
      followed.addAll(
        list.map((e) => FollowedProducer.fromJson(e as Map<String, dynamic>)),
      );
    }
    final notifs = <ProducerNotification>[];
    if (notifRaw != null) {
      final list = jsonDecode(notifRaw) as List;
      notifs.addAll(
        list.map((e) => ProducerNotification.fromJson(e as Map<String, dynamic>)),
      );
    }
    state = FollowState(followed: followed, notifications: notifs);
  }

  Future<void> _persist() async {
    await _prefs?.setString(
      AppConstants.followedProducersKey,
      jsonEncode(state.followed.map((e) => e.toJson()).toList()),
    );
    await _prefs?.setString(
      AppConstants.producerNotificationsKey,
      jsonEncode(state.notifications.map((e) => e.toJson()).toList()),
    );
  }

  bool isFollowing(String producerId) {
    return state.followed.any((p) => p.id == producerId);
  }

  Future<void> follow(String producerId, String name) async {
    if (isFollowing(producerId)) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    final entry = FollowedProducer(
      id: producerId,
      name: name,
      lastSeenAt: now,
      followedAt: now,
    );
    state = FollowState(
      followed: [...state.followed, entry],
      notifications: state.notifications,
    );
    await _persist();
  }

  Future<void> unfollow(String producerId) async {
    state = FollowState(
      followed: state.followed.where((p) => p.id != producerId).toList(),
      notifications: state.notifications,
    );
    await _persist();
  }

  /// Marks all notifications as read (clears the red-dot badge).
  Future<void> markAllRead() async {
    if (state.notifications.every((n) => n.read)) return;
    state = FollowState(
      followed: state.followed,
      notifications:
          state.notifications.map((n) => n.copyWith(read: true)).toList(),
    );
    await _persist();
  }

  Future<void> dismissNotification(String notificationId) async {
    state = FollowState(
      followed: state.followed,
      notifications: state.notifications
          .where((n) => n.id != notificationId)
          .toList(),
    );
    await _persist();
  }

  Future<void> clearAllNotifications() async {
    state = FollowState(
      followed: state.followed,
      notifications: const [],
    );
    await _persist();
  }

  /// Checks every followed producer for VNs released after the last check
  /// time and records notifications for each. After a successful check the
  /// `lastSeenAt` timestamp is advanced to "now". Safe to call repeatedly;
  /// concurrent calls are ignored.
  Future<int> checkForNewWorks() async {
    if (_checking) return 0;
    if (state.followed.isEmpty) return 0;
    _checking = true;
    int newCount = 0;
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      final newNotifs = <ProducerNotification>[];
      final updatedFollowed = <FollowedProducer>[];

      for (final producer in state.followed) {
        try {
          // Use the recorded timestamp; if missing (migrated data), fall
          // back to "now" so the first check starts fresh.
          final threshold = producer.lastSeenAt > 0 ? producer.lastSeenAt : now;
          final dateStr = _millisToDateStr(threshold);

          final result = await _vnEndpoint.query(
            filters: [
              'and',
              ['developer', '=', ['id', '=', producer.id]],
              ['released', '>=', dateStr],
            ],
            fields: 'title, released',
            sort: 'released',
            reverse: true,
            results: 50,
            page: 1,
          );
          final vns = result.results;
          for (final vn in vns) {
            newNotifs.add(ProducerNotification(
              id: 'notif_${vn.id}_${producer.id}',
              producerId: producer.id,
              producerName: producer.name,
              vnId: vn.id,
              vnTitle: vn.title,
              released: vn.released,
              createdAt: now,
            ));
          }
          updatedFollowed.add(producer.copyWith(lastSeenAt: now));
        } catch (_) {
          // Network/API errors for a single producer shouldn't abort the loop.
          updatedFollowed.add(producer);
        }
      }

      // Merge new notifications, deduping by id and keeping newest-first.
      if (newNotifs.isNotEmpty) {
        final existing = state.notifications;
        final existingIds = existing.map((e) => e.id).toSet();
        final toAdd =
            newNotifs.where((n) => !existingIds.contains(n.id)).toList();
        if (toAdd.isNotEmpty) {
          newCount = toAdd.length;
          final merged = [...toAdd, ...existing]
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
          state = FollowState(
            followed: updatedFollowed,
            notifications: merged,
          );
          await _persist();
          return newCount;
        }
      }
      // No new notifications, but we still updated lastSeenAt bookkeeping.
      state = FollowState(
        followed: updatedFollowed,
        notifications: state.notifications,
      );
      await _persist();
    } finally {
      _checking = false;
    }
    return newCount;
  }
}

/// Immutable view of the followed-producers and notifications state.
class FollowState {
  const FollowState({
    this.followed = const [],
    this.notifications = const [],
  });

  final List<FollowedProducer> followed;
  final List<ProducerNotification> notifications;

  bool get hasUnread => notifications.any((n) => !n.read);
  int get unreadCount => notifications.where((n) => !n.read).length;
}

final followServiceProvider =
    StateNotifierProvider<FollowService, FollowState>((ref) {
  return FollowService(ref.watch(vnEndpointProvider));
});

/// Helper exposed for the follow-list page to render the last-check time.
String formatLastSeenAt(int millis) => _millisToDisplay(millis);
