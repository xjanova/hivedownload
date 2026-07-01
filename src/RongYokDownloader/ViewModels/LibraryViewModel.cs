using System.Collections.ObjectModel;
using System.Diagnostics;
using System.IO;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using RongYokDownloader.Data;
using RongYokDownloader.Models;
using RongYokDownloader.Services;

namespace RongYokDownloader.ViewModels;

/// <summary>"คลังของฉัน" — series with at least one downloaded episode.</summary>
public sealed partial class LibraryViewModel : ObservableObject
{
    private readonly Db _db;
    private readonly SettingsStore _settings;

    public event Action<Series>? PlayRequested;

    public ObservableCollection<Series> Items { get; } = new();

    [ObservableProperty] private string _statusMessage = "";
    [ObservableProperty] private bool _isEmpty = true;

    public LibraryViewModel(Db db, SettingsStore settings)
    {
        _db = db;
        _settings = settings;
    }

    [RelayCommand]
    public void Load()
    {
        Items.Clear();
        foreach (var s in _db.GetLibrarySeries())
        {
            int done = _db.CompletedEpisodeCount(s.Id);
            s.EpisodesCount = Math.Max(s.EpisodesCount, done);
            // prefer a local cover if we saved one
            var folder = FileNamer.SeriesFolder(_settings.DownloadRoot, s);
            var poster = Path.Combine(folder, "poster.jpg");
            if (File.Exists(poster)) s.PosterLocalPath = poster;
            Items.Add(s);
        }
        IsEmpty = Items.Count == 0;
        StatusMessage = IsEmpty
            ? "ยังไม่มีเรื่องที่ดาวน์โหลด — ไปที่ 'คลังซีรี่ส์' เพื่อเริ่มโหลด"
            : $"{Items.Count} เรื่องในคลัง";
    }

    [RelayCommand] private void Play(Series? s) { if (s is not null) PlayRequested?.Invoke(s); }

    [RelayCommand]
    private void OpenFolder(Series? s)
    {
        if (s is null) return;
        var folder = FileNamer.SeriesFolder(_settings.DownloadRoot, s);
        if (Directory.Exists(folder))
            Process.Start(new ProcessStartInfo("explorer.exe", $"\"{folder}\"") { UseShellExecute = true });
    }

    [RelayCommand]
    private void OpenToc(Series? s)
    {
        if (s is null) return;
        var toc = Path.Combine(FileNamer.SeriesFolder(_settings.DownloadRoot, s), "index.html");
        if (File.Exists(toc))
            Process.Start(new ProcessStartInfo(toc) { UseShellExecute = true });
    }
}
