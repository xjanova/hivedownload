using System.Collections.Concurrent;
using System.IO;
using System.Net;
using System.Net.Http;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;
using System.Windows.Media.Imaging;

namespace RongYokDownloader.Converters;

/// <summary>
/// Attached property that loads an image into an <see cref="Image"/> reliably.
///
/// WPF's built-in remote <see cref="BitmapImage.UriSource"/> download is flaky for
/// non-ASCII (Thai) URLs and inside virtualized item panels — it often just shows
/// nothing. So we download the bytes ourselves via a shared <see cref="HttpClient"/>
/// and decode from a MemoryStream with OnLoad + Freeze (fully self-contained, cross
/// thread-safe, cacheable). Handles both http(s) URLs and local file paths.
///
/// Usage:  &lt;Image conv:ImageLoader.SourceUrl="{Binding DisplayImageUrl}" /&gt;
/// </summary>
public static class ImageLoader
{
    private static readonly HttpClient Http = CreateClient();
    private static readonly ConcurrentDictionary<string, ImageSource?> Cache = new();

    private static HttpClient CreateClient()
    {
        var handler = new HttpClientHandler
        {
            AutomaticDecompression = DecompressionMethods.GZip | DecompressionMethods.Deflate | DecompressionMethods.Brotli,
        };
        var c = new HttpClient(handler) { Timeout = TimeSpan.FromSeconds(30) };
        c.DefaultRequestHeaders.UserAgent.ParseAdd(
            "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.0.0 Safari/537.36");
        c.DefaultRequestHeaders.Referrer = new Uri("https://rongyok.com/");
        return c;
    }

    public static readonly DependencyProperty SourceUrlProperty =
        DependencyProperty.RegisterAttached(
            "SourceUrl", typeof(string), typeof(ImageLoader),
            new PropertyMetadata(null, OnSourceUrlChanged));

    public static void SetSourceUrl(DependencyObject o, string? v) => o.SetValue(SourceUrlProperty, v);
    public static string? GetSourceUrl(DependencyObject o) => (string?)o.GetValue(SourceUrlProperty);

    private static async void OnSourceUrlChanged(DependencyObject d, DependencyPropertyChangedEventArgs e)
    {
        if (d is not Image img) return;
        string? url = e.NewValue as string;

        img.Source = null;                       // clear immediately (matters for recycled containers)
        if (string.IsNullOrWhiteSpace(url)) return;

        if (Cache.TryGetValue(url, out var cached))
        {
            if (GetSourceUrl(img) == url) img.Source = cached;
            return;
        }

        ImageSource? src = null;
        try
        {
            byte[] bytes;
            if (url.StartsWith("http", StringComparison.OrdinalIgnoreCase))
                bytes = await Http.GetByteArrayAsync(url);
            else if (File.Exists(url))
                bytes = await File.ReadAllBytesAsync(url);
            else
                return;

            src = Decode(bytes);
        }
        catch
        {
            src = null;                          // 404 / network / decode failure → leave blank
        }

        Cache[url] = src;
        if (src is not null && GetSourceUrl(img) == url)   // guard against container recycling
            img.Source = src;
    }

    private static ImageSource Decode(byte[] bytes)
    {
        using var ms = new MemoryStream(bytes);
        var bmp = new BitmapImage();
        bmp.BeginInit();
        bmp.CacheOption = BitmapCacheOption.OnLoad;          // decode now, don't hold the stream
        bmp.CreateOptions = BitmapCreateOptions.PreservePixelFormat;
        bmp.DecodePixelWidth = 300;                          // posters render ~200px wide
        bmp.StreamSource = ms;
        bmp.EndInit();
        bmp.Freeze();                                        // shareable across elements & threads
        return bmp;
    }
}
