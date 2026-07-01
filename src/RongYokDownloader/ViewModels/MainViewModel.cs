using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using RongYokDownloader.Data;
using RongYokDownloader.Models;
using RongYokDownloader.Services;

namespace RongYokDownloader.ViewModels;

/// <summary>
/// The application shell. Creates the shared services, owns the four main pages
/// (Catalog / Downloads / Library / Settings) and handles navigation, including the
/// on-demand Detail and Player pages.
/// </summary>
public sealed partial class MainViewModel : ObservableObject
{
    private readonly Db _db;
    private readonly RongYokClient _client;
    private readonly SettingsStore _settings;
    private readonly DownloadManager _downloads;

    private bool _navGuard;

    public CatalogViewModel Catalog { get; }
    public DownloadsViewModel DownloadsPage { get; }
    public LibraryViewModel Library { get; }
    public SettingsViewModel Settings { get; }

    [ObservableProperty] private object? _currentPage;
    [ObservableProperty] private int _selectedNavIndex;
    [ObservableProperty] private int _activeDownloads;
    [ObservableProperty] private bool _isScanning;
    [ObservableProperty] private string _scanStatus = "";

    /// <summary>Raised when a scan finds new content — the shell opens the What's New dialog.</summary>
    public event Action<WhatsNewViewModel>? ShowWhatsNewRequested;

    public MainViewModel(string dbPath)
    {
        _db = new Db(dbPath);
        _settings = new SettingsStore(_db);
        _client = new RongYokClient();
        _downloads = new DownloadManager(_client, _db, _settings);   // constructed on the UI thread
        _downloads.Changed += () => ActiveDownloads = _downloads.Jobs.Count(j => j.IsActive);

        Catalog = new CatalogViewModel(_db, _client);
        Catalog.OpenDetailRequested += OpenDetail;

        DownloadsPage = new DownloadsViewModel(_downloads);

        Library = new LibraryViewModel(_db, _settings);
        Library.PlayRequested += OpenPlayer;

        Settings = new SettingsViewModel(_settings, _db);

        ShowCatalog();
    }

    partial void OnSelectedNavIndexChanged(int value)
    {
        if (_navGuard) return;
        switch (value)
        {
            case 0: ShowCatalog(); break;
            case 1: ShowDownloads(); break;
            case 2: ShowLibrary(); break;
            case 3: ShowSettings(); break;
        }
    }

    private void SetNav(int index)
    {
        _navGuard = true;
        SelectedNavIndex = index;
        _navGuard = false;
    }

    [RelayCommand]
    private void ShowCatalog()
    {
        SetNav(0);
        CurrentPage = Catalog;
        _ = Catalog.LoadCommand.ExecuteAsync(null);
    }

    [RelayCommand]
    private void ShowDownloads()
    {
        SetNav(1);
        CurrentPage = DownloadsPage;
    }

    [RelayCommand]
    private void ShowLibrary()
    {
        SetNav(2);
        Library.LoadCommand.Execute(null);
        CurrentPage = Library;
    }

    [RelayCommand]
    private void ShowSettings()
    {
        SetNav(3);
        CurrentPage = Settings;
    }

    /// <summary>
    /// Scan the site for new content: (1) diff the full catalog against the DB to find
    /// brand-new series, and (2) re-check the episode count of every tracked/downloaded
    /// series to find new episodes. Opens the What's New dialog if anything turned up.
    /// </summary>
    [RelayCommand]
    private async Task ScanForNew()
    {
        if (IsScanning) return;
        try
        {
            IsScanning = true;
            ScanStatus = "กำลังดึงรายการล่าสุดจากเว็บ…";

            var known = _db.GetAllSeriesIds();
            var fresh = await Task.Run(() => _client.FetchCatalogAsync());

            var result = new ScanResult();
            result.NewSeries.AddRange(fresh.Where(s => !known.Contains(s.Id)).OrderByDescending(s => s.Id));

            _db.UpsertSeries(fresh);
            Catalog.ReloadFromDb();

            // Check tracked series for new episodes.
            var tracked = _db.GetTrackedSeries();
            for (int i = 0; i < tracked.Count; i++)
            {
                var s = tracked[i];
                ScanStatus = $"กำลังตรวจตอนใหม่ {i + 1}/{tracked.Count} — {s.CleanTitle}";
                try
                {
                    var nums = await Task.Run(() => _client.FetchEpisodeNumbersAsync(s.Id));
                    if (nums.Count > s.EpisodesCount && s.EpisodesCount > 0)
                    {
                        result.EpisodeUpdates.Add(new EpisodeUpdate { Series = s, OldCount = s.EpisodesCount, NewCount = nums.Count });
                        _db.UpdateSeriesEpisodeCount(s.Id, nums.Count);
                    }
                    else if (nums.Count > 0 && s.EpisodesCount == 0)
                    {
                        _db.UpdateSeriesEpisodeCount(s.Id, nums.Count);
                    }
                }
                catch { /* skip series that fail to load */ }
            }

            _settings.LastCatalogSync = DateTime.Now.ToString("yyyy-MM-dd HH:mm");

            if (result.IsEmpty)
            {
                ScanStatus = "สแกนเสร็จ — ยังไม่มีของใหม่ ✓";
            }
            else
            {
                ScanStatus = $"พบของใหม่: ซีรี่ส์ {result.NewSeries.Count} · ตอนใหม่ {result.EpisodeUpdates.Count} เรื่อง";
                var whatsNew = new WhatsNewViewModel(result, _db, _client, _downloads, OpenDetail);
                ShowWhatsNewRequested?.Invoke(whatsNew);
            }
        }
        catch (Exception ex)
        {
            ScanStatus = "สแกนไม่สำเร็จ: " + ex.Message;
        }
        finally
        {
            IsScanning = false;
        }
    }

    private void OpenDetail(Series s)
    {
        var vm = new SeriesDetailViewModel(s, _db, _client, _downloads, _settings);
        vm.BackRequested += ShowCatalog;
        vm.GoToDownloadsRequested += ShowDownloads;
        vm.WatchEpisodeRequested += ep => OpenPlayerAt(s, ep, stream: true);
        SetNav(0);
        CurrentPage = vm;
        _ = vm.LoadCommand.ExecuteAsync(null);
    }

    /// <summary>Open the player for a series pointed straight at one episode (double-click-to-watch).</summary>
    private void OpenPlayerAt(Series s, int episodeNumber, bool stream)
    {
        var vm = new PlayerViewModel(s, _db, _settings, _downloads, _client);
        vm.BackRequested += () => OpenDetail(s);   // "back" returns to the series detail
        SetNav(0);
        CurrentPage = vm;
        vm.StartAt(episodeNumber, stream);
        vm.LoadCommand.Execute(null);
    }

    private void OpenPlayer(Series s)
    {
        var vm = new PlayerViewModel(s, _db, _settings, _downloads, _client);
        vm.BackRequested += ShowLibrary;
        SetNav(2);
        CurrentPage = vm;
        vm.LoadCommand.Execute(null);
    }
}
