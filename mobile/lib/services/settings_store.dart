import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

enum AppLang { th, en }

/// Lightweight persisted app settings (language, playback prefs, dismissed-update
/// tag). Mirrors the desktop app's SettingsStore.
class SettingsStore {
  SettingsStore._(this._prefs);

  final SharedPreferences _prefs;

  static Future<SettingsStore> load() async =>
      SettingsStore._(await SharedPreferences.getInstance());

  static const _kLang = 'lang';
  static const _kLegacyPro = 'subscription_pro';
  static const _kSkippedTag = 'skipped_update_tag';
  static const _kOnboarded = 'onboarded';
  static const _kAutoSkipIntro = 'auto_skip_intro';

  /// "ข้ามอินโทรอัตโนมัติ" — mirrors the web's `localStorage['nx_autoskip']`.
  bool get autoSkipIntro => _prefs.getBool(_kAutoSkipIntro) ?? false;
  Future<void> setAutoSkipIntro(bool v) => _prefs.setBool(_kAutoSkipIntro, v);

  AppLang get language =>
      _prefs.getString(_kLang) == 'en' ? AppLang.en : AppLang.th;
  Future<void> setLanguage(AppLang l) =>
      _prefs.setString(_kLang, l == AppLang.en ? 'en' : 'th');

  /// Pro used to live here as a local bool that the "สมัคร Pro" button simply set
  /// to true — no payment, no server. Because `isEpisodeUnlocked` short-circuits
  /// on Pro, that one tap also unlocked every episode, so the flag gave away both
  /// the ad-free pass and the whole coin economy. Pro is now read only from
  /// MemberState (server-authoritative `pro_until`). This clears the stale key so
  /// an existing install doesn't keep a Pro it never paid for.
  Future<void> clearLegacyProFlag() async {
    if (_prefs.containsKey(_kLegacyPro)) {
      await _prefs.remove(_kLegacyPro);
    }
  }

  /// Release tag the user chose to skip ("ข้ามเวอร์ชัน").
  String? get skippedUpdateTag => _prefs.getString(_kSkippedTag);
  Future<void> setSkippedUpdateTag(String? tag) => tag == null
      ? _prefs.remove(_kSkippedTag)
      : _prefs.setString(_kSkippedTag, tag);

  bool get onboarded => _prefs.getBool(_kOnboarded) ?? false;
  Future<void> setOnboarded(bool v) => _prefs.setBool(_kOnboarded, v);

  // ---------------------------------------------------------- notifications

  /// Per-category notification toggles (default ON). Keys must match the
  /// server's AppNotification categories: new_content | news | other.
  bool notifyCategory(String category) =>
      _prefs.getBool('notify_$category') ?? true;
  Future<void> setNotifyCategory(String category, bool v) =>
      _prefs.setBool('notify_$category', v);

  /// Highest notification id the user has already opened the inbox for —
  /// anything newer counts toward the unread badge.
  int get lastSeenNoticeId => _prefs.getInt('last_seen_notice_id') ?? 0;
  Future<void> setLastSeenNoticeId(int id) =>
      _prefs.setInt('last_seen_notice_id', id);

  // ----------------------------------------------------------------- consent

  /// The user ticked "ยอมรับข้อตกลง/นโยบาย" before signing in. Once accepted the
  /// sheet shows a plain notice instead of re-asking.
  bool get consentAccepted => _prefs.getBool('consent_accepted') ?? false;
  Future<void> setConsentAccepted(bool v) => _prefs.setBool('consent_accepted', v);

  // --------------------------------------------------------------- telemetry

  /// Random per-install key for device statistics. NOT a hardware identifier —
  /// generated on first read, reset by reinstalling the app.
  String get deviceKey {
    var k = _prefs.getString('device_key');
    if (k == null || k.length < 16) {
      final rnd = Random.secure();
      const alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
      k = List.generate(32, (_) => alphabet[rnd.nextInt(alphabet.length)]).join();
      _prefs.setString('device_key', k);
    }
    return k;
  }
}
