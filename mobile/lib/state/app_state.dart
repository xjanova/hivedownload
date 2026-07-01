import 'package:flutter/foundation.dart';

import '../l10n/l10n.dart';
import '../services/settings_store.dart';

/// Global UI state: language, subscription flag, onboarding.
class AppState extends ChangeNotifier {
  AppState(this.settings);
  final SettingsStore settings;

  AppLang get lang => settings.language;
  L10n get l => L10n(lang);
  bool get isPro => settings.isPro;
  bool get onboarded => settings.onboarded;

  Future<void> setLang(AppLang v) async {
    await settings.setLanguage(v);
    notifyListeners();
  }

  Future<void> toggleLang() => setLang(lang == AppLang.th ? AppLang.en : AppLang.th);

  Future<void> setPro(bool v) async {
    await settings.setPro(v);
    notifyListeners();
  }

  Future<void> completeOnboarding() async {
    await settings.setOnboarded(true);
    notifyListeners();
  }
}
