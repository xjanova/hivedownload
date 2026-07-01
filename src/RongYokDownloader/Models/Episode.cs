namespace RongYokDownloader.Models;

/// <summary>One episode of a series and its local download state.</summary>
public sealed class Episode
{
    public long Id { get; set; }              // local DB primary key (autoincrement)
    public int SeriesId { get; set; }
    public int EpisodeNumber { get; set; }

    public DownloadStatus Status { get; set; } = DownloadStatus.None;

    /// <summary>Local absolute file path once (partly) downloaded.</summary>
    public string? FilePath { get; set; }

    /// <summary>Bytes already on disk.</summary>
    public long DownloadedBytes { get; set; }

    /// <summary>Total size in bytes as reported by the CDN (Content-Length).</summary>
    public long TotalBytes { get; set; }

    public string? DownloadedAt { get; set; }

    public string? Error { get; set; }
}
