import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../models/ad.dart';

/// Ad delivery client + rotator. Pulls ad creatives from the Thaiprompt backend
/// (`main.thaiprompt.online`) and cycles through them so the UI can show a
/// rotating banner. Everything in the app is free to watch; **Pro (129฿/mo)
/// simply removes these ads**, so callers must gate the banner on `!isPro`.
///
/// The ad backend is not built yet — this client is wired and ready. Until the
/// endpoint returns data it degrades to a silent no-op (empty list → no banner),
/// so shipping it now is safe.
///
/// ── Backend contract to implement on main.thaiprompt.online (Laravel) ──
/// GET /api/ads?app=hivedownload&placement=player[&limit=N]
///   → { "success": true,
///       "data": [ { "id", "image_url", "click_url"?, "weight"?,
///                   "duration_ms"?, "placement"?, "starts_at"?, "ends_at"? } ],
///       "rotate_ms": 8000 }
/// Public (no auth). Matches the ecosystem envelope ({success,data,...}).
class AdService extends ChangeNotifier {
  AdService({Dio? dio, this.app = 'hivedownload'})
      : _dio = dio ??
            Dio(BaseOptions(
              baseUrl: baseUrl,
              connectTimeout: const Duration(seconds: 8),
              receiveTimeout: const Duration(seconds: 10),
              headers: {'Accept': 'application/json'},
            ));

  static const String baseUrl = 'https://main.thaiprompt.online';
  static const String adsPath = '/api/ads';

  final Dio _dio;
  final String app;

  final Map<String, List<Ad>> _byPlacement = {};
  int _rotateMs = 8000;

  final Map<String, int> _index = {};
  Timer? _timer;
  bool _started = false;

  /// The ad currently in rotation for [placement], or null when there are none.
  Ad? current(String placement) {
    final list = _byPlacement[placement];
    if (list == null || list.isEmpty) return null;
    final i = (_index[placement] ?? 0) % list.length;
    return list[i];
  }

  bool hasAds(String placement) => (_byPlacement[placement]?.isNotEmpty) ?? false;

  /// Fetches ads for the given placements and (re)starts rotation. Safe to call
  /// on every app launch; failures are swallowed.
  Future<void> start({List<String> placements = const ['player']}) async {
    _started = true;
    await Future.wait(placements.map(_fetch));
    _restartTimer();
  }

  Future<void> refresh(String placement) async {
    await _fetch(placement);
    if (_started) _restartTimer();
  }

  Future<void> _fetch(String placement) async {
    try {
      final resp = await _dio.get<Map<String, dynamic>>(
        adsPath,
        queryParameters: {'app': app, 'placement': placement},
      );
      final data = resp.data;
      if (data == null || data['success'] != true) return;

      final raw = data['data'];
      final ads = <Ad>[];
      if (raw is List) {
        for (final e in raw) {
          if (e is Map<String, dynamic>) {
            final ad = Ad.fromJson(e);
            if (ad != null) ads.add(ad);
          }
        }
      }
      // expand by weight for fair rotation
      final playlist = <Ad>[];
      for (final ad in ads) {
        for (var i = 0; i < ad.weight.clamp(1, 10); i++) {
          playlist.add(ad);
        }
      }
      _byPlacement[placement] = playlist;

      final r = (data['rotate_ms'] as num?)?.toInt();
      if (r != null && r >= 2000) _rotateMs = r;

      notifyListeners();
    } catch (e) {
      // Backend not ready / offline / empty → no ads. Silent by design.
      if (kDebugMode) debugPrint('AdService._fetch($placement) skipped: $e');
    }
  }

  void _restartTimer() {
    _timer?.cancel();
    final anyAds = _byPlacement.values.any((l) => l.isNotEmpty);
    if (!anyAds) return;
    _timer = Timer.periodic(Duration(milliseconds: _rotateMs), (_) {
      for (final key in _byPlacement.keys) {
        _index[key] = (_index[key] ?? 0) + 1;
      }
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
