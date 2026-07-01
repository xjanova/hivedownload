using System.ComponentModel;
using System.IO;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;
using System.Windows.Media.Animation;
using System.Windows.Threading;
using RongYokDownloader.ViewModels;

namespace RongYokDownloader.Views;

public partial class PlayerView : UserControl
{
    private readonly DispatcherTimer _timer;
    private readonly DispatcherTimer _hideTimer;
    private PlayerViewModel? _vm;
    private bool _isPlaying;
    private bool _suppressSeek;
    private bool _wantPlay;   // we intend to be playing (used to re-assert Play on MediaOpened)
    private bool _controlsVisible = true;
    private bool _autoAdvancing;   // the next episode is starting via continuous auto-advance

    // Segoe MDL2 glyphs: Play = E768, Pause = E769
    private const string PlayGlyph = "";
    private const string PauseGlyph = "";

    public PlayerView()
    {
        InitializeComponent();
        _timer = new DispatcherTimer { Interval = TimeSpan.FromMilliseconds(250) };
        _timer.Tick += Timer_Tick;

        _hideTimer = new DispatcherTimer { Interval = TimeSpan.FromSeconds(2.5) };
        _hideTimer.Tick += (_, _) => HideControls();

        DataContextChanged += OnDataContextChanged;
        Loaded += OnViewLoaded;
        Seek.ValueChanged += Seek_ValueChanged;
        Unloaded += (_, _) => TearDown();
    }

    private void OnDataContextChanged(object sender, DependencyPropertyChangedEventArgs e)
    {
        if (_vm is not null)
        {
            _vm.PropertyChanged -= Vm_PropertyChanged;
            _vm.WaitingEpisodeFailed -= OnWaitingEpisodeFailed;
        }
        _vm = DataContext as PlayerViewModel;
        if (_vm is not null)
        {
            _vm.PropertyChanged += Vm_PropertyChanged;
            _vm.WaitingEpisodeFailed += OnWaitingEpisodeFailed;
            // Defer the first play until the view is actually in the visual tree (see OnViewLoaded).
            // Calling MediaElement.Play() before that is the classic "first video is a frozen frame" bug.
            if (IsLoaded) LoadCurrent();
        }
    }

    private void OnViewLoaded(object sender, RoutedEventArgs e)
    {
        if (_vm is not null) LoadCurrent();
    }

    // ---- auto-hide transport controls (don't cover the video while watching) ----

    private void Video_MouseMove(object sender, MouseEventArgs e) => ShowControls();

    private void ShowControls()
    {
        if (!_controlsVisible)
        {
            _controlsVisible = true;
            ControlsBar.IsHitTestVisible = true;
            ControlsBar.BeginAnimation(OpacityProperty, new DoubleAnimation(1, TimeSpan.FromMilliseconds(120)));
            VideoArea.Cursor = Cursors.Arrow;
        }
        _hideTimer.Stop();
        if (_isPlaying) _hideTimer.Start();   // only auto-hide while actually playing
    }

    private void HideControls()
    {
        _hideTimer.Stop();
        if (!_isPlaying) return;              // keep visible when paused / stopped / empty
        _controlsVisible = false;
        ControlsBar.BeginAnimation(OpacityProperty, new DoubleAnimation(0, TimeSpan.FromMilliseconds(350)));
        ControlsBar.IsHitTestVisible = false;
        VideoArea.Cursor = Cursors.None;
    }

    private void PlaylistItem_PreviewDown(object sender, MouseButtonEventArgs e)
    {
        if (e.ClickCount == 2 && sender is FrameworkElement fe && fe.DataContext is PlayerEpisode ep)
        {
            e.Handled = true;
            _vm?.StreamEpisodeNowCommand.Execute(ep);
        }
    }

    private void OnWaitingEpisodeFailed(int episodeNumber)
    {
        EmptyHint.Text = $"โหลดตอนที่ {episodeNumber} ไม่สำเร็จ — แตะที่ตอนเพื่อลองอีกครั้ง";
        EmptyHint.Visibility = Visibility.Visible;
    }

    private void Vm_PropertyChanged(object? sender, PropertyChangedEventArgs e)
    {
        if (e.PropertyName == nameof(PlayerViewModel.CurrentFilePath))
            LoadCurrent();
    }

    private void LoadCurrent()
    {
        // If this load is a continuous auto-advance, keep the controls in their current state
        // (usually hidden) instead of popping them up for every new episode.
        bool auto = _autoAdvancing;
        _autoAdvancing = false;

        // CurrentFilePath is either a local file (download mode) or an http(s) URL (stream mode).
        string? src = _vm?.CurrentFilePath;
        bool isHttp = src is not null && src.StartsWith("http", StringComparison.OrdinalIgnoreCase);
        if (string.IsNullOrEmpty(src) || (!isHttp && !File.Exists(src)))
        {
            EmptyHint.Visibility = Visibility.Visible;
            return;
        }

        EmptyHint.Visibility = Visibility.Collapsed;
        Media.Volume = Vol.Value;
        Media.Stop();
        Media.Source = new Uri(src);
        _wantPlay = true;
        Media.Play();
        _isPlaying = true;
        PlayPauseBtn.Content = PauseGlyph;
        _timer.Start();
        if (!auto) ShowControls();   // continuous auto-advance → leave controls hidden
        else if (_isPlaying) _hideTimer.Start();
    }

