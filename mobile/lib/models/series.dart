import 'enums.dart';

/// A drama/series on rongyok.com. Mirrors the `seriesData` objects embedded in
/// `/category?category=all` plus a few fields we compute or fill in later.
/// Ported from RongYokDownloader.Models.Series (desktop app).
class Series {
  Series({
    required this.id,
    this.title = '',
    this.cleanTitle = '',
    this.description = '',
    this.type = DubType.unknown,
    this.posterUrl = '',
    this.jpgUrl = '',
    this.viewCount = 0,
    this.createdAt = '',
    this.episodesCount = 0,
    this.year,
  });

  final int id;

  /// Raw title from the site (often carries a trailing "th" language tag).
  final String title;

  /// Cleaned, display-ready title (suffix stripped).
  String cleanTitle;

  final String description;

  DubType type;

  /// Absolute URL of the .webp poster.
  final String posterUrl;

  /// Absolute URL of the .jpg poster.
  final String jpgUrl;

  int viewCount;

  final String createdAt;

  /// Number of episodes. 0 until the detail page has been loaded.
  int episodesCount;

  /// Publication year parsed from the poster file name, if present.
  int? year;

  // ---- computed helpers ----
  String get typeThai => type.thai;
  String get yearText => year?.toString() ?? '';

  /// Best image URL for display. Unlike the WPF app, Flutter decodes .webp
  /// natively, so we can use the (usually higher quality) poster directly and
  /// only fall back to the jpg.
  String get displayImageUrl => posterUrl.isNotEmpty ? posterUrl : jpgUrl;

  String get viewCountText =>
      viewCount >= 1000 ? '${(viewCount / 1000.0).toStringAsFixed(1)}K' : '$viewCount';

  /// The rongyok poster filename encodes the clean title, language and year:
  /// `poster/{title}-{พากย์ไทย|ซับไทย}-{year}-{id}.{ext}`
  static final RegExp _posterPattern =
      RegExp(r'poster/(?<title>.+?)-(?<type>พากย์ไทย|ซับไทย)-(?<year>\d{4})-(?<id>\d+)\.');

  /// Parses one `seriesData` object. Returns null if it has no numeric `id`.
  static Series? fromJson(Map<String, dynamic> el) {
    final idRaw = el['id'];
    final id = idRaw is int ? idRaw : int.tryParse('${idRaw ?? ''}');
    if (id == null) return null;

    final rawTitle = _str(el, 'title');
    final posterRel = _str(el, 'poster_url');
    final jpgRel = _str(el, 'jpg_url');

    final s = Series(
      id: id,
      title: rawTitle,
      description: _str(el, 'description'),
      posterUrl: _toAbsolute(posterRel),
      jpgUrl: _toAbsolute(jpgRel.isEmpty ? posterRel : jpgRel),
      viewCount: _int(el, 'view_count'),
      createdAt: _str(el, 'created_at'),
    );

    // Derive clean title, language and year from the poster file name — it's the
    // most reliable source.
    final m = _posterPattern.firstMatch(posterRel);
    if (m != null) {
      s.cleanTitle = _tryDecode(m.namedGroup('title') ?? '');
      s.type = DubTypeX.detect(m.namedGroup('type'));
      final y = int.tryParse(m.namedGroup('year') ?? '');
      if (y != null) s.year = y;
    } else {
      s.type = DubTypeX.detect('$posterRel$rawTitle');
    }

    if (s.cleanTitle.trim().isEmpty) {
      s.cleanTitle = _cleanTitle(rawTitle);
    }
    return s;
  }

  /// rongyok poster titles are usually percent-encoded, but not always well —
  /// a single malformed `%` must not crash the whole catalog parse. Fall back
  /// to the raw value on any decode error.
  static String _tryDecode(String v) {
    try {
      return Uri.decodeComponent(v);
    } catch (_) {
      return v;
    }
  }

  /// Strips the trailing "th" language tag the site appends to raw titles.
  static String _cleanTitle(String raw) {
    var t = raw.trim();
    if (t.length > 2 && t.toLowerCase().endsWith('th')) {
      t = t.substring(0, t.length - 2).trimRight();
    }
    return t;
  }

  static String _str(Map<String, dynamic> el, String key) {
    final v = el[key];
    return v is String ? v : '';
  }

  static int _int(Map<String, dynamic> el, String key) {
    final v = el[key];
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse('${v ?? ''}') ?? 0;
  }

  static const String baseUrl = 'https://rongyok.com';

  static String _toAbsolute(String rel) {
    if (rel.isEmpty) return '';
    if (rel.toLowerCase().startsWith('http')) return rel;
    return '$baseUrl/${rel.replaceFirst(RegExp(r'^/+'), '')}';
  }
}
