import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/member.dart';

/// Local-first persistence for the account layer (member, coin balance, unlocked
/// episodes, daily-activity counters). Authoritative until netwix.online is live;
/// afterwards the server reconciles.
class AccountStore {
  AccountStore._(this._p);
  final SharedPreferences _p;

  static Future<AccountStore> load() async => AccountStore._(await SharedPreferences.getInstance());

  static const _kMember = 'member';
  static const _kCoins = 'coins';
  static const _kUnlocks = 'unlocks'; // List<"seriesId:ep">
  static const _kFirstLogin = 'first_login_bonus_done';
  static const _kActivity = 'daily_activity'; // { "yyyy-mm-dd": { key: count } }

  Member? get member => Member.decode(_p.getString(_kMember));
  Future<void> setMember(Member? m) =>
      m == null ? _p.remove(_kMember) : _p.setString(_kMember, m.encode());

  int get coins => _p.getInt(_kCoins) ?? 0;
  Future<void> setCoins(int v) => _p.setInt(_kCoins, v < 0 ? 0 : v);

  bool get firstLoginBonusDone => _p.getBool(_kFirstLogin) ?? false;
  Future<void> setFirstLoginBonusDone() => _p.setBool(_kFirstLogin, true);

  Set<String> get _unlocks => (_p.getStringList(_kUnlocks) ?? const []).toSet();
  bool isUnlocked(int seriesId, int ep) => _unlocks.contains('$seriesId:$ep');
  Future<void> addUnlock(int seriesId, int ep) async {
    final set = _unlocks..add('$seriesId:$ep');
    await _p.setStringList(_kUnlocks, set.toList());
  }

  // ---- daily activity counters (e.g. reward-watch count, check-in) ----
  Map<String, dynamic> _activityFor(String date) {
    final raw = _p.getString(_kActivity);
    if (raw == null) return {};
    try {
      final all = jsonDecode(raw) as Map<String, dynamic>;
      return (all[date] as Map<String, dynamic>?) ?? {};
    } catch (_) {
      return {};
    }
  }

  int activityCount(String date, String key) => (_activityFor(date)[key] as num?)?.toInt() ?? 0;

  Future<void> bumpActivity(String date, String key) async {
    Map<String, dynamic> all = {};
    final raw = _p.getString(_kActivity);
    if (raw != null) {
      try {
        all = jsonDecode(raw) as Map<String, dynamic>;
      } catch (_) {}
    }
    // keep only today's bucket to avoid unbounded growth
    final today = (all[date] as Map<String, dynamic>?) ?? {};
    today[key] = ((today[key] as num?)?.toInt() ?? 0) + 1;
    await _p.setString(_kActivity, jsonEncode({date: today}));
  }

  Future<void> clear() async {
    await _p.remove(_kMember);
    await _p.remove(_kCoins);
    await _p.remove(_kUnlocks);
    await _p.remove(_kActivity);
    // keep _kFirstLogin so signing in again doesn't re-grant the bonus
  }
}
