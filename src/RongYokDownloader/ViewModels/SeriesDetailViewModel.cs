using System.Collections.ObjectModel;
using System.IO;
using System.Threading;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using RongYokDownloader.Data;
using RongYokDownloader.Models;
using RongYokDownloader.Services;

namespace RongYokDownloader.ViewModels;

/// <summary>A single selectable episode row on the detail page.</summary>
public sealed partial class EpisodeSelectItem : ObservableObject
{
    public int EpisodeNumber { get; init; }

    [ObservableProperty] private bool _isSelected;
    [ObservableProperty] private DownloadStatus _status;

    public string Label => $"ตอนที่ {EpisodeNumber}";
    public bool IsDownloaded => Status == DownloadStatus.Completed;
}

/// <summary>Detail view for one series: shows info and lets the user pick episodes to download.</summary>
public sealed partial class SeriesDetailViewModel : ObservableObject
{
    private readonly Db _db;
    private readonly IMediaSource _source;
    private readonly DownloadManager _downloads;
    private readonly SettingsStore _settings;

    public event Action? BackRequested;
    public event Action? GoToDownloadsRequested;

    /// <summary>Raised when the user double-clicks an episode to watch it now (episode number).</summary>
    public event Action<int>? WatchEpisodeRequested;

    [ObservableProperty] private Series _series;
    [ObservableProperty] private bool _isBusy;
    [ObservableProperty] private string _statusMessage = "";

    public ObservableCollection<EpisodeSelectItem> Episodes { get; } = new();

    public int SelectedCount => Episodes.Count(e => e.IsSelected);
    public bool HasEpisodes => Episodes.Count > 0;

    public SeriesDetailViewModel(Series series, Db db, IMediaSource source, DownloadManager downloads, SettingsStore settings)
    {
        _series = series;
        _db = db;
        _source = source;
        _downloads = downloads;
        _settings = settings;
    }

    [RelayCommand]
    public async Task LoadAsync()
    {
        try
        {
            IsBusy = true;
            StatusMessage = "กำลังโหลดรายชื่อตอน…";

            var numbers = await Task.Run(() => _source.FetchEpisodeNumbersAsync(Series));
            if (numbers.Count == 0)
            {
                StatusMessage = "ไม่พบตอนสำหรับเรื่องนี้";
                return;
            }

            Series.EpisodesCount = numbers.Count;
            _db.UpdateSeriesEpisodeCount(Series.Id, numbers.Count);
            _db.UpsertEpisodePlaceholders(Series.Id, numbers);

            var statusByEp = _db.GetEpisodes(Series.Id)
                                .ToDictionary(e => e.EpisodeNumber, e => e.Status);

            Episodes.Clear();
            foreach (int n in numbers)
            {
                var item = new EpisodeSelectItem
                {
                    EpisodeNumber = n,
                    Status = statusByEp.TryGetValue(n, out var st) ? st : DownloadStatus.None,
                };
                item.PropertyChanged += (_, e) =>
                {
                    if (e.PropertyName == nameof(EpisodeSelectItem.IsSelected))
                        OnPropertyChanged(nameof(SelectedCount));
                };
                Episodes.Add(item);
            }

            OnPropertyChanged(nameof(HasEpisodes));
            OnPropertyChanged(nameof(SelectedCount));
            StatusMessage = $"{numbers.Count} ตอน";
        }
        catch (Exception ex)
        {
            StatusMessage = "โหลดตอนไม่สำเร็จ: " + ex.Message;
        }
        finally
        {
            IsBusy = false;
        }
    }

    [RelayCommand] private void SelectAll() { foreach (var e in Episodes) e.IsSelected = true; }
    [RelayCommand] private void SelectNone() { foreach (var e in Episodes) e.IsSelected = false; }
    [RelayCommand] private void InvertSelection() { foreach (var e in Episodes) e.IsSelected = !e.IsSelected; }

    /// <summary>Select every episode that isn't already downloaded.</summary>
    [RelayCommand]
    private void SelectRemaining()
    {
        foreach (var e in Episodes) e.IsSelected = !e.IsDownloaded;
    }

    [RelayCommand]
    private void DownloadSelected()
    {
        var picks = Episodes.Where(e => e.IsSelected).Select(e => e.EpisodeNumber).ToList();
        if (picks.Count == 0)
        {
            StatusMessage = "ยังไม่ได้เลือกตอน";
            return;
        }
        _downloads.Enqueue(Series, picks);
        StatusMessage = $"เพิ่ม {picks.Count} ตอนเข้าคิวแล้ว";
        GoToDownloadsRequested?.Invoke();
    }

    [RelayCommand]
    private void DownloadAll()
    {
        _downloads.Enqueue(Series, Episodes.Select(e => e.EpisodeNumber));
        StatusMessage = $"เพิ่มทั้งหมด {Episodes.Count} ตอนเข้าคิวแล้ว";
        GoToDownloadsRequested?.Invoke();
    }

    /// <summary>Double-click an episode → open the player and stream it right away.</summary>
    [RelayCommand]
    private void WatchEpisode(EpisodeSelectItem? item)
    {
        if (item is not null) WatchEpisodeRequested?.Invoke(item.EpisodeNumber);
    }

    /// <summary>
    /// Ensure episode 1 is available on disk (for a smooth, buffer-free looping background preview)
    /// and return its local path. Reuses a normally-downloaded copy if present, otherwise downloads
    /// it once into a small preview cache. Null if it couldn't be fetched.
    /// </summary>
    public async Task<string?> EnsurePreviewFileAsync(CancellationToken ct = default)
    {
        try
        {
            // 1) already downloaded normally? reuse it.
            var normalPath = FileNamer.EpisodePath(_settings.DownloadRoot, Series, 1);
            if (File.Exists(normalPath)) return normalPath;

            // 2) preview cache
            var cacheDir = Path.Combine(
                Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
                "RongYokDownloader", "preview");
            Directory.CreateDirectory(cacheDir);
            var cachePath = Path.Combine(cacheDir, $"{Series.Id}_ep1.mp4");
            if (File.Exists(cachePath) && new FileInfo(cachePath).Length > 200_000) return cachePath;

            // 3) download episode 1 once — only for plain-file sources; HLS previews aren't worth it
            var stream = await _source.ResolveEpisodeAsync(Series, 1, ct);
            if (stream is null || stream.Kind != StreamKind.Mp4Progressive || string.IsNullOrEmpty(stream.Url))
                return null;

            var part = cachePath + ".part";
            using (var resp = await _source.GetStreamResponseAsync(stream.Url, 0, ct))
            {
                resp.EnsureSuccessStatusCode();
                await using var fs = new FileStream(part, FileMode.Create, FileAccess.Write, FileShare.None, 1 << 16, useAsync: true);
                await resp.Content.CopyToAsync(fs, ct);
            }
            if (File.Exists(cachePath)) File.Delete(cachePath);
            File.Move(part, cachePath);

            TrimPreviewCache(cacheDir, keep: 12);
            return cachePath;
        }
        catch
        {
            return null;
        }
    }

    /// <summary>Keep only the newest N cached preview clips so the cache doesn't grow forever.</summary>
    private static void TrimPreviewCache(string dir, int keep)
    {
        try
        {
            foreach (var f in new DirectoryInfo(dir).GetFiles("*.mp4")
                         .OrderByDescending(f => f.LastWriteTimeUtc).Skip(keep))
            {
                try { f.Delete(); } catch { /* ignore */ }
            }
        }
        catch { /* ignore */ }
    }

    [RelayCommand] private void Back() => BackRequested?.Invoke();
}
