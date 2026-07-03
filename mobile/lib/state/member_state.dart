import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/member.dart';
import '../services/account_store.dart';
import '../services/auth_service.dart';
import '../services/netwix_api.dart';
import '../services/netwix_client.dart';
import '../services/reward_config.dart';

/// The app-facing account/coins state. Auth + identity come from NetWix
/// (bearer token on [NetwixApi]); coins/activities stay local-first for now.
class MemberState extends ChangeNotifier {
  MemberState(this._store, this._netwix, this._api, this._auth);

  final AccountStore _store;
  final NetwixClient _netwix;
  final NetwixApi _api;
  final AuthService _auth;

  Member? _member;
  int _coins = 0;

  Member? get member => _member;
  bool get isLoggedIn => _member?.isLoggedIn ?? false;
  bool get isPro => _member?.isPro ?? false;
  int get coins => _coins;
  String get referralCode => _member?.referralCode ?? '';

  void init() {
    _member = _store.member;
    _coins = _store.coins;
    final token = _member?.token;
    _netwix.setToken(token);
    _api.setToken(token);
    notifyListeners();
    if (token != null) unawaited(_refreshMe());
  }

  /// Re-pull the profile from the server (name/avatar/plan may have changed).
  Future<void> _refreshMe() async {
    final me = await _api.fetchMe();
    if (me == null) return; // transient/401 — keep the cached member
    _member = Member.fromNetwixUser(me, token: _member?.token);
    await _store.setMember(_member);
    notifyListeners();
  }

  // -------------------------------------------------------------- auth

  /// Runs the web sign-in bridge. Throws [AuthCancelled] if the user backs out.
  Future<AuthResult> login(AuthProvider provider) async {
    final res = await _auth.signIn(provider);
    _member = res.member;
    await _store.setMember(res.member);
    _netwix.setToken(res.member.token);
    _api.setToken(res.member.token);

    // ล็อกอินครั้งแรกด้วยบัญชี → +10 เหรียญ (ครั้งเดียวตลอดกาล)
    if (!_store.firstLoginBonusDone) {
      await _addCoins(RewardConfig.firstLoginBonus, 'first_login');
      await _store.setFirstLoginBonusDone();
    }
    notifyListeners();
    return res;
  }

  Future<void> logout() async {
    await _api.logoutToken(); // best-effort server revoke
    _member = null;
    _netwix.setToken(null);
    _api.setToken(null);
    await _store.setMember(null);
    notifyListeners();
  }

  // ------------------------------------------------------------- coins

  Future<void> _addCoins(int delta, String reason) async {
    _coins = (_coins + delta).clamp(0, 1 << 31);
    await _store.setCoins(_coins);
    unawaited(_netwix.earn(reason)); // server reconciles when live
  }

  /// Public earn (referral bonuses, etc.).
  Future<void> earn(int delta, String reason) async {
    await _addCoins(delta, reason);
    notifyListeners();
  }

  Future<bool> _spend(int amount) async {
    if (_coins < amount) return false;
    _coins -= amount;
    await _store.setCoins(_coins);
    return true;
  }

  // ----------------------------------------------------------- gating

  /// Free for the first [freeEpisodes] (by position), for Pro members, or if
  /// unlocked. When the lock is disabled, every episode is free.
  /// [episodeId] is the stable NetWix episode id used as the unlock key.
  bool isEpisodeUnlocked(int contentId, int episodeId, int index, {required bool isPro}) {
    if (!RewardConfig.gatingEnabled) return true;
    if (isPro) return true;
    if (index < RewardConfig.freeEpisodes) return true;
    return _store.isUnlocked(contentId, episodeId);
  }

  bool isUnlocked(int contentId, int episodeId) => _store.isUnlocked(contentId, episodeId);

  /// Spends coins to unlock one episode. Returns false if not enough coins.
  Future<bool> unlockEpisode(int contentId, int episodeId) async {
    if (_store.isUnlocked(contentId, episodeId)) return true;
    if (!await _spend(RewardConfig.unlockCost)) return false;
    await _store.addUnlock(contentId, episodeId);
    unawaited(_netwix.unlock(contentId, episodeId));
    notifyListeners();
    return true;
  }

  int get unlockCost => RewardConfig.unlockCost;

  // -------------------------------------------------------- activities

  String get _today {
    final d = DateTime.now();
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  bool get checkedInToday => _store.activityCount(_today, 'checkin') > 0;

  /// Daily check-in → coins (once per day). Returns coins granted (0 if already).
  Future<int> dailyCheckIn() async {
    if (checkedInToday) return 0;
    await _store.bumpActivity(_today, 'checkin');
    await _addCoins(RewardConfig.dailyCheckin, 'daily_checkin');
    notifyListeners();
    return RewardConfig.dailyCheckin;
  }

  int get rewardWatchesToday => _store.activityCount(_today, 'reward');
  bool get canRewardWatch => rewardWatchesToday < RewardConfig.rewardWatchDailyMax;

  /// Grants coins for finishing a reward clip (respects the daily cap).
  Future<int> claimRewardWatch() async {
    if (!canRewardWatch) return 0;
    await _store.bumpActivity(_today, 'reward');
    await _addCoins(RewardConfig.rewardWatchCoins, 'reward_watch');
    notifyListeners();
    return RewardConfig.rewardWatchCoins;
  }
}
