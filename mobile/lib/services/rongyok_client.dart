import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../models/series.dart';
import 'json_extract.dart';

/// Talks to rongyok.com. Three confirmed endpoints, no auth / captcha / ad-gate
/// required (ported from RongYokDownloader.Services.RongYokClient):
///   1. GET /category?category=all              → embedded `seriesData` array (whole catalog)
///   2. GET /watch/?series_id={id}              → embedded object with episodes_count + episodes[]
///   3. GET /watch/get_video.php?series_id&ep   → `{"ok":true,"video_url":"…mp4"}`
///
/// Video files live on a CDN (signed, expiring ~24h, plain MP4 — H.264/AAC, no DRM),
/// so we resolve a fresh URL every time we play or download an episode.
class RongYokClient {
  static const String baseUrl = 'https://rongyok.com';

  static const String userAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/125.0.0.0 Safari/537.36';

  final Dio _http;

  RongYokClient({Dio? dio})
      : _http = dio ??
            Dio(BaseOptions(
              connectTimeout: const Duration(seconds: 30),
              receiveTimeout: const Duration(seconds: 60),
              headers: {
                'User-Agent': userAgent,
                'Accept-Language': 'th,en;q=0.8',
              },
              // rongyok pages are HTML/JS with embedded JSON — read them as text.
              responseType: ResponseType.plain,
              followRedirects: true,
            ));

  static final RegExp _episodesCountPattern = RegExp(r'"episodes_count"\s*:\s*(\d+)');

  // ------------------------------------------------------------- 1. catalog

  /// Downloads and parses the full catalog (~2,300+ series).
  Future<List<Series>> fetchCatalog({CancelToken? cancelToken}) async {
    final resp = await _http.get<String>(
      '$baseUrl/category?category=all',
      cancelToken: cancelToken,
    );
    final html = resp.data ?? '';
    final arrayJson = JsonExtract.catalogArray(html);
    if (arrayJson == null) {
      throw StateError('ไม่พบข้อมูลซีรี่ส์ในหน้าเว็บ (seriesData) — โครงสร้างเว็บอาจเปลี่ยนไป');
    }

    final decoded = jsonDecode(arrayJson);
    final list = <Series>[];
    if (decoded is List) {
      for (final el in decoded) {
        if (el is Map<String, dynamic>) {
          final s = Series.fromJson(el);
          if (s != null) list.add(s);
        }
      }
    }
    return list;
  }

  // ------------------------------------------------------- 2. episode list

  /// Returns the episode numbers for a series (and thus the count).
  /// Parses the embedded `episodes` array; falls back to 1..episodes_count.
  Future<List<int>> fetchEpisodeNumbers(int seriesId, {CancelToken? cancelToken}) async {
    final resp = await _http.get<String>(
      '$baseUrl/watch/?series_id=$seriesId',
      cancelToken: cancelToken,
    );
    final html = resp.data ?? '';

    final nums = <int>[];
    final epArray = JsonExtract.episodesArray(html);
    if (epArray != null) {
      try {
        final decoded = jsonDecode(epArray);
        if (decoded is List) {
          for (final e in decoded) {
            if (e is Map && e['episode_number'] is num) {
              nums.add((e['episode_number'] as num).toInt());
            }
          }
        }
      } on FormatException {
        // fall through to count-based
      }
    }

    if (nums.isEmpty) {
      final m = _episodesCountPattern.firstMatch(html);
      if (m != null) {
        final count = int.tryParse(m.group(1) ?? '');
        if (count != null) {
          for (var i = 1; i <= count; i++) {
            nums.add(i);
          }
        }
      }
    }

    nums.sort();
    return nums;
  }

  // --------------------------------------------------------- 3. video url

  /// Resolves the direct (CDN) MP4 URL for one episode. Null if unavailable.
  /// The endpoint requires a Referer + `X-Requested-With` header to answer.
  Future<String?> getVideoUrl(int seriesId, int ep, {CancelToken? cancelToken}) async {
    try {
      final resp = await _http.get<String>(
        '$baseUrl/watch/get_video.php?series_id=$seriesId&ep=$ep',
        cancelToken: cancelToken,
        options: Options(
          headers: {
            'Referer': '$baseUrl/watch/?series_id=$seriesId&ep=$ep',
            'X-Requested-With': 'XMLHttpRequest',
          },
        ),
      );
      final body = resp.data ?? '';
      final decoded = jsonDecode(body);
      if (decoded is! Map) return null;

      final okRaw = decoded['ok'];
      final ok = okRaw == true || okRaw == 'true';
      if (!ok) return null;

      final url = decoded['video_url'];
      return url is String && url.isNotEmpty ? url : null;
    } catch (e) {
      if (kDebugMode) debugPrint('getVideoUrl($seriesId, $ep) failed: $e');
      return null;
    }
  }

  /// HTTP headers to attach when streaming/downloading a resolved MP4 URL.
  static Map<String, String> get mediaHeaders => {'User-Agent': userAgent};
}
