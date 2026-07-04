import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../models/content.dart';
import '../models/episode.dart';
import '../models/member.dart';

/// Client for the NetWix mobile API (`https://netwix.online/api/app/*`).
///
/// This is the app's ONLY content backend. NetWix resolves each episode's stream
/// server-side, on demand: a FRESH signed CDN mp4 for rongyok (the links expire
/// ~24h but are NOT IP-locked — the old app just kept fetching stale ones), or an
/// HMAC-signed HLS proxy for wow-drama. Either way the client plays the returned
/// url directly (no headers), from any IP. Envelope: `{ "success": bool, "data": {...} }`.
class NetwixApi {
  NetwixApi({Dio? dio, String? token})
      : _token = token,
        _dio = dio ??
            Dio(BaseOptions(
              baseUrl: baseUrl,
              connectTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(seconds: 20),
              headers: {'Accept': 'application/json'},
            ));

  static const String origin = 'https://netwix.online';
  static const String baseUrl = '$origin/api/app';

  final Dio _dio;
  String? _token;

  /// Set/clear the member token (Phase 3). Sent as Bearer on every request.
  void setToken(String? token) => _token = token;

  Options get _opts => Options(headers: {
        if (_token != null) 'Authorization': 'Bearer $_token',
      });

  Map<String, dynamic>? _data(Response r) {
    final b = r.data;
    if (b is Map && b['success'] == true && b['data'] is Map) {
      return (b['data'] as Map).cast<String, dynamic>();
    }
    return null;
  }

  // ------------------------------------------------------------- catalog

  /// Home hero + rails.
  Future<NetwixHome?> fetchHome() async {
    try {
      final d = _data(await _dio.get('/home', options: _opts));
      if (d == null) return null;
      final hero = d['hero'] is Map ? Content.fromJson((d['hero'] as Map).cast<String, dynamic>()) : null;
      final rails = <NetwixRail>[];
      if (d['rails'] is List) {
        for (final r in d['rails']) {
          if (r is Map) rails.add(NetwixRail.fromJson(r.cast<String, dynamic>()));
        }
      }
      return NetwixHome(hero: hero, rails: rails);
    } catch (e) {
      if (kDebugMode) debugPrint('netwix fetchHome: $e');
      return null;
    }
  }

  /// One page of titles + total + whether more pages exist — for the Explore
  /// grid's infinite scroll. Narrow by media [type] (series|movie|vertical), by
  /// [genre] slug, or set [anime] for the anime/cartoon bucket.
  Future<PagedContent> fetchTitlesPage(
      {String? type, String? genre, bool anime = false, int page = 1, int per = 30}) async {
    try {
      final d = _data(await _dio.get('/titles', queryParameters: {
        'type': ?type,
        'genre': ?genre,
        if (anime) 'anime': 1,
        'page': page,
        'per': per,
      }, options: _opts));
      return PagedContent(
        _contentList(d?['items']),
        d?['has_more'] == true,
        total: (d?['total'] as num?)?.toInt() ?? 0,
      );
    } catch (e) {
      if (kDebugMode) debugPrint('netwix fetchTitlesPage: $e');
      return const PagedContent(<Content>[], false);
    }
  }

  /// One page of server-side search results (matches title + synopsis).
  Future<PagedContent> searchPage(String q, {int page = 1}) async {
    try {
      final d = _data(await _dio.get('/search',
          queryParameters: {'q': q, 'page': page}, options: _opts));
      return PagedContent(_contentList(d?['items']), d?['has_more'] == true);
    } catch (e) {
      if (kDebugMode) debugPrint('netwix searchPage: $e');
      return const PagedContent(<Content>[], false);
    }
  }

  /// The genre taxonomy for the app's category chips (name, name_en, slug,
  /// is_anime). Empty on failure.
  Future<List<GenreChip>> fetchGenres() async {
    try {
      final d = _data(await _dio.get('/genres', options: _opts));
      final items = d?['items'];
      if (items is! List) return const [];
      return items
          .whereType<Map>()
          .map((m) => GenreChip.fromJson(m.cast<String, dynamic>()))
          .toList();
    } catch (e) {
      if (kDebugMode) debugPrint('netwix fetchGenres: $e');
      return const [];
    }
  }

