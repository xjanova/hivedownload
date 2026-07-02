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
        _engine.Log += m => OnUi(() =>
        {
            Log.Insert(0, $"{DateTime.Now:HH:mm:ss}  {m}");
            while (Log.Count > 300) Log.RemoveAt(Log.Count - 1);
        });
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

    [RelayCommand]
    private void Start()
    {
        Save();
        _engine.Start();
        IsRunning = true;
        StatusText = "กำลังเชื่อมต่อ NetWix…";
    }

    [RelayCommand]
    private void Stop()
    {
        _engine.Stop();
        IsRunning = false;
        IsConnected = false;
        ConnectionLabel = "หยุดแล้ว";
    }

    [RelayCommand]
    private void Save()
    {
        _settings.NetWixUrl = (NetWixUrl ?? "").Trim();
        _settings.NetWixToken = (Token ?? "").Trim();
        _settings.NetWixInterval = IntervalSeconds;
        _settings.NetWixAutoStart = AutoStart;
    }

    public void Dispose() => _engine.Dispose();
}
