namespace RongYokDownloader.Models;

/// <summary>How an episode's video is delivered — decides which download engine handles it.</summary>
public enum StreamKind
{
    /// <summary>A single progressive file (e.g. an .mp4 on a CDN) downloaded with an HTTP byte-range.</summary>
    Mp4Progressive = 0,

    /// <summary>An HLS playlist (.m3u8) — segments are fetched, joined and muxed to .mp4 with ffmpeg.</summary>
    Hls = 1,
}

/// <summary>
/// The result of resolving one episode to something downloadable. Sources return this instead of a
/// bare URL so the download engine knows whether it's a plain file or an HLS playlist, plus any
/// headers (Referer/UA) the CDN insists on.
/// </summary>
public sealed class StreamInfo
{
    public required StreamKind Kind { get; init; }

    /// <summary>The .mp4 URL (progressive) or the .m3u8 URL (HLS).</summary>
    public required string Url { get; init; }

    /// <summary>Referer some CDNs require (e.g. getplay-cdn checks the embedding domain).</summary>
    public string? Referer { get; init; }

    /// <summary>Optional User-Agent override for the media requests.</summary>
    public string? UserAgent { get; init; }
}
