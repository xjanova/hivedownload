import '../services/settings_store.dart' show AppLang;

/// Tiny bilingual helper. The design shows Thai primary + English secondary,
/// often together, so screens use [pick] (one language) or [bi] (both).
class L10n {
  const L10n(this.lang);
  final AppLang lang;

  bool get isTh => lang == AppLang.th;

  /// One language based on the current selection.
  String pick(String th, String en) => isTh ? th : en;

  /// Bilingual "th · en" line (as used throughout the design copy).
  String bi(String th, String en) => '$th · $en';
}
