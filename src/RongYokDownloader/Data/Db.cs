using System.IO;
using Dapper;
using Microsoft.Data.Sqlite;
using RongYokDownloader.Models;

namespace RongYokDownloader.Data;

/// <summary>
/// Thin SQLite persistence layer (Dapper over Microsoft.Data.Sqlite).
/// One database file holds the whole catalog, per-episode download state and app settings.
/// A fresh connection is opened per operation — cheap for SQLite and avoids threading headaches.
/// </summary>
public sealed class Db
{
    public string DbPath { get; }
    private readonly string _connString;

    public Db(string dbPath)
    {
        DbPath = dbPath;
        Directory.CreateDirectory(Path.GetDirectoryName(dbPath)!);
        _connString = new SqliteConnectionStringBuilder
        {
            DataSource = dbPath,
            Mode = SqliteOpenMode.ReadWriteCreate,
            Cache = SqliteCacheMode.Shared,
        }.ToString();
        Initialize();
    }

    private SqliteConnection Open()
    {
        var c = new SqliteConnection(_connString);
        c.Open();
        // WAL keeps reads snappy while a download thread writes progress.
        c.Execute("PRAGMA journal_mode=WAL; PRAGMA synchronous=NORMAL; PRAGMA foreign_keys=ON;");
        return c;
    }

    private void Initialize()
    {
        using var c = Open();
        c.Execute("""
            CREATE TABLE IF NOT EXISTS series (
                id              INTEGER PRIMARY KEY,
                source_id       TEXT NOT NULL DEFAULT 'rongyok',
                slug            TEXT NOT NULL DEFAULT '',
                title           TEXT NOT NULL DEFAULT '',
                clean_title     TEXT NOT NULL DEFAULT '',
                description     TEXT NOT NULL DEFAULT '',
                type            INTEGER NOT NULL DEFAULT 0,
                poster_url      TEXT NOT NULL DEFAULT '',
                jpg_url         TEXT NOT NULL DEFAULT '',
                poster_local    TEXT,
                view_count      INTEGER NOT NULL DEFAULT 0,
                created_at      TEXT NOT NULL DEFAULT '',
                episodes_count  INTEGER NOT NULL DEFAULT 0,
                year            INTEGER
            );

            CREATE TABLE IF NOT EXISTS episodes (
                id               INTEGER PRIMARY KEY AUTOINCREMENT,
                series_id        INTEGER NOT NULL,
                episode_number   INTEGER NOT NULL,
                status           INTEGER NOT NULL DEFAULT 0,
                file_path        TEXT,
                downloaded_bytes INTEGER NOT NULL DEFAULT 0,
                total_bytes      INTEGER NOT NULL DEFAULT 0,
                downloaded_at    TEXT,
                error            TEXT,
                UNIQUE(series_id, episode_number)
            );

            CREATE TABLE IF NOT EXISTS settings (
                key   TEXT PRIMARY KEY,
                value TEXT
            );

            CREATE INDEX IF NOT EXISTS ix_episodes_series ON episodes(series_id);
            """);

        // Migrate databases created before multi-source support: add the new series columns
        // (existing rows keep the 'rongyok' default) so old installs upgrade seamlessly.
        MigrateAddColumn(c, "series", "source_id", "TEXT NOT NULL DEFAULT 'rongyok'");
        MigrateAddColumn(c, "series", "slug", "TEXT NOT NULL DEFAULT ''");
        c.Execute("CREATE INDEX IF NOT EXISTS ix_series_source ON series(source_id);");
    }

    /// <summary>Adds a column only if it isn't already there (SQLite has no ADD COLUMN IF NOT EXISTS).</summary>
    private static void MigrateAddColumn(SqliteConnection c, string table, string column, string decl)
    {
        var cols = c.Query<string>($"SELECT name FROM pragma_table_info('{table}');")
                    .ToHashSet(StringComparer.OrdinalIgnoreCase);
        if (!cols.Contains(column))
            c.Execute($"ALTER TABLE {table} ADD COLUMN {column} {decl};");
    }

    // ---------------------------------------------------------------- series