    private void Timer_Tick(object? sender, EventArgs e)
    {
        if (Media.Source is null || !Media.NaturalDuration.HasTimeSpan) return;
        _suppressSeek = true;
        Seek.Value = Media.Position.TotalSeconds;
        _suppressSeek = false;
        CurTime.Text = Fmt(Media.Position);
    }

    private void Media_MediaOpened(object sender, RoutedEventArgs e)
    {
        if (Media.NaturalDuration.HasTimeSpan)
        {
            Seek.Maximum = Media.NaturalDuration.TimeSpan.TotalSeconds;
            DurTime.Text = Fmt(Media.NaturalDuration.TimeSpan);
        }
        // Re-assert playback now that the media surface is ready — fixes the frozen first frame.
        if (_wantPlay) Media.Play();
    }

    private void Media_MediaEnded(object sender, RoutedEventArgs e)
    {
        // Auto-advance strictly in order — always the very next episode, never skipping a gap.
        var vm = _vm;
        var next = vm?.NextEpisode;
        if (vm is null || next is null)
        {
            // End of the series.
            Media.Stop();
            _isPlaying = false;
            PlayPauseBtn.Content = PlayGlyph;
            _timer.Stop();
            return;
        }

        if (vm.StreamMode || next.IsPlayable)
        {
            _autoAdvancing = true;                    // continuous watch → don't pop the controls back up
            vm.NextCommand.Execute(null);             // streaming, or already downloaded → seamless
        }
        else
        {
            // Next episode isn't downloaded yet: stop, show a waiting hint, queue it.
            // It auto-plays the moment the download finishes (see PlayerViewModel.OnEpisodeCompleted).
            Media.Stop();
            _isPlaying = false;
            PlayPauseBtn.Content = PlayGlyph;
            _timer.Stop();
            EmptyHint.Text = $"กำลังโหลดตอนที่ {next.EpisodeNumber} เพื่อเล่นต่อ…";
            EmptyHint.Visibility = Visibility.Visible;
            vm.PlayEpisodeCommand.Execute(next);
        }
    }

    private void Media_MediaFailed(object sender, ExceptionRoutedEventArgs e)
    {
        _timer.Stop();
        EmptyHint.Text = "เล่นไฟล์ไม่ได้ — Windows อาจไม่มีตัวถอดรหัส H.264/HEVC\n(ลองติดตั้ง 'HEVC Video Extensions' หรือเปิดไฟล์ด้วย VLC)";
        EmptyHint.Visibility = Visibility.Visible;
    }

    private void PlayPause_Click(object sender, RoutedEventArgs e)
    {
        if (Media.Source is null) return;
        if (_isPlaying) { Media.Pause(); PlayPauseBtn.Content = PlayGlyph; _wantPlay = false; }
        else { Media.Play(); PlayPauseBtn.Content = PauseGlyph; _wantPlay = true; }
        _isPlaying = !_isPlaying;
        ShowControls();
    }

    private void Stop_Click(object sender, RoutedEventArgs e)
    {
        Media.Stop();
        _isPlaying = false;
        _wantPlay = false;
        PlayPauseBtn.Content = PlayGlyph;
        Seek.Value = 0;
        CurTime.Text = "0:00";
        ShowControls();
    }

    private void Seek_ValueChanged(object sender, RoutedPropertyChangedEventArgs<double> e)
    {
        if (_suppressSeek || Media.Source is null) return;
        Media.Position = TimeSpan.FromSeconds(e.NewValue);
    }

    private void Vol_ValueChanged(object sender, RoutedPropertyChangedEventArgs<double> e)
    {
        if (Media is not null) Media.Volume = e.NewValue;
    }

    private void ToggleTheater_Click(object sender, RoutedEventArgs e)
    {
        bool showing = Sidebar.Visibility == Visibility.Visible;
        Sidebar.Visibility = showing ? Visibility.Collapsed : Visibility.Visible;
        TheaterBtn.Content = showing ? "แสดงรายการตอน" : "โรงหนัง";
    }

    private void TearDown()
    {
        _timer.Stop();
        _hideTimer.Stop();
        try { Media.Stop(); Media.Close(); } catch { /* ignore */ }
        if (_vm is not null)
        {
            _vm.PropertyChanged -= Vm_PropertyChanged;
            _vm.WaitingEpisodeFailed -= OnWaitingEpisodeFailed;
            _vm.Detach();
        }
    }

    private static string Fmt(TimeSpan t)
        => t.TotalHours >= 1 ? $"{(int)t.TotalHours}:{t.Minutes:00}:{t.Seconds:00}" : $"{t.Minutes}:{t.Seconds:00}";
}
