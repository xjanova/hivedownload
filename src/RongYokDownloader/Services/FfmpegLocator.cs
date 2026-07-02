using System.IO;

namespace RongYokDownloader.Services;

/// <summary>
/// Finds the ffmpeg executable. Prefers the copy shipped next to the app (tools\ffmpeg\ffmpeg.exe
/// or ffmpeg.exe in the app folder); falls back to whatever is on PATH.
/// </summary>
public static class FfmpegLocator
{
    private static string? _cached;

    /// <summary>Absolute path to a bundled ffmpeg, or just "ffmpeg" to use PATH. Cached after first probe.</summary>
    public static string ResolvePath()
    {
        if (_cached is not null) return _cached;

        string baseDir = AppContext.BaseDirectory;
        string[] candidates =
        {
            Path.Combine(baseDir, "tools", "ffmpeg", "ffmpeg.exe"),
            Path.Combine(baseDir, "ffmpeg", "ffmpeg.exe"),
            Path.Combine(baseDir, "ffmpeg.exe"),
        };

        foreach (var c in candidates)
        {
            if (File.Exists(c)) { _cached = c; return c; }
        }

        _cached = "ffmpeg"; // rely on PATH
        return _cached;
    }

    /// <summary>True if a bundled ffmpeg.exe exists (so we can warn before a job fails).</summary>
    public static bool HasBundled() =>
        ResolvePath().EndsWith("ffmpeg.exe", StringComparison.OrdinalIgnoreCase) &&
        File.Exists(ResolvePath());
}
