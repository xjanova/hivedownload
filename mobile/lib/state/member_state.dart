import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/member.dart';
import '../services/account_store.dart';
import '../services/auth_service.dart';
import '../services/netwix_client.dart';
import '../services/reward_config.dart';

/// The app-facing account/coins/gating state. Local-first (AccountStore) and
/// backend-ready (NetwixClient). All coin mutations are optimistic locally and
/// mirrored to netwix.online when it's live (server is authoritative later).
class MemberState extends ChangeNotifier {
  MemberState(this._store, this._netwix, this._auth);

  final AccountStore _store;
  final NetwixClient _netwix;
  final AuthService _auth;

  Member? _member;
  int _coins = 0;

  Member? get member => _member;
  bool get isLoggedIn => _member?.isLoggedIn ?? false;
  int get coins => _coins;
  String get referralCode => _member?.referralCode ?? '';

  void init() {
    _member = _store.member;
    _coins = _store.coins;
    if (_member?.token != null) _netwix.setToken(_member!.token);
    notifyListeners();
  }

  // -------------------------------------------------------------- auth

  Future<AuthResult> login(AuthProvider provider) async {
    final res = await _auth.signIn(provider);
    _member = res.member;
    await _store.setMember(res.member);
    if (res.member.token != null) _netwix.setToken(res.member.token);

    // ล็อกอินครั้งแรกด้วยบัญชี → +10 เหรียญ (ครั้งเดียวตลอดกาล)
    if (!_store.firstLoginBonusDone) {
      await _addCoins(RewardConfig.firstLoginBonus, 'first_login');
      await _store.setFirstLoginBonusDone();
    }
    notifyListeners();
    return res;
  }

  Future<void> logout() async {
    _member = null;
    _netwix.setToken(null);
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

  /// Free for the first [freeEpisodes], for Pro members, or if unlocked.
  bool isEpisodeUnlocked(int seriesId, List<int> episodes, int ep, {required bool isPro}) {
    if (isPro) return true;
    final idx = episodes.indexOf(ep);
    if (idx >= 0 && idx < RewardConfig.freeEpisodes) return true;
    return _store.isUnlocked(seriesId, ep);
  }

  bool isUnlocked(int seriesId, int ep) => _store.isUnlocked(seriesId, ep);

  /// Spends coins to unlock one episode. Returns false if not enough coins.
  Future<bool> unlockEpisode(int seriesId, int ep) async {
    if (_store.isUnlocked(seriesId, ep)) return true;
    if (!await _spend(RewardConfig.unlockCost)) return false;
    await _store.addUnlock(seriesId, ep);
    unawaited(_netwix.unlock(seriesId, ep));
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