    public void UpsertSeries(IEnumerable<Series> items)
    {
        using var c = Open();
        using var tx = c.BeginTransaction();
        const string sql = """
            INSERT INTO series (id,source_id,slug,title,clean_title,description,type,poster_url,jpg_url,view_count,created_at,episodes_count,year)
            VALUES (@Id,@SourceId,@Slug,@Title,@CleanTitle,@Description,@Type,@PosterUrl,@JpgUrl,@ViewCount,@CreatedAt,@EpisodesCount,@Year)
            ON CONFLICT(id) DO UPDATE SET
                source_id=excluded.source_id,
                slug=CASE WHEN excluded.slug<>'' THEN excluded.slug ELSE series.slug END,
                title=excluded.title,
                clean_title=excluded.clean_title,
                description=CASE WHEN excluded.description<>'' THEN excluded.description ELSE series.description END,
                type=excluded.type,
                poster_url=excluded.poster_url,
                jpg_url=excluded.jpg_url,
                view_count=excluded.view_count,
                created_at=excluded.created_at,
                episodes_count=CASE WHEN excluded.episodes_count>0 THEN excluded.episodes_count ELSE series.episodes_count END,
                year=COALESCE(excluded.year, series.year);
            """;
        foreach (var s in items)
        {
            c.Execute(sql, new
            {
                s.Id, s.SourceId, s.Slug, s.Title, s.CleanTitle, s.Description, Type = (int)s.Type,
                s.PosterUrl, s.JpgUrl, s.ViewCount, s.CreatedAt, s.EpisodesCount, s.Year
            }, tx);
        }
        tx.Commit();
    }

    public void UpdateSeriesEpisodeCount(int seriesId, int count)
    {
        using var c = Open();
        c.Execute("UPDATE series SET episodes_count=@count WHERE id=@id AND @count>0;", new { id = seriesId, count });
    }

    public void UpdateSeriesPosterLocal(int seriesId, string path)
    {
        using var c = Open();
        c.Execute("UPDATE series SET poster_local=@path WHERE id=@id;", new { id = seriesId, path });
    }

    private const string SeriesColumns =
        "id,source_id AS SourceId,slug AS Slug,title,clean_title AS CleanTitle,description,type," +
        "poster_url AS PosterUrl,jpg_url AS JpgUrl,poster_local AS PosterLocalPath," +
        "view_count AS ViewCount,created_at AS CreatedAt,episodes_count AS EpisodesCount,year";

    public List<Series> GetAllSeries()
    {
        using var c = Open();
        return c.Query<Series>($"SELECT {SeriesColumns} FROM series ORDER BY id DESC;").ToList();
    }

    /// <summary>All series for one source only (the catalog shows one source at a time).</summary>
    public List<Series> GetAllSeries(string sourceId)
    {
        using var c = Open();
        return c.Query<Series>(
            $"SELECT {SeriesColumns} FROM series WHERE source_id=@sourceId ORDER BY id DESC;",
            new { sourceId }).ToList();
    }

    public int SeriesCount()
    {
        using var c = Open();
        return c.ExecuteScalar<int>("SELECT COUNT(*) FROM series;");
    }

    // -------------------------------------------------------------- episodes

    public void UpsertEpisodePlaceholders(int seriesId, IEnumerable<int> episodeNumbers)
    {
        using var c = Open();
        using var tx = c.BeginTransaction();
        foreach (var n in episodeNumbers)
        {
            c.Execute(
                "INSERT OR IGNORE INTO episodes (series_id,episode_number,status) VALUES (@s,@n,0);",
                new { s = seriesId, n }, tx);
        }
        tx.Commit();
    }

    public List<Episode> GetEpisodes(int seriesId)
    {
        using var c = Open();
        return c.Query<Episode>(
            "SELECT id,series_id AS SeriesId,episode_number AS EpisodeNumber,status,file_path AS FilePath,downloaded_bytes AS DownloadedBytes,total_bytes AS TotalBytes,downloaded_at AS DownloadedAt,error FROM episodes WHERE series_id=@s ORDER BY episode_number;",
            new { s = seriesId }).ToList();
    }

