using System.Collections.ObjectModel;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using RongYokDownloader.Data;
using RongYokDownloader.Models;
using RongYokDownloader.Services;

namespace RongYokDownloader.ViewModels;

/// <summary>A newly-discovered series row in the What's New dialog.</summary>
public sealed partial class NewSeriesItem : ObservableObject
{
    public required Series Series { get; init; }
    [ObservableProperty] private bool _queued;
}

/// <summary>A tracked series that gained episodes, in the What's New dialog.</summary>
public sealed partial class EpisodeUpdateItem : ObservableObject
{
    public required EpisodeUpdate Update { get; init; }
    [ObservableProperty] private bool _queued;

    public Series Series => Update.Series;
    public string Summary => $"+{Update.AddedCount} ตอนใหม่  (ตอนที่ {Update.OldCount + 1}–{Update.NewCount})";
}

/// <summary>
/// Presents the result of a scan: brand-new series and tracked series that gained
/// episodes, each with one-click download. Shown as a modal dialog after scanning.
/// </summary>
public sealed partial class WhatsNewViewModel : ObservableObject
{
    private readonly Db _db;
    private readonly RongYokClient _client;
    private readonly DownloadManager _downloads;
    private readonly Action<Series> _openDetail;

    public event Action? CloseRequested;

    public ObservableCollection<NewSeriesItem> NewSeries { get; } = new();
    public ObservableCollection<EpisodeUpdateItem> Updates { get; } = new();

    public bool HasNewSeries => NewSeries.Count > 0;
    public bool HasUpdates => Updates.Count > 0;
    public string Headline { get; }

    public WhatsNewViewModel(ScanResult result, Db db, RongYokClient client, DownloadManager downloads, Action<Series> openDetail)
    {
        _db = db;
        _client = client;
        _downloads = downloads;
        _openDetail = openDetail;

        foreach (var s in result.NewSeries)
            NewSeries.Add(new NewSeriesItem { Series = s });
        foreach (var u in result.EpisodeUpdates.OrderByDescending(u => u.AddedCount))
            Updates.Add(new EpisodeUpdateItem { Update = u });

        var parts = new List<string>();
        if (HasNewSeries) parts.Add($"ซีรี่ส์ใหม่ {NewSeries.Count} เรื่อง");
        if (HasUpdates) parts.Add($"ตอนใหม่ {Updates.Count} เรื่อง");
        Headline = parts.Count > 0 ? "พบ " + string.Join(" · ", parts) : "ไม่พบของใหม่";
    }

    /// <summary>Fetch a new series' episode list and queue the whole thing.</summary>
    [RelayCommand]
    private async Task DownloadSeries(NewSeriesItem? item)
    {
        if (item is null || item.Queued) return;
        try
        {
            var nums = await Task.Run(() => _client.FetchEpisodeNumbersAsync(item.Series.Id));
            if (nums.Count == 0) return;
            item.Series.EpisodesCount = nums.Count;
            _db.UpdateSeriesEpisodeCount(item.Series.Id, nums.Count);
            _db.UpsertEpisodePlaceholders(item.Series.Id, nums);
            _downloads.Enqueue(item.Series, nums);
            item.Queued = true;
        }
        catch { /* leave un-queued so the user can retry */ }
    }

    /// <summary>Queue just the newly-added episodes of a tracked series.</summary>
    [RelayCommand]
    private void DownloadNewEpisodes(EpisodeUpdateItem? item)
    {
        if (item is null || item.Queued) return;
        var s = item.Update.Series;
        s.EpisodesCount = item.Update.NewCount;
        _db.UpdateSeriesEpisodeCount(s.Id, item.Update.NewCount);
        _db.UpsertEpisodePlaceholders(s.Id, item.Update.NewEpisodeNumbers);
        _downloads.Enqueue(s, item.Update.NewEpisodeNumbers);
        item.Queued = true;
    }

    [RelayCommand]
    private void OpenSeries(Series? s)
    {
        if (s is null) return;
        _openDetail(s);
        CloseRequested?.Invoke();
    }

    [RelayCommand]
    private void Close() => CloseRequested?.Invoke();
}
