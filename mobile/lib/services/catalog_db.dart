import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../models/series.dart';

/// One "continue watching" entry (resume row joined with its series).
class ResumeItem {
  ResumeItem(this.series, this.episode, this.positionSec, this.durationSec);
  final Series series;
  final int episode;
  final int positionSec;
  final int durationSec;
  double get progress => durationSec > 0 ? positionSec / durationSec : 0;
}

/// Local SQLite cache for the streaming app (mirrors the desktop `rongyok.db`,
/// minus download state). Holds:
///   • series          — the whole catalog (offline-friendly, instant open)
///   • series_episodes — cached episode-number list per series
///   • video_cache     — resolved MP4 URLs with a timestamp (reused only while
///                       fresh; the CDN links expire ~24h so we re-resolve)
///   • resume          — last watched position per (series, episode)
///   • meta            — small key/value (e.g. last catalog sync time)
class CatalogDb {
  CatalogDb._(this._db);
  final Database _db;

  /// How long a cached video URL may be reused before we re-resolve it.
  static const Duration videoUrlTtl = Duration(hours: 12);

  static Future<CatalogDb> open() async {
    final dir = await getApplicationSupportDirectory();
    final path = p.join(dir.path, 'hivedownload.db');
    final db = await openDatabase(
      path,
      version: 1,
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE series (
            id             INTEGER PRIMARY KEY,
            title          TEXT NOT NULL DEFAULT '',
            clean_title    TEXT NOT NULL DEFAULT '',
            description    TEXT NOT NULL DEFAULT '',
            type           INTEGER NOT NULL DEFAULT 0,
            poster_url     TEXT NOT NULL DEFAULT '',
            jpg_url        TEXT NOT NULL DEFAULT '',
            view_count     INTEGER NOT NULL DEFAULT 0,
            created_at     TEXT NOT NULL DEFAULT '',
            episodes_count INTEGER NOT NULL DEFAULT 0,
            year           INTEGER
          )''');
        await db.execute('''
          CREATE TABLE series_episodes (
            series_id      INTEGER NOT NULL,
            episode_number INTEGER NOT NULL,
            PRIMARY KEY (series_id, episode_number)
          )''');
        await db.execute('''
          CREATE TABLE video_cache (
            series_id      INTEGER NOT NULL,
            episode_number INTEGER NOT NULL,
            url            TEXT NOT NULL,
            resolved_at    INTEGER NOT NULL,
            PRIMARY KEY (series_id, episode_number)
          )''');
        await db.execute('''
          CREATE TABLE resume (
            series_id      INTEGER NOT NULL,
            episode_number INTEGER NOT NULL,
            position_sec   INTEGER NOT NULL,
            duration_sec   INTEGER NOT NULL,
            updated_at     INTEGER NOT NULL,
            PRIMARY KEY (series_id, episode_number)
          )''');
        await db.execute('CREATE TABLE meta (key TEXT PRIMARY KEY, value TEXT)');
      },
    );
    return CatalogDb._(db);
  }

  // ----------------------------------------------------------------- series

  Future<void> upsertSeries(List<Series> items) async {
    final batch = _db.batch();
    for (final s in items) {
      batch.insert('series', _seriesToRow(s), conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
    await setMeta('catalog_synced_at', '${DateTime.now().millisecondsSinceEpoch}');
  }

  Future<List<Series>> getAllSeries() async {
    final rows = await _db.query('series');
    return rows.map(_rowToSeries).toList();
  }

  Future<int> seriesCount() async =>
      Sqflite.firstIntValue(await _db.rawQuery('SELECT COUNT(*) FROM series')) ?? 0;

  Future<DateTime?> lastCatalogSync() async {
    final v = await getMeta('catalog_synced_at');
    final ms = int.tryParse(v ?? '');
    return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
  }

  // --------------------------------------------------------------- episodes

  Future<void> upsertEpisodes(int seriesId, List<int> episodes) async {
    final batch = _db.batch();
    for (final n in episodes) {
      batch.insert('series_episodes', {'series_id': seriesId, 'episode_number': n},
          conflictAlgorithm: ConflictAlgorithm.ignore);
    }
    batch.update('series', {'episodes_count': episodes.length},
        where: 'id = ?', whereArgs: [seriesId]);
    await batch.commit(noResult: true);
  }

  Future<List<int>> getEpisodes(int seriesId) async {
    final rows = await _db.query('series_episodes',
        columns: ['episode_number'],
        where: 'series_id = ?',
        whereArgs: [seriesId],
        orderBy: 'episode_number');
    return rows.map((r) => (r['episode_number'] as num).toInt()).toList();
  }

  // ------------------------------------------------------------- video urls

  /// Returns a cached MP4 URL only if it was resolved within [videoUrlTtl].
  Future<String?> freshVideoUrl(int seriesId, int ep) async {
    final rows = await _db.query('video_cache',
        where: 'series_id = ? AND episode_number = ?', whereArgs: [seriesId, ep], limit: 1);
    if (rows.isEmpty) return null;
    final resolvedAt = (rows.first['resolved_at'] as num).toInt();
    final age = DateTime.now().millisecondsSinceEpoch - resolvedAt;
    if (age > videoUrlTtl.inMilliseconds) return null;
    return rows.first['url'] as String?;
  }

  Future<void> cacheVideoUrl(int seriesId, int ep, String url) async {
    await _db.insert(
        'video_cache',
        {
          'series_id': seriesId,
          'episode_number': ep,
          'url': url,
          'resolved_at': DateTime.now().millisecondsSinceEpoch,
        },
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Drops a cached URL (e.g. it turned out to be dead) so the next play
  /// re-resolves a fresh one.
  Future<void> invalidateVideoUrl(int seriesId, int ep) async {
    await _db.delete('video_cache',
        where: 'series_id = ? AND episode_number = ?', whereArgs: [seriesId, ep]);
  }

  // ---------------------------------------------------------------- resume

  Future<void> saveResume(int seriesId, int ep, int positionSec, int durationSec) async {
    // Don't remember trivial or finished positions.
    if (positionSec < 5 || (durationSec > 0 && positionSec > durationSec - 10)) {
      await _db.delete('resume',
          where: 'series_id = ? AND episode_number = ?', whereArgs: [seriesId, ep]);
      return;
    }
    await _db.insert(
        'resume',
        {
          'series_id': seriesId,
          'episode_number': ep,
          'position_sec': positionSec,
          'duration_sec': durationSec,
          'updated_at': DateTime.now().millisecondsSinceEpoch,
        },
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<int?> getResume(int seriesId, int ep) async {
    final rows = await _db.query('resume',
        columns: ['position_sec'],
        where: 'series_id = ? AND episode_number = ?',
        whereArgs: [seriesId, ep],
        limit: 1);
    return rows.isEmpty ? null : (rows.first['position_sec'] as num).toInt();
  }

  /// Most-recently-watched, unfinished episodes, newest first.
  Future<List<ResumeItem>> continueWatching({int limit = 10}) async {
    final rows = await _db.rawQuery('''
      SELECT r.episode_number AS ep, r.position_sec AS pos, r.duration_sec AS dur, s.*
      FROM resume r JOIN series s ON s.id = r.series_id
      ORDER BY r.updated_at DESC LIMIT ?''', [limit]);
    return rows
        .map((row) => ResumeItem(
              _rowToSeries(row),
              (row['ep'] as num).toInt(),
              (row['pos'] as num).toInt(),
              (row['dur'] as num).toInt(),
            ))
        .toList();
  }

  // ------------------------------------------------------------------ meta

  Future<String?> getMeta(String key) async {
    final rows = await _db.query('meta', where: 'key = ?', whereArgs: [key], limit: 1);
    return rows.isEmpty ? null : rows.first['value'] as String?;
  }

  Future<void> setMeta(String key, String value) => _db.insert(
      'meta', {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace);

  // --------------------------------------------------------------- mapping

  Map<String, Object?> _seriesToRow(Series s) => {
        'id': s.id,
        'title': s.title,
        'clean_title': s.cleanTitle,
        'description': s.description,
        'type': s.type.index,
        'poster_url': s.posterUrl,
        'jpg_url': s.jpgUrl,
        'view_count': s.viewCount,
        'created_at': s.createdAt,
        'episodes_count': s.episodesCount,
        'year': s.year,
      };

  Series _rowToSeries(Map<String, Object?> m) => Series.fromDbRow(m);

  Future<void> close() async {
    try {
      await _db.close();
    } catch (e) {
      if (kDebugMode) debugPrint('CatalogDb.close: $e');
    }
  }
}
