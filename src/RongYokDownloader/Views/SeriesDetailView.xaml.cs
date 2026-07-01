using System.IO;
using System.Threading;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;
using System.Windows.Media;
using System.Windows.Media.Animation;
using System.Windows.Media.Effects;
using RongYokDownloader.ViewModels;

namespace RongYokDownloader.Views;

public partial class SeriesDetailView : UserControl
{
    private SeriesDetailViewModel? _vm;
    private CancellationTokenSource? _cts;
    private bool _stopped;
    private const double BgMainOpacity = 0.96;   // crisp centred video
    private const double BgBlurOpacity = 0.42;   // soft ambient backdrop

    public SeriesDetailView()
    {
        InitializeComponent();
        DataContextChanged += (_, _) => _vm = DataContext as SeriesDetailViewModel;
        Loaded += OnLoaded;
        Unloaded += OnUnloaded;
    }

    // ---- background preview: episode 1, pre-downloaded, looping, with sound ----

    private async void OnLoaded(object sender, RoutedEventArgs e)
    {
        _stopped = false;
        _cts?.Cancel();
        _cts = new CancellationTokenSource();
        var ct = _cts.Token;
        if (_vm is null) return;

        try
        {
            PrepHint.Visibility = Visibility.Visible;

            // Episode list is fetched asynchronously by the VM — wait until we know it exists.
            for (int i = 0; i < 25 && _vm.Series.EpisodesCount <= 0 && !ct.IsCancellationRequested; i++)
                await Task.Delay(400, ct);

            // Make sure EP.1 is on disk (downloads it once), then play the local file — no buffering.
            var path = await _vm.EnsurePreviewFileAsync(ct);
            if (_stopped || ct.IsCancellationRequested || string.IsNullOrEmpty(path) || !File.Exists(path))
            {
                PrepHint.Visibility = Visibility.Collapsed;
                return;
            }

            var uri = new Uri(path);
            BgA.Volume = 0.8;
            BgA.Position = TimeSpan.Zero;
            BgA.Source = uri;
            BgA.Play();       // crisp centred layer (with sound) — MediaOpened → fade in + hide hint

            BgBlur.Volume = 0;
            BgBlur.Position = TimeSpan.Zero;
            BgBlur.Source = uri;   // same clip, blurred backdrop (muted)
            BgBlur.Play();
        }
        catch (OperationCanceledException) { /* navigated away */ }
        catch { PrepHint.Visibility = Visibility.Collapsed; }
    }

    // Even feather on every edge: a blurred, inset rounded-white rectangle used as an OpacityMask,
    // rebuilt in code so it is always sized to the video (ElementName bindings don't work inside a
    // VisualBrush.Visual, which is why the XAML radial/visual-brush approaches looked wrong).
    private void BgA_SizeChanged(object sender, SizeChangedEventArgs e) => UpdateFeatherMask();

    private void UpdateFeatherMask()
    {
        double w = BgA.ActualWidth, h = BgA.ActualHeight;
        if (w < 8 || h < 8) return;

        var shape = new Border
        {
            Margin = new Thickness(34),
            Background = Brushes.White,
            CornerRadius = new CornerRadius(26),
            Effect = new BlurEffect { Radius = 34, KernelType = KernelType.Gaussian, RenderingBias = RenderingBias.Performance },
        };
        var host = new Grid { Width = w, Height = h };
        host.Children.Add(shape);

        var size = new Size(w, h);
        host.Measure(size);
        host.Arrange(new Rect(size));
        host.UpdateLayout();

        BgA.OpacityMask = new VisualBrush(host) { Stretch = Stretch.None, AlignmentX = AlignmentX.Center, AlignmentY = AlignmentY.Center };
    }

    private void Bg_MediaOpened(object sender, RoutedEventArgs e)
    {
        if (_stopped) return;
        PrepHint.Visibility = Visibility.Collapsed;
        UpdateFeatherMask();
        // Re-assert Play once the media surface is ready — fixes the frozen first frame.
        BgA.Play();
        BgBlur.Play();
        // smooth fade-in, like the original preview
        BgA.BeginAnimation(OpacityProperty, new DoubleAnimation(BgMainOpacity, TimeSpan.FromMilliseconds(1100)));
        BgBlur.BeginAnimation(OpacityProperty, new DoubleAnimation(BgBlurOpacity, TimeSpan.FromMilliseconds(1100)));
    }

    private void Bg_MediaEnded(object sender, RoutedEventArgs e)
    {
        if (_stopped) return;
        // loop both layers together
        BgA.Position = TimeSpan.Zero; BgA.Play();
        BgBlur.Position = TimeSpan.Zero; BgBlur.Play();
        // soft dip-fade at the loop point so it doesn't hard-cut
        BgA.BeginAnimation(OpacityProperty, new DoubleAnimation(0.15, BgMainOpacity, TimeSpan.FromMilliseconds(1100)));
        BgBlur.BeginAnimation(OpacityProperty, new DoubleAnimation(0.08, BgBlurOpacity, TimeSpan.FromMilliseconds(1100)));
    }

    private void Bg_MediaFailed(object sender, ExceptionRoutedEventArgs e)
        => PrepHint.Visibility = Visibility.Collapsed;

    private void OnUnloaded(object sender, RoutedEventArgs e)
    {
        _stopped = true;
        _cts?.Cancel();
        try { BgA.Stop(); BgA.Close(); } catch { /* ignore */ }
        try { BgBlur.Stop(); BgBlur.Close(); } catch { /* ignore */ }
    }

    // ---- double-click an episode chip → open the player and stream it -----

    // MouseDoubleClick doesn't fire reliably on ButtonBase (it consumes mouse-down),
    // so detect the double-click ourselves in the tunnelling preview event.
    private void Episode_PreviewDown(object sender, MouseButtonEventArgs e)
    {
        if (e.ClickCount == 2 &&
            DataContext is SeriesDetailViewModel vm &&
            sender is FrameworkElement fe && fe.DataContext is EpisodeSelectItem item)
        {
            e.Handled = true;
            vm.WatchEpisodeCommand.Execute(item);
        }
    }
}
