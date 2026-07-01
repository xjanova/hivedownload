namespace RongYokDownloader.Models;

/// <summary>
/// A drama/series on rongyok.com. Mirrors the <c>seriesData</c> objects embedded in
/// <c>/category?category=all</c> plus a few fields we compute or fill in later.
/// </summary>
public sealed class Series
{
    public int Id { get; set; }

    /// <summary>Raw title from the site (often carries a trailing "th" language tag).</summary>
    public string Title { get; set; } = "";

    /// <summary>Cleaned, display-ready title (suffix stripped).</summary>
    public string CleanTitle { get; set; } = "";

    public string Description { get; set; } = "";

    public DubType Type { get; set; } = DubType.Unknown;

    /// <summary>Absolute URL of the .webp poster.</summary>
    public string PosterUrl { get; set; } = "";

    /// <summary>Absolute URL of the .jpg poster (used for local saving — broader tool support).</summary>
    public string JpgUrl { get; set; } = "";

    /// <summary>Local path of the downloaded cover, if any.</summary>
    public string? PosterLocalPath { get; set; }

    public int ViewCount { get; set; }

    public string CreatedAt { get; set; } = "";

    /// <summary>Number of episodes. 0 until the detail page has been loaded.</summary>
    public int EpisodesCount { get; set; }

    /// <summary>Publication year parsed from the poster file name, if present.</summary>
    public int? Year { get; set; }

    // ---- computed helpers ----
    public string TypeThai => Type.ToThai();
    public string YearText => Year?.ToString() ?? "";

    /// <summary>
    /// Best image URL/path for display. WPF cannot decode .webp, so we prefer the .jpg
    /// (or the locally saved cover once it exists).
    /// </summary>
    public string DisplayImageUrl =>
        !string.IsNullOrEmpty(PosterLocalPath) ? PosterLocalPath
        : !string.IsNullOrEmpty(JpgUrl) ? JpgUrl
        : PosterUrl;

    public string ViewCountText => ViewCount >= 1000 ? $"{ViewCount / 1000.0:0.0}K" : ViewCount.ToString();
}
