using System.Collections.ObjectModel;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using RongYokDownloader.Models;
using RongYokDownloader.Services;

namespace RongYokDownloader.ViewModels;

/// <summary>The download queue page — thin presentation over <see cref="DownloadManager"/>.</summary>
public sealed partial class DownloadsViewModel : ObservableObject
{
    private readonly DownloadManager _downloads;

    public ObservableCollection<DownloadJob> Jobs => _downloads.Jobs;

    [ObservableProperty] private string _summary = "";

    public DownloadsViewModel(DownloadManager downloads)
    {
        _downloads = downloads;
        _downloads.Changed += UpdateSummary;
        _downloads.Jobs.CollectionChanged += (_, _) => UpdateSummary();
        UpdateSummary();
    }

    public int ActiveCount => Jobs.Count(j => j.IsActive);

    private void UpdateSummary()
    {
        int active = Jobs.Count(j => j.Status is DownloadStatus.Downloading);
        int queued = Jobs.Count(j => j.Status is DownloadStatus.Queued);
        int done = Jobs.Count(j => j.Status is DownloadStatus.Completed);
        int failed = Jobs.Count(j => j.Status is DownloadStatus.Failed);
        Summary = $"กำลังโหลด {active} · รอคิว {queued} · เสร็จ {done}" + (failed > 0 ? $" · ล้มเหลว {failed}" : "");
        OnPropertyChanged(nameof(ActiveCount));
    }

    [RelayCommand] private void Pause(DownloadJob job) => _downloads.Pause(job);
    [RelayCommand] private void Resume(DownloadJob job) => _downloads.Resume(job);
    [RelayCommand] private void Remove(DownloadJob job) => _downloads.Remove(job);

    [RelayCommand] private void PauseAll() => _downloads.PauseAll();
    [RelayCommand] private void ResumeAll() => _downloads.ResumeAll();
    [RelayCommand] private void ClearCompleted() => _downloads.ClearCompleted();
}
