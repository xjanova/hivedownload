import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../models/content.dart';

/// One "continue watching" entry (resume row joined with its content).
class ResumeItem {
  ResumeItem(this.content, this.episodeId, this.episodeNumber, this.positionSec, this.durationSec);
  final Content content;
  final int episodeId;
  final int episodeNumber;
  final int positionSec;
  final int durationSec;
  double get progress => durationSec > 0 ? positionSec / durationSec : 0;
}

/// Local SQLite cache. Everything comes from NetWix now, so this only holds:
///   • content — the cached catalog (instant paint before the network returns)
///   • resume  — last watched position per (content, episode)
///   • meta    — small key/value (e.g. last catalog sync time)
///
/// Video URLs are no longer cached: NetWix serves stable `/storage/*.mp4`
/// (or an HLS proxy) resolved live per play, so there's nothing to expire.
class CatalogDb {
  CatalogDb._(this._db);
  final Database _db;

  static Future<CatalogDb> open() async {
    final dir = await getApplicationSupportDirectory();
    final path = p.join(dir.path, 'hivedownload.db');
    final db = await openDatabase(
      path,
      version: 2,
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: (db, _) => _createSchema(db),
      onUpgrade: (db, oldVersion, newVersion) async {
        // v1 was the rongyok schema — drop it wholesale and rebuild for NetWix.
        for (final t in ['series', 'series_episodes', 'video_cache', 'resume', 'meta']) {
          await db.execute('DROP TABLE IF EXISTS $t');
        }
        await _createSchema(db);
      },
    );
    return CatalogDb._(db);
  }

  static Future<void> _createSchema(Database db) async {
    await db.execute('''
      CREATE TABLE content (
        id             INTEGER PRIMARY KEY,
        slug           TEXT NOT NULL DEFAULT '',
        title          TEXT NOT NULL DEFAULT '',
        type           TEXT NOT NULL DEFAULT 'series',
        synopsis       TEXT NOT NULL DEFAULT '',
        year           INTEGER,
        rating         REAL NOT NULL DEFAULT 0,
        poster_url     TEXT NOT NULL DEFAULT '',
        backdrop_url   TEXT NOT NULL DEFAULT '',
        views          INTEGER NOT NULL DEFAULT 0,
        episodes_count INTEGER NOT NULL DEFAULT 0
      )''');
    await db.execute('''
      CREATE TABLE resume (
        content_id     INTEGER NOT NULL,
        episode_id     INTEGER NOT NULL,
        episode_number INTEGER NOT NULL,
        position_sec   INTEGER NOT NULL,
        duration_sec   INTEGER NOT NULL,
        updated_at     INTEGER NOT NULL,
        PRIMARY KEY (content_id, episode_id)
      )''');
    await db.execute('CREATE TABLE meta (key TEXT PRIMARY KEY, value TEXT)');
  }

  // ---------------------------------------------------------------- content

  Future<void> upsertContent(List<Content> items) async {
    final batch = _db.batch();
    for (final c in items) {
      batch.insert('content', c.toDbMap(), conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
    await setMeta('catalog_synced_at', '${DateTime.now().millisecondsSinceEpoch}');
  }

  Future<List<Content>> getAllContent() async {
    final rows = await _db.query('content');
    return rows.map(Content.fromDbMap).toList();
  }

  Future<Content?> getContent(int id) async {
    final rows = await _db.query('content', where: 'id = ?', whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : Content.fromDbMap(rows.first);
  }

  Future<int> contentCount() async =>
      Sqflite.firstIntValue(await _db.rawQuery('SELECT COUNT(*) FROM content')) ?? 0;

  Future<DateTime?> lastCatalogSync() async {
    final v = await getMeta('catalog_synced_at');
    final ms = int.tryParse(v ?? '');
    return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
  }

  // ----------------------------------------------------------------- resume

  Future<void> saveResume(
      int contentId, int episodeId, int episodeNumber, int positionSec, int durationSec) async {
    // Don't remember trivial or finished positions.
    if (positionSec < 5 || (durationSec > 0 && positionSec > durationSec - 10)) {
      await _db.delete('resume',
          where: 'content_id = ? AND episode_id = ?', whereArgs: [contentId, episodeId]);
      return;
    }
    await _db.insert(
        'resume',
        {
          'content_id': contentId,
          'episode_id': episodeId,
          'episode_number': episodeNumber,
          'position_sec': positionSec,
          'duration_sec': durationSec,
          'updated_at': DateTime.now().millisecondsSinceEpoch,
        },
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<int?> getResume(int contentId, int episodeId) async {
    final rows = await _db.query('resume',
        columns: ['position_sec'],
        where: 'content_id = ? AND episode_id = ?',
        whereArgs: [contentId, episodeId],
        limit: 1);
    return rows.isEmpty ? null : (rows.first['position_sec'] as num).toInt();
  }

  /// Most-recently-watched, unfinished episodes, newest first.
  Future<List<ResumeItem>> continueWatching({int limit = 10}) async {
    final rows = await _db.rawQuery('''
      SELECT r.episode_id AS eid, r.episode_number AS ep, r.position_sec AS pos,
             r.duration_sec AS dur, c.*
      FROM resume r JOIN content c ON c.id = r.content_id
      ORDER BY r.updated_at DESC LIMIT ?''', [limit]);
    return rows
        .map((row) => ResumeItem(
              Content.fromDbMap(row),
              (row['eid'] as num).toInt(),
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

  Future<void> close() async {
    try {
      await _db.close();
    } catch (e) {
      if (kDebugMode) debugPrint('CatalogDb.close: $e');
    }
  }
}
