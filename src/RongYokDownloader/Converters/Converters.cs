using System.Collections.Concurrent;
using System.Globalization;
using System.IO;
using System.Windows;
using System.Windows.Data;
using System.Windows.Media;
using System.Windows.Media.Imaging;
using RongYokDownloader.Models;

namespace RongYokDownloader.Converters;

/// <summary>
/// Turns an image URL/path string into a decoded, cached <see cref="BitmapImage"/>.
/// Remote images load asynchronously; results are cached per-URL so re-paging the
/// catalog doesn't re-download. Decodes down to poster size to keep memory sane.
/// </summary>
public sealed class UrlToImageConverter : IValueConverter
{
    private static readonly ConcurrentDictionary<string, BitmapImage> Cache = new();

    public object? Convert(object? value, Type targetType, object? parameter, CultureInfo culture)
    {
        if (value is not string url || string.IsNullOrWhiteSpace(url)) return null;

        return Cache.GetOrAdd(url, u =>
        {
            try
            {
                var bmp = new BitmapImage();
                bmp.BeginInit();
                bmp.CacheOption = BitmapCacheOption.OnDemand;   // async for http, lazy for file
                bmp.CreateOptions = BitmapCreateOptions.DelayCreation;
                bmp.DecodePixelWidth = 260;                     // posters render ~200px wide
                bmp.UriSource = new Uri(u, UriKind.Absolute);
                bmp.EndInit();
                return bmp;
            }
            catch
            {
                return new BitmapImage();
            }
        });
    }

    public object ConvertBack(object? value, Type t, object? p, CultureInfo c) => Binding.DoNothing;
}

/// <summary>bool → Visibility (true = Visible). Pass "invert" to flip.</summary>
public sealed class BoolToVisibilityConverter : IValueConverter
{
    public object Convert(object? value, Type t, object? parameter, CultureInfo c)
    {
        bool b = value is bool v && v;
        if (parameter as string == "invert") b = !b;
        return b ? Visibility.Visible : Visibility.Collapsed;
    }
    public object ConvertBack(object? value, Type t, object? p, CultureInfo c)
        => value is Visibility vis && vis == Visibility.Visible;
}

/// <summary>Non-null / non-empty → Visible.</summary>
public sealed class NotEmptyToVisibilityConverter : IValueConverter
{
    public object Convert(object? value, Type t, object? p, CultureInfo c)
    {
        bool has = value switch
        {
            null => false,
            string s => !string.IsNullOrWhiteSpace(s),
            int i => i != 0,
            _ => true,
        };
        return has ? Visibility.Visible : Visibility.Collapsed;
    }
    public object ConvertBack(object? value, Type t, object? p, CultureInfo c) => Binding.DoNothing;
}

/// <summary>Maps a <see cref="DownloadStatus"/> to a status brush for the queue rows.</summary>
public sealed class StatusToBrushConverter : IValueConverter
{
    public object Convert(object? value, Type t, object? p, CultureInfo c) => value switch
    {
        DownloadStatus.Completed => new SolidColorBrush(Color.FromRgb(0x30, 0xD1, 0x58)),   // neon green
        DownloadStatus.Downloading => new SolidColorBrush(Color.FromRgb(0x22, 0xD3, 0xEE)), // neon cyan
        DownloadStatus.Failed => new SolidColorBrush(Color.FromRgb(0xF4, 0x3F, 0x5E)),      // neon red
        DownloadStatus.Paused => new SolidColorBrush(Color.FromRgb(0xFB, 0xBF, 0x24)),      // amber
        _ => new SolidColorBrush(Color.FromRgb(0x61, 0x61, 0x6F)),                          // muted
    };
    public object ConvertBack(object? value, Type t, object? p, CultureInfo c) => Binding.DoNothing;
}

/// <summary>Multiplies a 0..1 progress fraction by the bound track width (for the progress fill).</summary>
public sealed class ProgressToWidthConverter : IMultiValueConverter
{
    public object Convert(object[] values, Type t, object? p, CultureInfo c)
    {
        if (values.Length >= 2 && values[0] is double frac && values[1] is double width && width > 0)
            return Math.Clamp(frac, 0, 1) * width;
        return 0d;
    }
    public object[] ConvertBack(object? value, Type[] t, object? p, CultureInfo c) => throw new NotSupportedException();
}

/// <summary>True when a file exists at the given path (drives the "play" affordance).</summary>
public sealed class FileExistsConverter : IValueConverter
{
    public object Convert(object? value, Type t, object? p, CultureInfo c)
        => value is string s && !string.IsNullOrEmpty(s) && File.Exists(s);
    public object ConvertBack(object? value, Type t, object? p, CultureInfo c) => Binding.DoNothing;
}
