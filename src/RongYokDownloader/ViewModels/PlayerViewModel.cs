using System.Collections.ObjectModel;
using System.IO;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using RongYokDownloader.Data;
using RongYokDownloader.Models;
using RongYokDownloader.Services;

namespace RongYokDownloader.ViewModels;

/// <summary>One entry in the player's episode sidebar.</summary>
public sealed partial class PlayerEpisode : ObservableObject
{
    public int EpisodeNumber { get; init; }

    [ObservableProperty] private string? _filePath;
    [ObservableProperty] private bool _isPlayable;   // file exists on disk
    [ObservableProperty] private bool _isBusy;        // queued / downloading
    [ObservableProperty] private bool _isCurrent;

    public string Label => $"ตอนที่ {EpisodeNumber}";
}

/// <summary>
/// Drives the built-in player. Owns the playlist and current selection; the actual
/// <c>MediaElement</c> transport lives in the view code-behind, which watches
/// <see cref="CurrentFilePath"/>.
///
/// New: clicking an episode that isn't downloaded queues it immediately (auto-plays when
/// ready), and an optional "prefetch" mode downloads upcoming episodes ahead while you watch.
/// </summary>
public sealed partial class PlayerViewModel : ObservableObject
{
    private readonly Db _db;
    private readonly SettingsStore _settings;
    private readonly DownloadManager _downloads;
    private readonly IMediaSource _source;

    private int _autoPlayEp;   // episode the user tapped to download; auto-play it once ready
    private int _startEpisode; // when opened for a specific episode (0 = default first)
    private bool _startStream; // stream that starting episode rather than requiring a local file

    public event Action? BackRequested;

    /// <summary>Raised when the episode we were waiting to auto-play failed to download.</summary>
    public event Action<int>? WaitingEpisodeFailed;

    [ObservableProperty] private Series _series;

    [ObservableProperty]
    [NotifyPropertyChangedFor(nameof(CurrentTitle))]
    private string? _currentFilePath;

    [ObservableProperty] private int _currentEpisodeNumber;

    /// <summary>When on, watching episode N quietly downloads the next few episodes.</summary>
    [ObservableProperty] private bool _prefetch;

    /// <summary>When on, play episodes straight from the source (no file saved to disk).</summary>
    [ObservableProperty] private bool _streamMode;

    public ObservableCollection<PlayerEpisode> Episodes { get; } = new();

    public string CurrentTitle => CurrentEpisodeNumber > 0
        ? $"{Title} — ตอนที่ {CurrentEpisodeNumber}"
        : Title;

    private string Title => string.IsNullOrWhiteSpace(Series.CleanTitle) ? Series.Title : Series.CleanTitle;

    public PlayerViewModel(Series series, Db db, SettingsStore settings, DownloadManager downloads, IMediaSource source)
    {
        _series = series;
        _db = db;
        _settings = settings;
        _downloads = downloads;
        _source = source;
        _prefetch = _settings.PrefetchAhead;
        _streamMode = _settings.StreamMode;
        _downloads.EpisodeCompleted += OnEpisodeCompleted;
        _downloads.EpisodeFailed += OnEpisodeFailed;
    }

    partial void OnPrefetchChanged(bool value)
    {
        _settings.PrefetchAhead = value;
        if (value && CurrentEpisodeNumber > 0) PrefetchAhead();
    }

    partial void OnStreamModeChanged(bool value) => _settings.StreamMode = value;

    /// <summary>Open the player already pointed at a specific episode (optionally streaming it). Call before Load().</summary>
    public void StartAt(int episodeNumber, bool stream)
    {
        _startEpisode = episodeNumber;
        _startStream = stream;
    }

    [RelayCommand]
    public void Load()
    {
        Episodes.Clear();
        var root = _settings.DownloadRoot;

        // Full 1..N list so the user can tap any episode (downloaded ones play, others download).
        int count = Series.EpisodesCount;
        var numbers = count > 0
            ? Enumerable.Range(1, count)
            : _db.GetEpisodes(Series.Id).Select(e => e.EpisodeNumber).OrderBy(n => n);

        foreach (int n in numbers)
        {
            string path = FileNamer.EpisodePath(root, Series, n);
            Episodes.Add(new PlayerEpisode
            {
                EpisodeNumber = n,
                FilePath = path,
                IsPlayable = File.Exists(path),
            });
        }

        // Opened for a specific episode (e.g. double-clicked from the detail page) → go straight to it.
        if (_startEpisode > 0)
        {
            var target = Episodes.FirstOrDefault(e => e.EpisodeNumber == _startEpisode);
            if (target is not null)
            {
                if (_startStream) StreamEpisodeNow(target);
                else PlayEpisode(target);
                return;
            }
        }

        // Stream mode: start the first episode straight from the source.
        // Otherwise start the earliest episode that's already downloaded.
        var start = StreamMode ? Episodes.FirstOrDefault() : Episodes.FirstOrDefault(x => x.IsPlayable);
        if (start is not null) PlayEpisode(start);
    }