  Future<NetwixDetail?> fetchDetail(String slug) async {
    try {
      final d = _data(await _dio.get('/titles/$slug', options: _opts));
      if (d == null) return null;
      return NetwixDetail(
        content: Content.fromJson((d['content'] as Map).cast<String, dynamic>()),
        episodes: _episodeList(d['episodes']),
        related: _contentList(d['related']),
      );
    } catch (e) {
      if (kDebugMode) debugPrint('netwix fetchDetail: $e');
      return null;
    }
  }

  // ------------------------------------------------------------- playback

  /// Resolves a playable stream for an episode.
  /// Returns null on network error; a [NetwixSource] with `ready=false` when the
  /// episode isn't mirrored yet ("preparing").
  Future<NetwixSource?> resolveSource(int episodeId) async {
    try {
      final r = await _dio.get('/episodes/$episodeId/source',
          options: Options(headers: _opts.headers, validateStatus: (s) => s != null && s < 500));
      final b = r.data;
      final data = (b is Map && b['data'] is Map) ? (b['data'] as Map).cast<String, dynamic>() : null;
      if (data == null) return const NetwixSource(ready: false);
      return NetwixSource.fromJson(data);
    } catch (e) {
      if (kDebugMode) debugPrint('netwix resolveSource($episodeId): $e');
      return null;
    }
  }

  // ------------------------------------------------------------- member auth

  /// Exchange the one-time login code (from the netwix:// deep link) for a
  /// bearer token. Returns `{token, user}` or null.
  Future<Map<String, dynamic>?> exchangeCode(String code, {String device = 'android'}) async {
    try {
      final r = await _dio.post('/auth/exchange',
          data: {'code': code, 'device': device},
          options: Options(validateStatus: (s) => s != null && s < 500));
      return _data(r);
    } catch (e) {
      if (kDebugMode) debugPrint('netwix exchangeCode: $e');
      return null;
    }
  }

  /// Current member + default profile (requires a token via [setToken]).
  Future<Map<String, dynamic>?> fetchMe() async {
    try {
      return _data(await _dio.get('/auth/me', options: _opts));
    } catch (e) {
      if (kDebugMode) debugPrint('netwix fetchMe: $e');
      return null;
    }
  }

  /// Revoke the current token server-side. Best-effort.
  Future<void> logoutToken() async {
    try {
      await _dio.post('/auth/logout',
          options: Options(headers: _opts.headers, validateStatus: (s) => s != null && s < 500));
    } catch (e) {
      if (kDebugMode) debugPrint('netwix logoutToken: $e');
    }
  }

  // -------------------------------------------------- member library / social
  //
  // Backed by the real `/api/app/*` member endpoints (Library + Feedback
  // controllers). All writes require a member token (set via [setToken]); the
  // server 401s a guest, which surfaces here as a null return — callers gate on
  // login first and treat null as "offline/declined, keep local state".

  /// Per-title interaction state for the detail screen (liked / in-list / my
  /// rating + counts). Token-only — returns null for guests or on failure.
  Future<ContentState?> fetchContentState(int contentId) async {
    try {
      final d = _data(await _dio.get('/content/$contentId/state', options: _opts));
      return d == null ? null : ContentState.fromJson(d);
    } catch (e) {
      if (kDebugMode) debugPrint('netwix contentState($contentId): $e');
      return null;
    }
  }

  /// Public rating summary (avg + count) — works for guests too.
  Future<RatingSummary?> fetchRatings(int contentId) async {
    try {
      final d = _data(await _dio.get('/content/$contentId/ratings', options: _opts));
      return d == null ? null : RatingSummary.fromJson(d);
    } catch (e) {
      if (kDebugMode) debugPrint('netwix ratings($contentId): $e');
      return null;
    }
  }

  /// Toggle like on a title. Returns the server-authoritative {liked, count}
  /// or null (guest/offline).
  Future<LikeResult?> toggleLike(int contentId) async {
    try {
      final d = _data(await _dio.post('/content/$contentId/like', options: _opts));
      return d == null ? null : LikeResult.fromJson(d);
    } catch (e) {
      if (kDebugMode) debugPrint('netwix toggleLike($contentId): $e');
      return null;
    }
  }

  /// Toggle a title in the member's list. Returns the new in-list flag or null.
  Future<bool?> toggleList(int contentId) async {
    try {
      final d = _data(await _dio.post('/content/$contentId/list', options: _opts));
      return d == null ? null : d['in_list'] == true;
    } catch (e) {
      if (kDebugMode) debugPrint('netwix toggleList($contentId): $e');
      return null;
    }
  }

