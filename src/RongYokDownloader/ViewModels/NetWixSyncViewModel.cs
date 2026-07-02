using System.Collections.ObjectModel;
using System.Windows;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using RongYokDownloader.Services;

namespace RongYokDownloader.ViewModels;

/// <summary>
/// The "NetWix Sync" tab: shows whether we're connected to NetWix and what it's asking us to
/// download, and lets the user start/stop the background mirror loop.
/// </summary>
public sealed partial class NetWixSyncViewModel : ObservableObject, IDisposable
{
    private readonly SettingsStore _settings;
    private readonly NetwixSyncEngine _engine;

    [ObservableProperty] private bool _isConnected;
    [ObservableProperty] private bool _isRunning;
    [ObservableProperty] private string _connectionLabel = "ยังไม่เชื่อมต่อ";
    [ObservableProperty] private string _statusText = "กด “เริ่มซิงค์” เพื่อเชื่อมต่อกับ NetWix";
    [ObservableProperty] private int _queueCount;

    [ObservableProperty] private string _netWixUrl;
    [ObservableProperty] private string _token;
    [ObservableProperty] private int _intervalSeconds;
    [ObservableProperty] private bool _autoStart;

    public ObservableCollection<string> Log { get; } = new();

    public NetWixSyncViewModel(SettingsStore settings)
    {
        _settings = settings;
        _netWixUrl = settings.NetWixUrl;
        _token = settings.NetWixToken;
        _intervalSeconds = settings.NetWixInterval;
        _autoStart = settings.NetWixAutoStart;

        _engine = new NetwixSyncEngine(settings);
        _engine.Log += AddLog;
        _engine.StatusChanged += s => OnUi(() => StatusText = s);
        _engine.QueueChanged += n => OnUi(() => QueueCount = n);
        _engine.ConnectionChanged += c => OnUi(() =>
        {
            IsConnected = c;
            ConnectionLabel = c ? "เชื่อมต่อ NetWix แล้ว" : "เชื่อมต่อไม่ได้";
        });

        if (settings.NetWixAutoStart && !string.IsNullOrWhiteSpace(settings.NetWixToken))
            Start();
    }

    private static void OnUi(Action a) => Application.Current?.Dispatcher.Invoke(a);

    private void AddLog(string m) => OnUi(() =>
    {
        Log.Insert(0, $"{DateTime.Now:HH:mm:ss}  {m}");
        while (Log.Count > 300) Log.RemoveAt(Log.Count - 1);
    });

    /// <summary>Write the current field values through to the settings DB (normalizing them).</summary>
    private void Persist()
    {
        _settings.NetWixUrl = (NetWixUrl ?? "").Trim();
        _settings.NetWixToken = (Token ?? "").Trim();
        _settings.NetWixInterval = IntervalSeconds;
        _settings.NetWixAutoStart = AutoStart;
    }

    [RelayCommand]
    private void Start()
    {
        Persist();
        _engine.Start();
        IsRunning = true;
        StatusText = "กำลังเชื่อมต่อ NetWix…";
        AddLog("▶ เริ่มซิงค์");
    }

    [RelayCommand]
    private void Stop()
    {
        _engine.Stop();
        IsRunning = false;
        IsConnected = false;
        ConnectionLabel = "หยุดแล้ว";
        AddLog("■ หยุดซิงค์แล้ว");
    }

    /// <summary>
    /// Save the connection settings and immediately verify them against NetWix, so the user gets
    /// clear feedback (the old Save was silent — you couldn't tell if it worked or if the token
    /// was even valid).
    /// </summary>
    [RelayCommand]
    private async Task SaveAsync()
    {
        try
        {
            Persist();
        }
        catch (Exception ex)
        {
            StatusText = "บันทึกไม่สำเร็จ: " + ex.Message;
            AddLog("✗ บันทึกไม่สำเร็จ: " + ex.Message);
            return;
        }

        // reflect the normalized (trimmed) values back so the UI shows exactly what was stored
        NetWixUrl = _settings.NetWixUrl;
        Token = _settings.NetWixToken;
        IntervalSeconds = _settings.NetWixInterval;

        AddLog("💾 บันทึกการตั้งค่าแล้ว");

        if (string.IsNullOrWhiteSpace(_settings.NetWixToken))
        {
            StatusText = "ยังไม่ได้ใส่ Ingest Token";
            AddLog("⚠ ยังไม่ได้ใส่ Ingest Token (ดูได้จากเซิร์ฟเวอร์: /home/admin/.netwix_ingest_token)");
            return;
        }

        StatusText = "กำลังทดสอบการเชื่อมต่อกับ NetWix…";
        AddLog("… กำลังทดสอบการเชื่อมต่อกับ NetWix");
        try
        {
            var (ok, message) = await _engine.TestConnectionAsync();
            StatusText = message;
            AddLog((ok ? "✓ " : "✗ ") + message);
        }
        catch (Exception ex)
        {
            StatusText = "ทดสอบไม่สำเร็จ: " + ex.Message;
            AddLog("✗ " + ex.Message);
        }
    }

    public void Dispose() => _engine.Dispose();
}
