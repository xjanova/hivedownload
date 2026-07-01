using System.IO;
using System.Windows;
using System.Windows.Media;
using System.Windows.Media.Animation;
using System.Windows.Threading;
using RongYokDownloader.ViewModels;
using RongYokDownloader.Views;

namespace RongYokDownloader;

public partial class App : Application
{
    protected override void OnStartup(StartupEventArgs e)
    {
        base.OnStartup(e);

        // Surface unhandled errors instead of silently dying.
        DispatcherUnhandledException += OnUnhandledException;

        string dataDir = Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
            "RongYokDownloader");
        Directory.CreateDirectory(dataDir);
        string dbPath = Path.Combine(dataDir, "rongyok.db");

        InstallRgbBrush();   // mutable animated brush, referenced via DynamicResource

        var mainVm = new MainViewModel(dbPath);
        var window = new MainWindow { DataContext = mainVm };
        window.Show();
    }

    /// <summary>
    /// Build the RGB rainbow brush in code (kept mutable so it can be animated) and install it as
    /// an Application resource. Templates reference it via DynamicResource — unlike a StaticResource
    /// inside a ControlTemplate, which WPF FREEZES (that froze the shared brush and made the rotate
    /// animation throw "Cannot animate ... because the object is sealed or frozen"). The transform
    /// then rotates forever so every element using the brush cycles through the spectrum.
    /// </summary>
    private void InstallRgbBrush()
    {
        var brush = new LinearGradientBrush
        {
            StartPoint = new System.Windows.Point(0, 0),
            EndPoint = new System.Windows.Point(1, 1),
            SpreadMethod = GradientSpreadMethod.Repeat,
        };
        void Stop(byte r, byte g, byte b, double o) => brush.GradientStops.Add(new GradientStop(Color.FromRgb(r, g, b), o));
        Stop(0xFF, 0x3B, 0x5C, 0.0);
        Stop(0xFF, 0x9F, 0x0A, 0.143);
        Stop(0xFF, 0xD6, 0x0A, 0.286);
        Stop(0x30, 0xD1, 0x58, 0.429);
        Stop(0x22, 0xD3, 0xEE, 0.571);
        Stop(0x5E, 0x9C, 0xFF, 0.714);
        Stop(0xBF, 0x5A, 0xF2, 0.857);
        Stop(0xFF, 0x3B, 0x5C, 1.0);

        var rt = new RotateTransform(0) { CenterX = 0.5, CenterY = 0.5 };
        brush.RelativeTransform = rt;

        var anim = new DoubleAnimation(0, 360, new Duration(TimeSpan.FromSeconds(8)))
        {
            RepeatBehavior = RepeatBehavior.Forever,
        };
        rt.BeginAnimation(RotateTransform.AngleProperty, anim);

        Resources["RgbBrush"] = brush;   // Application-level key wins over the merged Theme.xaml fallback
    }

    private void OnUnhandledException(object sender, DispatcherUnhandledExceptionEventArgs e)
    {
        MessageBox.Show(
            "เกิดข้อผิดพลาด: " + e.Exception.Message,
            "RongYok Downloader",
            MessageBoxButton.OK, MessageBoxImage.Warning);
        e.Handled = true;
    }
}
