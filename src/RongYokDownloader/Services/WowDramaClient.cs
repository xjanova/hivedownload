using System.Net;
using System.Net.Http;
using System.Text.Json;
using System.Text.RegularExpressions;
using RongYokDownloader.Models;

namespace RongYokDownloader.Services;

/// <summary>
/// Talks to wow-drama.com — a WordPress site (theme "wowdrama" + the "miru-player" plugin) that
/// hosts full-length CN/KR/JP series. Unlike rongyok there is no plain-file API: video is HLS, and
/// each episode resolves through several hops. Verified flow (2026-07):
///   1. catalog   → GET /category/the-series-all/page/{n}/   (parse the .pic cards)
///   2. episodes  → GET /{slug}/                              (parse the mp-ep-btn buttons)
///   3. resolve   → POST /wp-admin/admin-ajax.php action=miru_custom_player&post_id={id}
///                    → returns a getplay-cdn embed hash
///                  → the HLS playlist is https://getplay-cdn.com/api/stream/{hash}/index.m3u8
/// The playlist's segments are MPEG-TS hidden behind a tiny PNG header on TikTok's image CDN;
/// stripping + muxing is handled by <see cref="HlsDownloader"/>, not here.
/// </summary>
public sealed partial class WowDramaClient : IMediaSource
{
    public const string BaseUrl = "https://wow-drama.com";
    public const string GetPlayBase = "https://getplay-cdn.com";

    /// <summary>
    /// WordPress category id of "the-series-all" (holds every series — verified 2,473 posts).
    /// The catalogue is pulled from the WP REST API, 100 per page (~25 pages) — far faster and
    /// tidier than scraping 155 HTML listing pages.
    /// </summary>
    private const int SeriesCategoryId = 1;

    /// <summary>Safety cap so a broken/looping paginator can't fetch forever.</summary>
    private const int MaxCatalogPages = 60;

    public string SourceId => SourceIds.WowDrama;
    public string DisplayName => "wow-drama";

    private readonly HttpClient _http;

    public WowDramaClient(HttpClient? http = null)
    {
        if (http is not null)
        {
            _http = http;
        }
        else
        {
            var handler = new HttpClientHandler
            {
                AutomaticDecompression = DecompressionMethods.GZip | DecompressionMethods.Deflate | DecompressionMethods.Brotli,
                CookieContainer = new CookieContainer(),
                UseCookies = true,
            };
            _http = new HttpClient(handler) { Timeout = TimeSpan.FromSeconds(60) };
        }

        _http.DefaultRequestHeaders.UserAgent.ParseAdd(
            "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.0.0 Safari/537.36");
        _http.DefaultRequestHeaders.AcceptLanguage.ParseAdd("th,en;q=0.8");
    }

    // ---------------------------------------------------------------- regexes

    [GeneratedRegex(@"<button class=""mp-ep-btn[^""]*""\s+data-id=""(?<postid>\d+)""[^>]*>(?:<i[^>]*></i>)?\s*(?<label>[^<]+?)\s*</button>",
        RegexOptions.Compiled)]
    private static partial Regex EpButtonPattern();

    [GeneratedRegex(@"getplay-cdn\.com/embed/(?<hash>[a-f0-9]{16,})", RegexOptions.Compiled)]
    private static partial Regex GetPlayHashPattern();

    [GeneratedRegex(@"(?:\((?<y>\d{4})\)|-(?<y2>\d{4})(?:$|[/\-]))", RegexOptions.Compiled)]
    private static partial Regex YearPattern();

    [GeneratedRegex(@"^\s*ดู(ซีรี่ส์|ซีรี่ย์|ซีรีส์|หนัง)(จีน|เกาหลี|ญี่ปุ่น|ไทย|ฝรั่ง)?\s*", RegexOptions.Compiled)]
    private static partial Regex TitlePrefixPattern();

    [GeneratedRegex(@"\s*(เต็มเรื่อง|จบเรื่อง|ครบทุกตอน|ทุกตอน|พากย์ไทย|ซับไทย|ซับ|พากย์|HD|ครบ)\s*$", RegexOptions.Compiled)]
    private static partial Regex TitleSuffixPattern();

    // ------------------------------------------------------------- 1. catalog