    [RelayCommand]
    public void PlayEpisode(PlayerEpisode? ep)
    {
        if (ep is null) return;

        if (StreamMode)
        {
            _ = StreamEpisodeAsync(ep);   // play directly from the CDN, no download
            return;
        }

        if (ep.IsPlayable)
        {
            foreach (var e in Episodes) e.IsCurrent = ReferenceEquals(e, ep);
            CurrentEpisodeNumber = ep.EpisodeNumber;
            CurrentFilePath = ep.FilePath;
            if (Prefetch) PrefetchAhead();
        }
        else
        {
            // Not downloaded yet → make sure it's downloading (unless a prefetch already started it),
            // and remember to auto-play it the moment it lands.
            if (!ep.IsBusy) StartDownload(ep);
            _autoPlayEp = ep.EpisodeNumber;
        }
    }

    /// <summary>Double-click a playlist row → stream it right now, whatever the toggles say.</summary>
    [RelayCommand]
    public void StreamEpisodeNow(PlayerEpisode? ep)
    {
        if (ep is not null) _ = StreamEpisodeAsync(ep);
    }

    private void StartDownload(PlayerEpisode ep)
    {
        ep.IsBusy = true;
        _downloads.Enqueue(Series, new[] { ep.EpisodeNumber });
    }

    /// <summary>Resolve the source URL for an episode and play it directly (no file saved).</summary>
    private async Task StreamEpisodeAsync(PlayerEpisode ep)
    {
        try
        {
            var stream = await _source.ResolveEpisodeAsync(Series, ep.EpisodeNumber);

            // WPF's MediaElement can't play HLS — for those sources fall back to
            // download-then-autoplay (the finished .mp4 is playable).
            if (stream is null || stream.Kind != StreamKind.Mp4Progressive || string.IsNullOrEmpty(stream.Url))
            {
                if (!ep.IsBusy) StartDownload(ep);
                _autoPlayEp = ep.EpisodeNumber;
                return;
            }

            foreach (var e in Episodes) e.IsCurrent = ReferenceEquals(e, ep);
            CurrentEpisodeNumber = ep.EpisodeNumber;
            CurrentFilePath = stream.Url;   // http URL — the view streams it via MediaElement
        }
        catch
        {
            WaitingEpisodeFailed?.Invoke(ep.EpisodeNumber);
        }
    }

    /// <summary>Queue the next few not-yet-downloaded episodes after the current one.</summary>
    private void PrefetchAhead()
    {
        int want = _settings.PrefetchCount;
        var upcoming = Episodes
            .Where(e => e.EpisodeNumber > CurrentEpisodeNumber && !e.IsPlayable && !e.IsBusy)
            .Take(want)
            .ToList();
        if (upcoming.Count == 0) return;
        foreach (var e in upcoming) e.IsBusy = true;
        _downloads.Enqueue(Series, upcoming.Select(e => e.EpisodeNumber));
    }

    private void OnEpisodeCompleted(int seriesId, int episodeNumber)
    {
        if (seriesId != Series.Id) return;
        var pe = Episodes.FirstOrDefault(e => e.EpisodeNumber == episodeNumber);
        if (pe is null) return;

        pe.IsBusy = false;
        pe.FilePath = FileNamer.EpisodePath(_settings.DownloadRoot, Series, episodeNumber);
        pe.IsPlayable = File.Exists(pe.FilePath);

        // If the user tapped this episode to watch it, switch to it now that it's here
        // (only an explicit tap sets _autoPlayEp — prefetched episodes stay in the background).
        if (_autoPlayEp == episodeNumber && pe.IsPlayable)
        {
            _autoPlayEp = 0;
            PlayEpisode(pe);
        }
    }

    /// <summary>The episode immediately after the current one (whether or not it's downloaded).</summary>
    public PlayerEpisode? NextEpisode => Episodes.FirstOrDefault(e => e.EpisodeNumber == CurrentEpisodeNumber + 1);

    /// <summary>
    /// Go to the very next episode in order — never skip a gap. If it isn't downloaded yet,
    /// PlayEpisode queues it and it auto-plays once ready.
    /// </summary>
    private void OnEpisodeFailed(int seriesId, int episodeNumber)
    {
        if (seriesId != Series.Id) return;
        var pe = Episodes.FirstOrDefault(e => e.EpisodeNumber == episodeNumber);
        if (pe is not null) pe.IsBusy = false;
        if (_autoPlayEp == episodeNumber)
        {
            _autoPlayEp = 0;
            WaitingEpisodeFailed?.Invoke(episodeNumber);   // let the view surface it
        }
    }

    [RelayCommand]
    public void Next()
    {
        var next = Episodes.FirstOrDefault(e => e.EpisodeNumber == CurrentEpisodeNumber + 1);
        if (next is not null) PlayEpisode(next);
    }

    [RelayCommand]
    public void Previous()
    {
        var prev = Episodes.FirstOrDefault(e => e.EpisodeNumber == CurrentEpisodeNumber - 1);
        if (prev is not null) PlayEpisode(prev);
    }

    [RelayCommand] private void Back() => BackRequested?.Invoke();

    /// <summary>Unhook from the download manager — call when leaving the player.</summary>
    public void Detach()
    {
        _downloads.EpisodeCompleted -= OnEpisodeCompleted;
        _downloads.EpisodeFailed -= OnEpisodeFailed;
    }
}
