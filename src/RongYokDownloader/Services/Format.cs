namespace RongYokDownloader.Services;

/// <summary>Human-readable formatting helpers.</summary>
public static class Format
{
    public static string Bytes(long bytes)
    {
        if (bytes <= 0) return "0 B";
        string[] units = ["B", "KB", "MB", "GB", "TB"];
        double v = bytes;
        int i = 0;
        while (v >= 1024 && i < units.Length - 1) { v /= 1024; i++; }
        return i == 0 ? $"{v:0} {units[i]}" : $"{v:0.0} {units[i]}";
    }

    public static string Speed(double bytesPerSec)
        => bytesPerSec <= 1 ? "" : $"{Bytes((long)bytesPerSec)}/s";

    public static string Percent(double fraction)
        => $"{Math.Clamp(fraction, 0, 1) * 100:0}%";
}