    /// <summary>
    /// Pulls the whole catalogue via the WordPress REST API (100 posts/page, ~25 pages for ~2,473
    /// series). Reports "…page X/Y" through <paramref name="progress"/> so the UI shows movement.
    /// Posters are .webp-only on this site, so we don't carry them (WPF can't decode webp anyway).
    /// </summary>
    public async Task<List<Series>> FetchCatalogAsync(IProgress<string>? progress = null, CancellationToken ct = default)
    {
        var list = new List<Series>();
        var seen = new HashSet<int>();
        int totalPages = MaxCatalogPages;

        for (int page = 1; page <= totalPages && page <= MaxCatalogPages; page++)
        {
            ct.ThrowIfCancellationRequested();
            string url = $"{BaseUrl}/wp-json/wp/v2/posts?categories={SeriesCategoryId}" +
                         $"&per_page=100&page={page}&_fields=id,slug,title,featured_media";

            using var resp = await _http.SendAsync(new HttpRequestMessage(HttpMethod.Get, url), ct);
            if (!resp.IsSuccessStatusCode) break;   // 400 = past the last page

            if (page == 1 &&
                resp.Headers.TryGetValues("X-WP-TotalPages", out var tp) &&
                int.TryParse(tp.FirstOrDefault(), out int t) && t > 0)
                totalPages = Math.Min(t, MaxCatalogPages);

            string json = await resp.Content.ReadAsStringAsync(ct);
            int before = list.Count;

            // Parse this page's posts, remembering each one's featured-media id.
            var pageItems = new List<(Series Series, int MediaId)>();
            using (var doc = JsonDocument.Parse(json))
            {
                if (doc.RootElement.ValueKind != JsonValueKind.Array) break;
                foreach (var el in doc.RootElement.EnumerateArray())
                {
                    var parsed = ParseRestPost(el);
                    if (parsed.Series is not null) pageItems.Add((parsed.Series, parsed.MediaId));
                }
            }

            // One batched call resolves every poster URL for the page (media?include=…).
            var mediaIds = pageItems.Where(x => x.MediaId > 0).Select(x => x.MediaId).Distinct().ToList();
            if (mediaIds.Count > 0)
            {
                var posters = await FetchPostersAsync(mediaIds, ct);
                foreach (var (s, mid) in pageItems)
                {
                    if (posters.TryGetValue(mid, out var posterUrl))
                    {
                        s.PosterUrl = posterUrl;
                        s.JpgUrl = posterUrl;   // .webp; WPF decodes it via the OS WebP codec
                    }
                }
            }

            foreach (var (s, _) in pageItems)
                if (seen.Add(s.Id)) list.Add(s);

            progress?.Report($"wow-drama: ดึงแล้ว {list.Count} เรื่อง (หน้า {page}/{totalPages})");
            if (list.Count == before) break;        // empty page → done
        }

        return list;
    }

    private static (Series? Series, int MediaId) ParseRestPost(JsonElement el)
    {
        string slug = el.TryGetProperty("slug", out var sl) ? sl.GetString() ?? "" : "";
        if (string.IsNullOrEmpty(slug)) return (null, 0);

        string rawTitle = el.TryGetProperty("title", out var t) && t.TryGetProperty("rendered", out var r)
            ? WebUtility.HtmlDecode(r.GetString() ?? "").Trim()
            : slug;

        int mediaId = el.TryGetProperty("featured_media", out var fm) && fm.TryGetInt32(out int m) ? m : 0;

        var s = new Series
        {
            Id = SourceIds.StableNegativeId(SourceIds.WowDrama, slug),
            SourceId = SourceIds.WowDrama,
            Slug = slug,
            Title = rawTitle,
            CleanTitle = CleanWowTitle(rawTitle),
            Type = DubTypeExtensions.Detect(rawTitle),
        };

        var ym = YearPattern().Match(rawTitle + " " + slug);
        if (ym.Success)
        {
            string y = ym.Groups["y"].Success ? ym.Groups["y"].Value : ym.Groups["y2"].Value;
            if (int.TryParse(y, out int year)) s.Year = year;
        }

        return (s, mediaId);
    }

