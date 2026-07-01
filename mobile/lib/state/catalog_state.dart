import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/enums.dart';
import '../models/series.dart';
import '../services/catalog_db.dart';
import '../services/rongyok_client.dart';

/// The design's category chips mapped onto what rongyok actually exposes
/// (all titles are vertical Thai short-dramas): All / Thai-dub / Thai-sub /
/// Popular. Kept faithful to the source catalog rather than inventing a
/// vertical/horizontal taxonomy the site doesn't have.
enum CatalogFilter { all, thaiDub, thaiSub, popular }

extension CatalogFilterX on CatalogFilter {
  String get th => switch (this) {
        CatalogFilter.all => 'ทั้งหมด',
        CatalogFilter.thaiDub => 'พากย์ไทย',
        CatalogFilter.thaiSub => 'ซับไทย',
        CatalogFilter.popular => 'ยอดนิยม',
      };
  String get en => switch (this) {
        CatalogFilter.all => 'All',
        CatalogFilter.thaiDub => 'Dubbed',
        CatalogFilter.thaiSub => 'Subbed',
        CatalogFilter.popular => 'Popular',
      };
}

class CatalogState extends ChangeNotifier {
  CatalogState(this._client, this._db);
  final RongYokClient _client;
  final CatalogDb _db;

  List<Series> _all = [];
  bool loading = false;
  String? error;
  String _query = '';
  CatalogFilter filter = CatalogFilter.all;
  DateTime? lastSynced;

  bool get isEmpty => _all.isEmpty;
  int get total => _all.length;
  String get query => _query;

  /// Cache-first: shows the SQLite-cached catalog instantly, then refreshes
  /// from rongyok in the background and upserts the DB.
  Future<void> load({bool force = false}) async {
    if (loading) return;
    if (_all.isNotEmpty && !force) return;
    loading = true;
    error = null;
    notifyListeners();

    // 1) instant paint from the local cache
    if (_all.isEmpty) {
      try {
        final cached = await _db.getAllSeries();
        if (cached.isNotEmpty) {
          _all = cached;
          lastSynced = await _db.lastCatalogSync();
          notifyListeners();
        }
      } catch (e) {
        if (kDebugMode) debugPrint('catalog cache read failed: $e');
      }
    }

    // 2) refresh from the network, then persist
    try {
      final fresh = await _client.fetchCatalog();
      _all = fresh;
      error = null;
      unawaited(_db.upsertSeries(fresh));
      lastSynced = DateTime.now();
    } catch (e) {
      // Keep showing the cache; only surface an error if we have nothing.
      if (_all.isEmpty) {
        error = e is StateError ? e.message : 'โหลดคลังซีรี่ส์ไม่สำเร็จ ตรวจสอบการเชื่อมต่อ';
      }
      if (kDebugMode) debugPrint('catalog load failed: $e');
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

  /// Filtered + searched + sorted list for the UI.
  List<Series> get visible {
    Iterable<Series> list = _all;

    switch (filter) {
      case CatalogFilter.thaiDub:
        list = list.where((s) => s.type == DubType.thaiDub);
        break;
      case CatalogFilter.thaiSub:
        list = list.where((s) => s.type == DubType.thaiSub);
        break;
      case CatalogFilter.all:
      case CatalogFilter.popular:
        break;
    }

    if (_query.isNotEmpty) {
      final q = _query.toLowerCase();
      list = list.where((s) =>
          s.cleanTitle.toLowerCase().contains(q) ||
          s.title.toLowerCase().contains(q) ||
          s.description.toLowerCase().contains(q));
    }

    final result = list.toList();
    if (filter == CatalogFilter.popular) {
      result.sort((a, b) => b.viewCount.compareTo(a.viewCount));
    }
    return result;
  }

  /// A few high-view titles for the "featured" rail.
  List<Series> get featured {
    final copy = List<Series>.from(_all)..sort((a, b) => b.viewCount.compareTo(a.viewCount));
    return copy.take(10).toList();
  }
}
