import 'package:shared_preferences/shared_preferences.dart';

enum AppLang { th, en }

/// Lightweight persisted app settings (language, subscription flag, download
/// concurrency, dismissed-update tag). Mirrors the desktop app's SettingsStore.
class SettingsStore {
  SettingsStore._(this._prefs);

  final SharedPreferences _prefs;

  static Future<SettingsStore> load() async =>
      SettingsStore._(await SharedPreferences.getInstance());

  static const _kLang = 'lang';
  static const _kPro = 'subscription_pro';
  static const _kSkippedTag = 'skipped_update_tag';
  static const _kOnboarded = 'onboarded';

  AppLang get language =>
      _prefs.getString(_kLang) == 'en' ? AppLang.en : AppLang.th;
  Future<void> setLanguage(AppLang l) =>
      _prefs.setString(_kLang, l == AppLang.en ? 'en' : 'th');

  /// Whether the user has "Pro" — an **ad-free** viewing pass (129฿/mo). All
  /// content is free to watch either way; Pro just removes the ads. This is a
  /// local flag for now — no real billing is wired.
  bool get isPro => _prefs.getBool(_kPro) ?? false;
  Future<void> setPro(bool v) => _prefs.setBool(_kPro, v);

  /// Release tag the user chose to skip ("ข้ามเวอร์ชัน").
  String? get skippedUpdateTag => _prefs.getString(_kSkippedTag);
  Future<void> setSkippedUpdateTag(String? tag) => tag == null
      ? _prefs.remove(_kSkippedTag)
      : _prefs.setString(_kSkippedTag, tag);

  bool get onboarded => _prefs.getBool(_kOnboarded) ?? false;
  Future<void> setOnboarded(bool v) => _prefs.setBool(_kOnboarded, v);
}
