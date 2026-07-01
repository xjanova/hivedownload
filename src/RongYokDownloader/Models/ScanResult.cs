namespace RongYokDownloader.Models;

/// <summary>Outcome of a "scan for new content" pass.</summary>
public sealed class ScanResult
{
    /// <summary>Series that appeared on the site but weren't in our database yet.</summary>
    public List<Series> NewSeries { get; } = new();

    /// <summary>Tracked series that gained episodes since we last saw them.</summary>
    public List<EpisodeUpdate> EpisodeUpdates { get; } = new();

    public bool IsEmpty => NewSeries.Count == 0 && EpisodeUpdates.Count == 0;
    public int TotalNew => NewSeries.Count + EpisodeUpdates.Count;
}

/// <summary>A tracked series whose episode count grew.</summary>
public sealed class EpisodeUpdate
{
    public required Series Series { get; init; }
    public int OldCount { get; init; }
    public int NewCount { get; init; }
    public int AddedCount => Math.Max(0, NewCount - OldCount);

    /// <summary>Episode numbers that are new (OldCount+1 .. NewCount).</summary>
    public IEnumerable<int> NewEpisodeNumbers => Enumerable.Range(OldCount + 1, AddedCount);
}