  /// Rate a title 1–5. Returns {myRating, avg, count} or null.
  Future<RatingResult?> postRating(int contentId, int stars) async {
    try {
      final d = _data(await _dio.post('/content/$contentId/rating',
          data: {'stars': stars}, options: _opts));
      return d == null ? null : RatingResult.fromJson(d);
    } catch (e) {
      if (kDebugMode) debugPrint('netwix postRating($contentId): $e');
      return null;
    }
  }

  /// Comments for a title (public read; newest first). Empty list on failure.
  Future<List<Comment>> fetchComments(int contentId) async {
    try {
      final d = _data(await _dio.get('/content/$contentId/comments', options: _opts));
      final items = d?['items'];
      if (items is! List) return const [];
      return items
          .whereType<Map>()
          .map((m) => Comment.fromJson(m.cast<String, dynamic>()))
          .toList();
    } catch (e) {
      if (kDebugMode) debugPrint('netwix comments($contentId): $e');
      return const [];
    }
  }

  /// Post a comment (token-only). Returns the created comment or null.
  Future<Comment?> postComment(int contentId, String body) async {
    try {
      final d = _data(await _dio.post('/content/$contentId/comments',
          data: {'body': body}, options: _opts));
      final c = d?['comment'];
      return c is Map ? Comment.fromJson(c.cast<String, dynamic>()) : null;
    } catch (e) {
      if (kDebugMode) debugPrint('netwix postComment($contentId): $e');
      return null;
    }
  }

  /// Mirror the on-device resume position to the server (token-only, best-effort
  /// — a guest or a network blip just leaves the local SQLite resume as truth).
  Future<void> saveProgress({
    required int contentId,
    int? episodeId,
    required int positionSeconds,
    int? durationSeconds,
  }) async {
    try {
      await _dio.post('/progress',
          data: {
            'content_id': contentId,
            'episode_id': ?episodeId,
            'position_seconds': positionSeconds,
            'duration_seconds': ?durationSeconds,
          },
          options: Options(
              headers: _opts.headers, validateStatus: (s) => s != null && s < 500));
    } catch (e) {
      if (kDebugMode) debugPrint('netwix saveProgress: $e');
    }
  }

  /// The member's saved list (token-only). Empty on failure.
  Future<List<Content>> fetchMyList() async {
    try {
      final d = _data(await _dio.get('/my-list', options: _opts));
      return _contentList(d?['items']);
    } catch (e) {
      if (kDebugMode) debugPrint('netwix myList: $e');
      return const [];
    }
  }

  /// Server-side continue-watching (token-only). Empty on failure.
  Future<List<ProgressItem>> fetchProgress() async {
    try {
      final d = _data(await _dio.get('/progress', options: _opts));
      final items = d?['items'];
      if (items is! List) return const [];
      return items
          .whereType<Map>()
          .map((m) => ProgressItem.fromJson(m.cast<String, dynamic>()))
          .toList();
    } catch (e) {
      if (kDebugMode) debugPrint('netwix progress: $e');
      return const [];
    }
  }

  List<Content> _contentList(dynamic v) {
    if (v is! List) return const [];
    return v.whereType<Map>().map((m) => Content.fromJson(m.cast<String, dynamic>())).toList();
  }

  List<Episode> _episodeList(dynamic v) {
    if (v is! List) return const [];
    return v.whereType<Map>().map((m) => Episode.fromJson(m.cast<String, dynamic>())).toList();
  }
}

class NetwixHome {
  const NetwixHome({this.hero, required this.rails});
  final Content? hero;
  final List<NetwixRail> rails;
}

/// One page of catalog results (for infinite scroll / search).
class PagedContent {
  const PagedContent(this.items, this.hasMore, {this.total = 0});
  final List<Content> items;
  final bool hasMore;
  final int total; // server total for the query (0 when unknown, e.g. search)
}

/// One genre in the taxonomy (`GET /genres`) — backs an Explore category chip.
class GenreChip {
  const GenreChip({required this.name, this.nameEn, required this.slug, this.isAnime = false});
  final String name;
  final String? nameEn;
  final String slug;
  final bool isAnime;

  factory GenreChip.fromJson(Map<String, dynamic> j) => GenreChip(
        name: (j['name'] as String?) ?? '',
        nameEn: j['name_en'] as String?,
        slug: (j['slug'] as String?) ?? '',
        isAnime: j['is_anime'] == true,
      );
}

