using System.Net.Http;
using RongYokDownloader.Models;

namespace RongYokDownloader.Services;

/// <summary>
/// A browsable/downloadable content site. Each implementation knows how to list its catalog,
/// enumerate a series' episodes and resolve one episode to a downloadable <see cref="StreamInfo"/>.
/// The rest of the app talks only to this interface, so adding a site = adding one class.
/// </summary>
public interface IMediaSource
{
    /// <summary>Stable id stored on every <see cref="Series"/> from this source — see <see cref="SourceIds"/>.</summary>
    string SourceId { get; }

    /// <summary>Human-facing name shown in the source picker (e.g. "โรงหยก").</summary>
    string DisplayName { get; }

    /// <summary>
    /// Download the site's full catalogue. Every returned <see cref="Series"/> has
    /// <see cref="Series.SourceId"/> set. <paramref name="progress"/> receives human-facing
    /// status lines (e.g. "…page 3/25") so slow multi-page fetches show movement.
    /// </summary>
    Task<List<Series>> FetchCatalogAsync(IProgress<string>? progress = null, CancellationToken ct = default);

    /// <summary>Return the episode numbers available for a series (and thus the count).</summary>
    Task<List<int>> FetchEpisodeNumbersAsync(Series series, CancellationToken ct = default);

    /// <summary>Resolve one episode to a fresh, downloadable stream. Null if unavailable.</summary>
    Task<StreamInfo?> ResolveEpisodeAsync(Series series, int episodeNumber, CancellationToken ct = default);

    /// <summary>
    /// Open an HTTP stream for a plain URL (a poster, or an <see cref="StreamKind.Mp4Progressive"/> video),
    /// honouring <paramref name="resumeFrom"/> as a byte-range offset for resuming.
    /// </summary>
    Task<HttpResponseMessage> GetStreamResponseAsync(string url, long resumeFrom, CancellationToken ct);
}
