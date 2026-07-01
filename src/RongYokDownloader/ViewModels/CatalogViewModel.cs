using System.Collections.ObjectModel;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using RongYokDownloader.Data;
using RongYokDownloader.Models;
using RongYokDownloader.Services;

namespace RongYokDownloader.ViewModels;

/// <summary>The catalog browser: search, filter and page through every series on the site.</summary>
public sealed partial class CatalogViewModel : ObservableObject
{
    private const int PageSize = 48;

    private readonly Db _db;
    private readonly RongYokClient _client;

    private List<Series> _all = new();
    private List<Series> _filtered = new();
    private int _shown;

    /// <summary>Raised when the user opens a series — the shell swaps to the detail page.</summary>
    public event Action<Series>? OpenDetailRequested;

    public ObservableCollection<Series> Items { get; } = new();

    [ObservableProperty] private bool _isBusy;
    [ObservableProperty] private string _statusMessage = "";
    [ObservableProperty] private string _resultSummary = "";

    [ObservableProperty]
    [NotifyPropertyChangedFor(nameof(CanLoadMore))]
    private bool _hasMore;

    public bool CanLoadMore => HasMore && !IsBusy;
    public bool IsNotBusy => !IsBusy;

    // filters ------------------------------------------------------------

    [ObservableProperty] private string _searchText = "";
    partial void OnSearchTextChanged(string value) => ApplyFilter();

    /// <summary>0 = ทั้งหมด, 1 = พากย์ไทย, 2 = ซับไทย</summary>
    [ObservableProperty] private int _typeFilterIndex;
    partial void OnTypeFilterIndexChanged(int value) => ApplyFilter();

    /// <summary>0 = ล่าสุด, 1 = ยอดนิยม, 2 = ชื่อเรื่อง</summary>
    [ObservableProperty] private int _sortIndex;
    partial void OnSortIndexChanged(int value) => ApplyFilter();

    public CatalogViewModel(Db db, RongYokClient client)
    {
        _db = db;
        _client = client;
    }

    /// <summary>Called the first time the page is shown.</summary>
    [RelayCommand]
    public async Task LoadAsync()
    {
        if (_all.Count > 0) return;                 // already loaded this session
        _all = _db.GetAllSeries();
        if (_all.Count == 0)
            await RefreshAsync();                   // cold start → pull from the site
        else
        {
            ApplyFilter();
            StatusMessage = $"โหลดจากฐานข้อมูล {_all.Count} เรื่อง";
        }
    }

    /// <summary>Re-fetch the whole catalog from rongyok.com and cache it in SQLite.</summary>
    [RelayCommand]
    public async Task RefreshAsync()
    {
        if (IsBusy) return;
        try
        {
            IsBusy = true;
            StatusMessage = "กำลังดึงรายการซีรี่ส์จากเว็บ…";
            var list = await Task.Run(() => _client.FetchCatalogAsync());
            _db.UpsertSeries(list);
            _all = _db.GetAllSeries();
            ApplyFilter();
            StatusMessage = $"อัปเดตแล้ว {_all.Count} เรื่อง";
        }
        catch (Exception ex)
        {
            StatusMessage = "ดึงข้อมูลไม่สำเร็จ: " + ex.Message;
        }
        finally
        {
            IsBusy = false;
        }
    }

    /// <summary>Re-read the catalog from SQLite (after a scan added new series) and refresh the grid.</summary>
    public void ReloadFromDb()
    {
        _all = _db.GetAllSeries();
        ApplyFilter();
    }

    [RelayCommand]
    private void LoadMore()
    {
        _shown = Math.Min(_shown + PageSize, _filtered.Count);
        SyncItems();
    }

    [RelayCommand]
    private void OpenDetail(Series? s)
    {
        if (s is not null) OpenDetailRequested?.Invoke(s);
    }

    // -------------------------------------------------------------- internal

    private void ApplyFilter()
    {
        IEnumerable<Series> q = _all;

        string term = SearchText.Trim();
        if (term.Length > 0)
            q = q.Where(s =>
                s.CleanTitle.Contains(term, StringComparison.OrdinalIgnoreCase) ||
                s.Title.Contains(term, StringComparison.OrdinalIgnoreCase));

        q = TypeFilterIndex switch
        {
            1 => q.Where(s => s.Type == DubType.ThaiDub),
            2 => q.Where(s => s.Type == DubType.ThaiSub),
            _ => q,
        };

        q = SortIndex switch
        {
            1 => q.OrderByDescending(s => s.ViewCount),
            2 => q.OrderBy(s => s.CleanTitle, StringComparer.Ordinal),
            _ => q.OrderByDescending(s => s.Id),
        };

        _filtered = q.ToList();
        _shown = Math.Min(PageSize, _filtered.Count);
        SyncItems();
        ResultSummary = $"แสดง {Items.Count} จาก {_filtered.Count} เรื่อง";
    }

    private void SyncItems()
    {
        Items.Clear();
        for (int i = 0; i < _shown && i < _filtered.Count; i++)
            Items.Add(_filtered[i]);
        HasMore = _shown < _filtered.Count;
        ResultSummary = $"แสดง {Items.Count} จาก {_filtered.Count} เรื่อง";
    }

    partial void OnIsBusyChanged(bool value)
    {
        OnPropertyChanged(nameof(CanLoadMore));
        OnPropertyChanged(nameof(IsNotBusy));
    }
}
