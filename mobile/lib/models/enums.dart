/// Language track of a series, parsed from the poster file name on rongyok.com.
/// Ported from RongYokDownloader.Models.DubType (desktop app).
enum DubType {
  unknown,

  /// พากย์ไทย — Thai dubbed.
  thaiDub,

  /// ซับไทย — Thai subtitles.
  thaiSub,
}

extension DubTypeX on DubType {
  String get thai => switch (this) {
        DubType.thaiDub => 'พากย์ไทย',
        DubType.thaiSub => 'ซับไทย',
        _ => 'ไม่ระบุ',
      };

  String get english => switch (this) {
        DubType.thaiDub => 'Thai dub',
        DubType.thaiSub => 'Thai sub',
        _ => 'Unknown',
      };

  /// Best-effort language detection from a rongyok poster path / title.
  static DubType detect(String? text) {
    if (text == null || text.isEmpty) return DubType.unknown;
    if (text.contains('พากย์ไทย')) return DubType.thaiDub;
    if (text.contains('ซับไทย')) return DubType.thaiSub;
    return DubType.unknown;
  }
}
