namespace RongYokDownloader.Models;

/// <summary>Language track of a series, parsed from the poster file name on rongyok.com.</summary>
public enum DubType
{
    Unknown = 0,
    /// <summary>พากย์ไทย — Thai dubbed.</summary>
    ThaiDub = 1,
    /// <summary>ซับไทย — Thai subtitles.</summary>
    ThaiSub = 2,
}

/// <summary>Lifecycle of a single episode download.</summary>
public enum DownloadStatus
{
    /// <summary>Known but never queued.</summary>
    None = 0,
    /// <summary>Sitting in the queue, waiting for a free download slot.</summary>
    Queued = 1,
    /// <summary>Actively transferring bytes.</summary>
    Downloading = 2,
    /// <summary>User paused (partial file kept on disk for resume).</summary>
    Paused = 3,
    /// <summary>Finished and verified on disk.</summary>
    Completed = 4,
    /// <summary>Failed — see <c>Error</c>. Can be retried.</summary>
    Failed = 5,
}

public static class DubTypeExtensions
{
    public static string ToThai(this DubType t) => t switch
    {
        DubType.ThaiDub => "พากย์ไทย",
        DubType.ThaiSub => "ซับไทย",
        _ => "ไม่ระบุ",
    };

    /// <summary>Best-effort language detection from a rongyok poster path/title.</summary>
    public static DubType Detect(string? text)
    {
        if (string.IsNullOrEmpty(text)) return DubType.Unknown;
        if (text.Contains("พากย์ไทย")) return DubType.ThaiDub;
        if (text.Contains("ซับไทย")) return DubType.ThaiSub;
        return DubType.Unknown;
    }
}