    public Episode? GetEpisode(int seriesId, int ep)
    {
        using var c = Open();
        return c.QueryFirstOrDefault<Episode>(
            "SELECT id,series_id AS SeriesId,episode_number AS EpisodeNumber,status,file_path AS FilePath,downloaded_bytes AS DownloadedBytes,total_bytes AS TotalBytes,downloaded_at AS DownloadedAt,error FROM episodes WHERE series_id=@s AND episode_number=@ep;",
            new { s = seriesId, ep });
    }

    public void SaveEpisode(Episode e)
    {
        using var c = Open();
        c.Execute("""
            INSERT INTO episodes (series_id,episode_number,status,file_path,downloaded_bytes,total_bytes,downloaded_at,error)
            VALUES (@SeriesId,@EpisodeNumber,@Status,@FilePath,@DownloadedBytes,@TotalBytes,@DownloadedAt,@Error)
            ON CONFLICT(series_id,episode_number) DO UPDATE SET
                status=excluded.status,
                file_path=excluded.file_path,
                downloaded_bytes=excluded.downloaded_bytes,
                total_bytes=excluded.total_bytes,
                downloaded_at=excluded.downloaded_at,
                error=excluded.error;
            """, new
        {
            e.SeriesId, e.EpisodeNumber, Status = (int)e.Status, e.FilePath,
            e.DownloadedBytes, e.TotalBytes, e.DownloadedAt, e.Error
        });
    }

    /// <summary>Series that have at least one completed episode — the "Library".</summary>
    public List<Series> GetLibrarySeries()
    {
        using var c = Open();
        return c.Query<Series>("""
            SELECT s.id,s.source_id AS SourceId,s.slug AS Slug,s.title,s.clean_title AS CleanTitle,s.description,s.type,
                   s.poster_url AS PosterUrl,s.jpg_url AS JpgUrl,s.poster_local AS PosterLocalPath,
                   s.view_count AS ViewCount,s.created_at AS CreatedAt,s.episodes_count AS EpisodesCount,s.year
            FROM series s
            WHERE EXISTS (SELECT 1 FROM episodes e WHERE e.series_id=s.id AND e.status=4)
            ORDER BY s.clean_title;
            """).ToList();
    }

    public int CompletedEpisodeCount(int seriesId)
    {
        using var c = Open();
        return c.ExecuteScalar<int>("SELECT COUNT(*) FROM episodes WHERE series_id=@s AND status=4;", new { s = seriesId });
    }

    /// <summary>
    /// Series the user has shown interest in — anything whose episode list has been
    /// loaded (episodes_count &gt; 0) or that has downloaded episodes. These are the
    /// series worth checking for NEW episodes during a scan.
    /// </summary>
    public List<Series> GetTrackedSeries()
    {
        using var c = Open();
        return c.Query<Series>($"""
            SELECT {SeriesColumns}
            FROM series
            WHERE episodes_count > 0
               OR id IN (SELECT DISTINCT series_id FROM episodes)
            ORDER BY id DESC;
            """).ToList();
    }

    public HashSet<int> GetAllSeriesIds()
    {
        using var c = Open();
        return c.Query<int>("SELECT id FROM series;").ToHashSet();
    }

    /// <summary>Known series ids for one source — used to spot brand-new series during a scan.</summary>
    public HashSet<int> GetAllSeriesIds(string sourceId)
    {
        using var c = Open();
        return c.Query<int>("SELECT id FROM series WHERE source_id=@sourceId;", new { sourceId }).ToHashSet();
    }

    /// <summary>Tracked series (episode list loaded or has downloads) for a single source.</summary>
    public List<Series> GetTrackedSeries(string sourceId)
        => GetTrackedSeries().Where(s => s.SourceId == sourceId).ToList();

    // -------------------------------------------------------------- settings

    public string? GetSetting(string key)
    {
        using var c = Open();
        return c.QueryFirstOrDefault<string>("SELECT value FROM settings WHERE key=@key;", new { key });
    }

    public void SetSetting(string key, string value)
    {
        using var c = Open();
        c.Execute("INSERT INTO settings (key,value) VALUES (@key,@value) ON CONFLICT(key) DO UPDATE SET value=excluded.value;",
            new { key, value });
    }
}
