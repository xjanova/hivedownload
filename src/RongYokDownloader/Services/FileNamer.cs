using System.IO;
using System.Text.RegularExpressions;
using RongYokDownloader.Models;

namespace RongYokDownloader.Services;

/// <summary>Builds tidy, filesystem-safe folder and file names (Thai titles included).</summary>
public static partial class FileNamer
{
    [GeneratedRegex(@"[<>:""/\\|?*\x00-\x1F]")]
    private static partial Regex InvalidChars();

    [GeneratedRegex(@"\s+")]
    private static partial Regex Whitespace();

    /// <summary>Strips characters Windows forbids and trims trailing dots/spaces.</summary>
    public static string Sanitize(string name)
    {
        if (string.IsNullOrWhiteSpace(name)) return "unknown";
        string s = InvalidChars().Replace(name, " ");
        s = Whitespace().Replace(s, " ").Trim();
        s = s.TrimEnd('.', ' ');
        if (s.Length == 0) s = "unknown";
        // keep individual path segments comfortably under the 255-char limit
        return s.Length > 120 ? s[..120].TrimEnd('.', ' ') : s;
    }

    /// <summary>e.g. "บ่วงรัก (พากย์ไทย)" — the per-series folder name.</summary>
    public static string SeriesFolderName(Series s)
    {
        string title = string.IsNullOrWhiteSpace(s.CleanTitle) ? s.Title : s.CleanTitle;
        string typeTag = s.Type == DubType.Unknown ? "" : $" ({s.Type.ToThai()})";
        return Sanitize($"{title}{typeTag}");
    }

    /// <summary>Full folder path for a series under the chosen download root.</summary>
    public static string SeriesFolder(string root, Series s)
        => Path.Combine(root, SeriesFolderName(s));

    /// <summary>e.g. "บ่วงรัก - EP07.mp4" (episode zero-padded to the series' width).</summary>
    public static string EpisodeFileName(Series s, int episodeNumber)
    {
        string title = string.IsNullOrWhiteSpace(s.CleanTitle) ? s.Title : s.CleanTitle;
        int width = Math.Max(2, s.EpisodesCount.ToString().Length);
        string ep = episodeNumber.ToString().PadLeft(width, '0');
        return Sanitize($"{title} - EP{ep}") + ".mp4";
    }

    public static string EpisodePath(string root, Series s, int episodeNumber)
        => Path.Combine(SeriesFolder(root, s), EpisodeFileName(s, episodeNumber));
}
