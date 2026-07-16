import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/notice.dart';
import '../services/netwix_api.dart';
import '../services/settings_store.dart';

/// In-app notification inbox: polls `GET /api/app/notifications` (on launch and
/// every [_pollEvery] while the app is open), filters by the user's per-category
/// toggles, and tracks the unread badge against a locally stored last-seen id.
class NotificationState extends ChangeNotifier {
  NotificationState(this._api, this._settings);

  final NetwixApi _api;
  final SettingsStore _settings;

  static const _pollEvery = Duration(minutes: 5);
  static const categories = ['new_content', 'news', 'other'];

  List<AppNotice> _all = const [];
  Timer? _timer;
  bool _loading = false;

  bool get loading => _loading && _all.isEmpty;

  /// Notices in the categories the user has enabled, newest first.
  List<AppNotice> get notices =>
      _all.where((n) => _settings.notifyCategory(n.category)).toList();

  /// Unread = enabled-category notices newer than the last inbox visit.
  int get unreadCount {
    final seen = _settings.lastSeenNoticeId;
    return notices.where((n) => n.id > seen).length;
  }

  bool categoryEnabled(String category) => _settings.notifyCategory(category);

  Future<void> setCategoryEnabled(String category, bool enabled) async {
    await _settings.setNotifyCategory(category, enabled);
    notifyListeners();
    // Mirror the toggle to the FCM topic so pushes stop/start at the source.
    // Imported lazily to avoid a hard dependency cycle at construction time.
    unawaited(_syncTopic?.call(category, enabled));
  }

  /// Hook installed by PushService (kept as a callback so this state class
  /// stays testable without Firebase).
  static Future<void> Function(String category, bool enabled)? _syncTopic;
  static set topicSync(Future<void> Function(String, bool)? fn) => _syncTopic = fn;

  /// Start polling (call once from app bootstrap).
  void start() {
    unawaited(refresh());
    _timer ??= Timer.periodic(_pollEvery, (_) => unawaited(refresh()));
  }

  Future<void> refresh() async {
    if (_loading) return;
    _loading = true;
    try {
      final items = await _api.fetchNotifications();
      if (items.isNotEmpty || _all.isEmpty) {
        _all = items;
      }
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// The inbox was opened — everything currently visible is now "seen".
  Future<void> markAllSeen() async {
    final top = _all.isEmpty ? 0 : _all.map((n) => n.id).reduce((a, b) => a > b ? a : b);
    if (top > _settings.lastSeenNoticeId) {
      await _settings.setLastSeenNoticeId(top);
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
