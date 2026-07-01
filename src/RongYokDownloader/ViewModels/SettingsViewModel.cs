using System.Diagnostics;
using System.IO;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using Microsoft.Win32;
using RongYokDownloader.Data;
using RongYokDownloader.Services;

namespace RongYokDownloader.ViewModels;

/// <summary>App settings: where files go, how many parallel downloads, extras.</summary>
public sealed partial class SettingsViewModel : ObservableObject
{
    private readonly SettingsStore _settings;
    private readonly Db _db;
    private bool _loading;

    [ObservableProperty] private string _downloadRoot = "";
    [ObservableProperty] private int _maxConcurrent = 3;
    [ObservableProperty] private bool _savePoster = true;
    [ObservableProperty] private bool _writeToc = true;

    public string DbPath => _db.DbPath;
    public int CatalogCount => _db.SeriesCount();

    public SettingsViewModel(SettingsStore settings, Db db)
    {
        _settings = settings;
        _db = db;
        _loading = true;
        DownloadRoot = _settings.DownloadRoot;
        MaxConcurrent = _settings.MaxConcurrentDownloads;
        SavePoster = _settings.SavePoster;
        WriteToc = _settings.WriteToc;
        _loading = false;
    }

    partial void OnDownloadRootChanged(string value) { if (!_loading && !string.IsNullOrWhiteSpace(value)) _settings.DownloadRoot = value; }
    partial void OnMaxConcurrentChanged(int value) { if (!_loading) _settings.MaxConcurrentDownloads = value; }
    partial void OnSavePosterChanged(bool value) { if (!_loading) _settings.SavePoster = value; }
    partial void OnWriteTocChanged(bool value) { if (!_loading) _settings.WriteToc = value; }

    [RelayCommand]
    private void BrowseFolder()
    {
        var dlg = new OpenFolderDialog
        {
            Title = "เลือกโฟลเดอร์สำหรับเก็บไฟล์ที่ดาวน์โหลด",
            InitialDirectory = Directory.Exists(DownloadRoot) ? DownloadRoot : "",
        };
        if (dlg.ShowDialog() == true)
            DownloadRoot = dlg.FolderName;
    }

    [RelayCommand]
    private void OpenDownloadFolder()
    {
        try
        {
            Directory.CreateDirectory(DownloadRoot);
            Process.Start(new ProcessStartInfo("explorer.exe", $"\"{DownloadRoot}\"") { UseShellExecute = true });
        }
        catch { /* ignore */ }
    }
}
