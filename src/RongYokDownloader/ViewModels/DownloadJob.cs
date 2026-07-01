using CommunityToolkit.Mvvm.ComponentModel;
using RongYokDownloader.Models;
using RongYokDownloader.Services;

namespace RongYokDownloader.ViewModels;

/// <summary>
/// One row in the download queue: a single episode, its live progress and controls' state.
/// It is an <see cref="ObservableObject"/> so the UI updates as bytes arrive.
/// </summary>
public sealed partial class DownloadJob : ObservableObject
{
    public required Series Series { get; init; }
    public required int EpisodeNumber { get; init; }

    /// <summary>Final destination path (the .mp4). The engine downloads to "&lt;path&gt;.part" first.</summary>
    public required string FilePath { get; init; }

    public string SeriesTitle => string.IsNullOrWhiteSpace(Series.CleanTitle) ? Series.Title : Series.CleanTitle;
    public string EpisodeLabel => $"ตอนที่ {EpisodeNumber}";

    [ObservableProperty]
    [NotifyPropertyChangedFor(nameof(StatusText))]
    [NotifyPropertyChangedFor(nameof(IsActive))]
    [NotifyPropertyChangedFor(nameof(CanPause))]
    [NotifyPropertyChangedFor(nameof(CanResume))]
    private DownloadStatus _status = DownloadStatus.Queued;

    [ObservableProperty]
    [NotifyPropertyChangedFor(nameof(PercentText))]
    private double _progress; // 0..1

    [ObservableProperty]
    [NotifyPropertyChangedFor(nameof(SizeText))]
    private long _downloadedBytes;

    [ObservableProperty]
    [NotifyPropertyChangedFor(nameof(SizeText))]
    private long _totalBytes;

    [ObservableProperty]
    [NotifyPropertyChangedFor(nameof(SpeedText))]
    private double _speedBytesPerSec;

    [ObservableProperty]
    private string? _error;

    // ---- derived, display-only ----

    public string PercentText => Format.Percent(Progress);

    public string SizeText => TotalBytes > 0
        ? $"{Format.Bytes(DownloadedBytes)} / {Format.Bytes(TotalBytes)}"
        : Format.Bytes(DownloadedBytes);

    public string SpeedText => Status == DownloadStatus.Downloading ? Format.Speed(SpeedBytesPerSec) : "";

    public bool IsActive => Status is DownloadStatus.Downloading or DownloadStatus.Queued;
    public bool CanPause => Status is DownloadStatus.Downloading or DownloadStatus.Queued;
    public bool CanResume => Status is DownloadStatus.Paused or DownloadStatus.Failed;

    public string StatusText => Status switch
    {
        DownloadStatus.Queued => "รอในคิว",
        DownloadStatus.Downloading => "กำลังโหลด",
        DownloadStatus.Paused => "หยุดชั่วคราว",
        DownloadStatus.Completed => "เสร็จแล้ว",
        DownloadStatus.Failed => "ล้มเหลว",
        _ => "",
    };
}