    /// <summary>Batch-resolve featured-media ids to their poster URLs in a single REST call.</summary>
    private async Task<Dictionary<int, string>> FetchPostersAsync(List<int> mediaIds, CancellationToken ct)
    {
        var map = new Dictionary<int, string>();
        try
        {
            string url = $"{BaseUrl}/wp-json/wp/v2/media?include={string.Join(",", mediaIds)}" +
                         $"&per_page=100&_fields=id,source_url";
            string json = await _http.GetStringAsync(url, ct);
            using var doc = JsonDocument.Parse(json);
            if (doc.RootElement.ValueKind == JsonValueKind.Array)
            {
                foreach (var el in doc.RootElement.EnumerateArray())
                {
                    if (el.TryGetProperty("id", out var idEl) && idEl.TryGetInt32(out int id) &&
                        el.TryGetProperty("source_url", out var su) && su.GetString() is { Length: > 0 } src)
                        map[id] = src;
                }
            }
        }
        catch { /* posters are best-effort — a page without them still lists fine */ }
        return map;
    }

    /// <summary>Trim the site's "ดูซีรี่ย์ … เต็มเรื่อง / ซับไทย" decoration down to a display title.</summary>
    private static string CleanWowTitle(string raw)
    {
        string t = TitlePrefixPattern().Replace(raw, "");
        for (int i = 0; i < 3; i++)                 // strip up to a few trailing tags
        {
            string next = TitleSuffixPattern().Replace(t, "").Trim();
            if (next == t) break;
            t = next;
        }
        return string.IsNullOrWhiteSpace(t) ? raw : t;
    }

    // ------------------------------------------------------- 2. episode list

    public async Task<List<int>> FetchEpisodeNumbersAsync(Series series, CancellationToken ct = default)
    {
        var eps = await FetchEpisodesAsync(series, ct);
        return eps.Select(e => e.Number).ToList();
    }

    /// <summary>Episode number → WordPress post id, in on-screen order (1-based).</summary>
    private async Task<List<(int Number, string PostId)>> FetchEpisodesAsync(Series series, CancellationToken ct)
    {
        string html = await _http.GetStringAsync($"{BaseUrl}/{series.Slug}/", ct);

        var result = new List<(int, string)>();
        int n = 0;
        foreach (Match m in EpButtonPattern().Matches(html))
        {
            n++;
            result.Add((n, m.Groups["postid"].Value));
        }
        return result;
    }

    // --------------------------------------------------------- 3. resolve HLS

    public async Task<StreamInfo?> ResolveEpisodeAsync(Series series, int episodeNumber, CancellationToken ct = default)
    {
        var eps = await FetchEpisodesAsync(series, ct);
        var target = eps.FirstOrDefault(e => e.Number == episodeNumber);
        if (target.PostId is null) return null;

        string? hash = await ResolveGetPlayHashAsync(series, target.PostId, ct);
        if (string.IsNullOrEmpty(hash)) return null;

        return new StreamInfo
        {
            Kind = StreamKind.Hls,
            Url = $"{GetPlayBase}/api/stream/{hash}/index.m3u8",
            Referer = $"{GetPlayBase}/embed/{hash}",
        };
    }

    /// <summary>POST the miru-player AJAX for one episode post and pull its getplay-cdn embed hash.</summary>
    private async Task<string?> ResolveGetPlayHashAsync(Series series, string postId, CancellationToken ct)
    {
        using var req = new HttpRequestMessage(HttpMethod.Post, $"{BaseUrl}/wp-admin/admin-ajax.php")
        {
            Content = new FormUrlEncodedContent(new[]
            {
                new KeyValuePair<string, string>("action", "miru_custom_player"),
                new KeyValuePair<string, string>("post_id", postId),
            }),
        };
        req.Headers.Referrer = new Uri($"{BaseUrl}/{series.Slug}/");
        req.Headers.Add("X-Requested-With", "XMLHttpRequest");

        using var resp = await _http.SendAsync(req, ct);
        if (!resp.IsSuccessStatusCode) return null;
        string body = await resp.Content.ReadAsStringAsync(ct);

        var m = GetPlayHashPattern().Match(body);
        return m.Success ? m.Groups["hash"].Value : null;
    }

    // ------------------------------------------------------------- utilities

    public Task<HttpResponseMessage> GetStreamResponseAsync(string url, long resumeFrom, CancellationToken ct)
    {
        var req = new HttpRequestMessage(HttpMethod.Get, url);
        if (resumeFrom > 0)
            req.Headers.Range = new System.Net.Http.Headers.RangeHeaderValue(resumeFrom, null);
        return _http.SendAsync(req, HttpCompletionOption.ResponseHeadersRead, ct);
    }
}
