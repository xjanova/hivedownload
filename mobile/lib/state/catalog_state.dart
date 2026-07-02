import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/content.dart';
import '../services/catalog_db.dart';
import '../services/netwix_api.dart';

/// Catalog filter chips → NetWix content types.
enum CatalogFilter { all, series, movie, vertical }

extension CatalogFilterX on CatalogFilter {
  String get th => switch (this) {
        CatalogFilter.all => 'ทั้งหมด',
        CatalogFilter.series => 'ซีรีส์',
        CatalogFilter.movie => 'ภาพยนตร์',
        CatalogFilter.vertical => 'แนวตั้ง',
      };
  String get en => switch (this) {
        CatalogFilter.all => 'All',
        CatalogFilter.series => 'Series',
        CatalogFilter.movie => 'Movies',
        CatalogFilter.vertical => 'Vertical',
      };
  String? get type => switch (this) {
        CatalogFilter.all => null,
        CatalogFilter.series => 'series',
        CatalogFilter.movie => 'movie',
        CatalogFilter.vertical => 'vertical',
      };
}

/// Catalog sourced entirely from NetWix (`/api/app/*`). Cache-first: paints the
/// SQLite-cached list instantly, then refreshes from NetWix.
class CatalogState extends ChangeNotifier {
  CatalogState(this._api, this._db);
  final NetwixApi _api;
  final CatalogDb _db;

  List<Content> _all = [];
  Content? _hero;
  bool loading = false;
  String? error;
  String _query = '';
  CatalogFilter filter = CatalogFilter.all;

  bool get isEmpty => _all.isEmpty;
  int get total => _all.length;
  String get query => _query;
  Content? get hero => _hero;

  Future<void> load({bool force = false}) async {
    if (loading) return;
    if (_all.isNotEmpty && !force) return;
    loading = true;
    error = null;
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
      _hero = home?.hero;
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

  void setFilter(CatalogFilter f) {
    filter = f;
    notifyListeners();
  }

  List<Content> get visible {
    Iterable<Content> list = _all;
    if (filter != CatalogFilter.all) {
      list = list.where((c) => c.type == filter.type);
    }
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