class NetwixRail {
  const NetwixRail({required this.key, required this.title, required this.ranked, required this.items});
  final String key;
  final String title;
  final bool ranked;
  final List<Content> items;

  factory NetwixRail.fromJson(Map<String, dynamic> j) => NetwixRail(
        key: (j['key'] as String?) ?? '',
        title: (j['title'] as String?) ?? '',
        ranked: j['ranked'] == true,
        items: (j['items'] is List)
            ? (j['items'] as List).whereType<Map>().map((m) => Content.fromJson(m.cast<String, dynamic>())).toList()
            : const [],
      );
}

class NetwixDetail {
  const NetwixDetail({required this.content, required this.episodes, required this.related});
  final Content content;
  final List<Episode> episodes;
  final List<Content> related;
}

class NetwixSource {
  const NetwixSource({required this.ready, this.kind, this.url});
  final bool ready;
  final String? kind; // 'mp4' | 'hls'
  final String? url;

  bool get isHls => kind == 'hls';

  factory NetwixSource.fromJson(Map<String, dynamic> j) => NetwixSource(
        ready: j['ready'] == true,
        kind: j['kind'] as String?,
        url: j['url'] as String?,
      );
}

/// Per-title member interaction state (`GET /content/{id}/state`).
class ContentState {
  const ContentState({
    this.liked = false,
    this.inList = false,
    this.myRating,
    this.likesCount = 0,
    this.ratingAvg = 0,
    this.ratingCount = 0,
    this.commentsCount = 0,
  });

  final bool liked;
  final bool inList;
  final int? myRating; // 1..5, null if the member hasn't rated
  final int likesCount;
  final double ratingAvg;
  final int ratingCount;
  final int commentsCount;

  factory ContentState.fromJson(Map<String, dynamic> j) => ContentState(
        liked: j['liked'] == true,
        inList: j['in_list'] == true,
        myRating: (j['my_rating'] as num?)?.toInt(),
        likesCount: (j['likes_count'] as num?)?.toInt() ?? 0,
        ratingAvg: (j['rating_avg'] as num?)?.toDouble() ?? 0,
        ratingCount: (j['rating_count'] as num?)?.toInt() ?? 0,
        commentsCount: (j['comments_count'] as num?)?.toInt() ?? 0,
      );
}

/// Result of `POST /content/{id}/like`.
class LikeResult {
  const LikeResult({required this.liked, required this.likesCount});
  final bool liked;
  final int likesCount;

  factory LikeResult.fromJson(Map<String, dynamic> j) => LikeResult(
        liked: j['liked'] == true,
        likesCount: (j['likes_count'] as num?)?.toInt() ?? 0,
      );
}

/// Result of `POST /content/{id}/rating`.
class RatingResult {
  const RatingResult({required this.myRating, required this.avg, required this.count});
  final int myRating;
  final double avg;
  final int count;

  factory RatingResult.fromJson(Map<String, dynamic> j) => RatingResult(
        myRating: (j['my_rating'] as num?)?.toInt() ?? 0,
        avg: (j['avg'] as num?)?.toDouble() ?? 0,
        count: (j['count'] as num?)?.toInt() ?? 0,
      );
}

/// Public rating summary (`GET /content/{id}/ratings`).
class RatingSummary {
  const RatingSummary({required this.avg, required this.count});
  final double avg;
  final int count;

  factory RatingSummary.fromJson(Map<String, dynamic> j) => RatingSummary(
        avg: (j['avg'] as num?)?.toDouble() ?? 0,
        count: (j['count'] as num?)?.toInt() ?? 0,
      );
}

/// One server-side continue-watching row (`GET /progress`).
class ProgressItem {
  const ProgressItem({
    required this.content,
    this.episodeId,
    this.percent = 0,
    this.positionSeconds = 0,
  });

  final Content content;
  final int? episodeId;
  final int percent;
  final int positionSeconds;

  factory ProgressItem.fromJson(Map<String, dynamic> j) => ProgressItem(
        content: Content.fromJson((j['content'] as Map).cast<String, dynamic>()),
        episodeId: (j['episode_id'] as num?)?.toInt(),
        percent: (j['percent'] as num?)?.toInt() ?? 0,
        positionSeconds: (j['position_seconds'] as num?)?.toInt() ?? 0,
      );
}
