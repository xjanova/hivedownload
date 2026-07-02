using RongYokDownloader.Models;

namespace RongYokDownloader.Services;

/// <summary>Holds the available <see cref="IMediaSource"/>s and resolves a series to its source.</summary>
public sealed class SourceRegistry
{
    private readonly Dictionary<string, IMediaSource> _byId;

    public SourceRegistry(IEnumerable<IMediaSource> sources)
    {
        _byId = sources.ToDictionary(s => s.SourceId, StringComparer.OrdinalIgnoreCase);
        All = _byId.Values.ToList();
        Default = _byId.TryGetValue(SourceIds.RongYok, out var r) ? r : All[0];
    }

    /// <summary>All sources, in registration order — used to build the source picker.</summary>
    public IReadOnlyList<IMediaSource> All { get; }

    /// <summary>The source shown first (rongyok).</summary>
    public IMediaSource Default { get; }

    /// <summary>Resolve a source id to its client, falling back to the default for unknown ids.</summary>
    public IMediaSource For(string? sourceId)
        => sourceId is not null && _byId.TryGetValue(sourceId, out var s) ? s : Default;

    /// <summary>Convenience: the source that owns a given series.</summary>
    public IMediaSource For(Series series) => For(series.SourceId);
}
