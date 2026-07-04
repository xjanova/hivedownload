import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/content.dart';
import '../services/catalog_db.dart';
import '../services/netwix_api.dart';

/// An Explore/Home category chip. Backed by a media [type] (series|movie|
/// vertical), a [genre] slug, the [anime] bucket, or 'all'. The five base chips
/// are fixed; genre chips are appended from the server taxonomy (`/genres`) so
/// the app's categories always match the web.
class CatalogCategory {
  const CatalogCategory({
    required this.id,
    required this.th,
    required this.en,
    this.type,
    this.genre,
    this.anime = false,
  });

  /// 'all' | 'series' | 'movie' | 'vertical' | 'anime' | 'g:{slug}'
  final String id;
  final String th;
  final String en;
  final String? type; // media type
  final String? genre; // genre slug
  final bool anime; // anime/cartoon bucket

  bool get isAll => id == 'all';
  String label(bool isTh) => isTh ? th : en;

  static const all = CatalogCategory(id: 'all', th: 'ทั้งหมด', en: 'All');

  /// Fixed chips shown before the server genre list.
  static const base = <CatalogCategory>[
    all,
    CatalogCategory(id: 'series', th: 'ซีรีส์', en: 'Series', type: 'series'),
    CatalogCategory(id: 'movie', th: 'ภาพยนตร์', en: 'Movies', type: 'movie'),
    CatalogCategory(id: 'vertical', th: 'แนวตั้ง', en: 'Vertical', type: 'vertical'),
    CatalogCategory(id: 'anime', th: 'อนิเมะ', en: 'Anime', anime: true),
  ];
}

/// Catalog sourced entirely from NetWix (`/api/app/*`). Cache-first: paints the
/// SQLite-cached list instantly, then refreshes from NetWix.
class CatalogState extends ChangeNotifier {
  CatalogState(this._api, this._db);
  final NetwixApi _api;
  final CatalogDb _db;

  List<Content> _all = [];
  Content? _hero;
  List<NetwixRail> _rails = const [];
  List<CatalogCategory> _genreCats = const [];
  // Server-fetched results per non-'all' category, cached by category id so
  // re-tapping a chip doesn't refetch.
  final Map<String, List<Content>> _byId = {};
  bool loading = false;
  bool filterLoading = false;
  String? error;
  String _query = '';
  CatalogCategory _current = CatalogCategory.all;

  bool get isEmpty => _all.isEmpty;
  int get total => _all.length;
  String get query => _query;
  Content? get hero => _hero;

  /// The web's curated home rails (trending + genre rails incl. an anime rail).
  List<NetwixRail> get rails => _rails;

  /// Base chips + the server genre taxonomy (anime is already the base 'anime'
  /// chip, so the genre-anime entries are dropped here to avoid duplicates).
  List<CatalogCategory> get categories => [...CatalogCategory.base, ..._genreCats];
  CatalogCategory get current => _current;

  Future<void> load({bool force = false}) async {
    if (loading) return;
    if (_all.isNotEmpty && !force) return;
    loading = true;
    error = null;
    if (force) _byId.clear(); // drop cached category results on manual refresh
    notifyListeners();

    if (_all.isEmpty) {
      try {
        final cached = await _db.getAllContent();
        if (cached.isNotEmpty) {
          _all = cached;
          notifyListeners();
        }
      } catch (e) {
        if (kDebugMode) debugPrint('catalog cache read: $e');
      }
    }

    try {
      final home = await _api.fetchHome();
      final titles = await _api.fetchTitles(per: 48);
      final genres = await _api.fetchGenres();
      _hero = home?.hero;
      if (home != null && home.rails.isNotEmpty) _rails = home.rails;
      if (genres.isNotEmpty) {
        _genreCats = genres
            .where((g) => !g.isAnime)
            .map((g) => CatalogCategory(
                  id: 'g:${g.slug}',
                  th: g.name,
                  en: g.nameEn ?? g.name,
                  genre: g.slug,
                ))
            .toList();
      }
      if (titles.isNotEmpty) {
        _all = titles;
        unawaited(_db.upsertContent(titles));
        error = null;
      } else if (_all.isEmpty) {
        error = 'โหลดคลังหนังไม่สำเร็จ ตรวจสอบการเชื่อมต่อ';
      }
    } catch (e) {
      if (_all.isEmpty) error = 'โหลดคลังหนังไม่สำเร็จ ตรวจสอบการเชื่อมต่อ';
      if (kDebugMode) debugPrint('catalog load: $e');
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  void setQuery(String q) {
    _query = q.trim();
    notifyListeners();
  }

  /// Switch category. 'all' shows the cached full list; any other category is
  /// fetched from the server (`/titles?type=|genre=|anime=`) and cached by id.
  Future<void> setCategory(CatalogCategory cat) async {
    if (_current.id == cat.id) return;
    _current = cat;
    notifyListeners();
    if (cat.isAll || _byId.containsKey(cat.id)) return; // cached / no fetch
    filterLoading = true;
    notifyListeners();
    try {
      _byId[cat.id] = await _api.fetchTitles(
          type: cat.type, genre: cat.genre, anime: cat.anime, per: 60);
    } catch (e) {
      _byId[cat.id] = const [];
      if (kDebugMode) debugPrint('catalog setCategory(${cat.id}): $e');
    } finally {
      filterLoading = false;
      notifyListeners();
    }
  }

  /// The items backing the current category (before search is applied).
  List<Content> get _source =>
      _current.isAll ? _all : (_byId[_current.id] ?? const []);

  List<Content> get visible {
    Iterable<Content> list = _source;
    if (_query.isNotEmpty) {
      final q = _query.toLowerCase();
      list = list.where((c) =>
          c.title.toLowerCase().contains(q) || c.synopsis.toLowerCase().contains(q));
    }
    return list.toList();
  }

  List<Content> get featured {
    final copy = List<Content>.from(_all)..sort((a, b) => b.views.compareTo(a.views));
    return copy.take(10).toList();
  }
}
