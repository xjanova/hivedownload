using System.IO;
using RongYokDownloader.Data;

namespace RongYokDownloader.Services;

/// <summary>Small typed wrapper over the <c>settings</c> table.</summary>
public sealed class SettingsStore
{
    private readonly Db _db;
    public SettingsStore(Db db) => _db = db;

    public string DownloadRoot
    {
        get
        {
            var v = _db.GetSetting("download_root");
            if (!string.IsNullOrWhiteSpace(v)) return v;
            var def = Path.Combine(
                Environment.GetFolderPath(Environment.SpecialFolder.MyVideos), "RongYok");
            return def;
        }
        set => _db.SetSetting("download_root", value);
    }

    public int MaxConcurrentDownloads
    {
        get => int.TryParse(_db.GetSetting("max_concurrent"), out var n) && n >= 1 && n <= 8 ? n : 3;
        set => _db.SetSetting("max_concurrent", Math.Clamp(value, 1, 8).ToString());
    }

    /// <summary>Also save the .jpg cover next to the episodes.</summary>
    public bool SavePoster
    {
        get => _db.GetSetting("save_poster") is not "0";
        set => _db.SetSetting("save_poster", value ? "1" : "0");
    }

    /// <summary>Write a per-series index.html table of contents.</summary>
    public bool WriteToc
    {
        get => _db.GetSetting("write_toc") is not "0";
        set => _db.SetSetting("write_toc", value ? "1" : "0");
    }

    public string? LastCatalogSync
    {
        get => _db.GetSetting("last_catalog_sync");
        set => _db.SetSetting("last_catalog_sync", value ?? "");
    }

    /// <summary>Player: auto-download upcoming episodes while watching.</summary>
    public bool PrefetchAhead
    {
        get => _db.GetSetting("prefetch_ahead") is "1";
        set => _db.SetSetting("prefetch_ahead", value ? "1" : "0");
    }

    /// <summary>How many episodes ahead to prefetch.</summary>
    public int PrefetchCount
    {
        get => int.TryParse(_db.GetSetting("prefetch_count"), out var n) && n is >= 1 and <= 10 ? n : 3;
        set => _db.SetSetting("prefetch_count", Math.Clamp(value, 1, 10).ToString());
    }

    /// <summary>Player: stream episodes straight from the source instead of saving them.</summary>
    public bool StreamMode
    {
        get => _db.GetSetting("stream_mode") is "1";
        set => _db.SetSetting("stream_mode", value ? "1" : "0");
    }

    // ── NetWix Sync (mirror rongyok episodes into the netwix.online streaming site) ──

    public string NetWixUrl
    {
        get { var v = _db.GetSetting("netwix_url"); return string.IsNullOrWhiteSpace(v) ? "https://netwix.online" : v; }
        set => _db.SetSetting("netwix_url", (value ?? "").Trim());
    }

    public string NetWixToken
    {
        get => _db.GetSetting("netwix_token") ?? "";
        set => _db.SetSetting("netwix_token", (value ?? "").Trim());
    }

    public int NetWixInterval
    {
        get => int.TryParse(_db.GetSetting("netwix_interval"), out var n) && n >= 15 ? n : 60;
        set => _db.SetSetting("netwix_interval", Math.Max(15, value).ToString());
    }

    /// <summary>Start NetWix sync automatically when the app opens.</summary>
    public bool NetWixAutoStart
    {
        get => _db.GetSetting("netwix_autostart") is "1";
        set => _db.SetSetting("netwix_autostart", value ? "1" : "0");
    }
}
