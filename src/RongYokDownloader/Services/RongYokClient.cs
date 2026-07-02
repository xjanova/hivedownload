using System.Net;
using System.Net.Http;
using System.Net.Http.Headers;
using System.Text.Json;
using System.Text.RegularExpressions;
using RongYokDownloader.Models;

namespace RongYokDownloader.Services;

/// <summary>
/// Talks to rongyok.com. Three confirmed endpoints, no auth / captcha / ad-gate required:
///   1. GET /category?category=all              → embedded <c>seriesData</c> array (whole catalog)
///   2. GET /watch/?series_id={id}              → embedded object with episodes_count + episodes[]
///   3. GET /watch/get_video.php?series_id&amp;ep → {"ok":true,"video_url":"&lt;discord mp4&gt;"}
/// Video files themselves live on Discord's CDN (signed, expiring, plain MP4).
/// </summary>
public sealed partial class RongYokClient : IMediaSource
{
    public const string BaseUrl = "https://rongyok.com";

    public string SourceId => SourceIds.RongYok;
    public string DisplayName => "โรงหยก";

    private readonly HttpClient _http;

    public RongYokClient(HttpClient? http = null)
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

    [GeneratedRegex(@"poster/(?<title>.+?)-(?<type>พากย์ไทย|ซับไทย)-(?<year>\d{4})-(?<id>\d+)\.", RegexOptions.Compiled)]
    private static partial Regex PosterPattern();

    [GeneratedRegex(@"""episodes_count""\s*:\s*(\d+)", RegexOptions.Compiled)]
    private static partial Regex EpisodesCountPattern();

    // ------------------------------------------------------------- 1. catalog

    /// <summary>Downloads and parses the full catalog (~2,300+ series) — one page, whole catalogue.</summary>
    public async Task<List<Series>> FetchCatalogAsync(IProgress<string>? progress = null, CancellationToken ct = default)
    {
        progress?.Report("โรงหยก: กำลังดึงแคตตาล็อก…");
        string html = await _http.GetStringAsync($"{BaseUrl}/category?category=all", ct);
        string? arrayJson = JsonExtract.CatalogArray(html);
        if (arrayJson is null)
            throw new InvalidOperationException("ไม่พบข้อมูลซีรี่ส์ในหน้าเว็บ (seriesData) — โครงสร้างเว็บอาจเปลี่ยนไป");

        var list = new List<Series>();
        using var doc = JsonDocument.Parse(arrayJson);
        foreach (var el in doc.RootElement.EnumerateArray())
        {
            var s = ParseSeries(el);
            if (s is not null) list.Add(s);
        }
        return list;
    }

    private static Series? ParseSeries(JsonElement el)
    {
        if (!el.TryGetProperty("id", out var idEl) || !idEl.TryGetInt32(out int id))
            return null;

        string rawTitle = GetStr(el, "title");
        string posterRel = GetStr(el, "poster_url");
        string jpgRel = GetStr(el, "jpg_url");

        var s = new Series
        {
            Id = id,
            SourceId = SourceIds.RongYok,
            Title = rawTitle,
            Description = GetStr(el, "description"),
            PosterUrl = ToAbsolute(posterRel),
            JpgUrl = ToAbsolute(string.IsNullOrEmpty(jpgRel) ? posterRel : jpgRel),
            ViewCount = el.TryGetProperty("view_count", out var vc) && vc.TryGetInt32(out int v) ? v : 0,
            CreatedAt = GetStr(el, "created_at"),
        };

        // Derive clean title, language and year from the poster file name — it's the most reliable source.
        var m = PosterPattern().Match(posterRel);
        if (m.Success)
        {
            s.CleanTitle = Uri.UnescapeDataString(m.Groups["title"].Value);
            s.Type = DubTypeExtensions.Detect(m.Groups["type"].Value);
            if (int.TryParse(m.Groups["year"].Value, out int y)) s.Year = y;
        }
        else
        {
            s.Type = DubTypeExtensions.Detect(posterRel + rawTitle);
        }

        if (string.IsNullOrWhiteSpace(s.CleanTitle))
            s.CleanTitle = CleanTitle(rawTitle);

        return s;
    }

    /// <summary>Strips the trailing "th" language tag the site appends to raw titles.</summary>
    private static string CleanTitle(string raw)
    {
        string t = raw.Trim();
        if (t.EndsWith("th", StringComparison.OrdinalIgnoreCase) && t.Length > 2)
            t = t[..^2].TrimEnd();
        return t;
    }

    // ------------------------------------------------------- 2. episode list

    /// <summary><see cref="IMediaSource"/> entry point — resolves the series to its numeric id.</summary>
    public Task<List<int>> FetchEpisodeNumbersAsync(Series series, CancellationToken ct = default)
        => FetchEpisodeNumbersAsync(series.Id, ct);

    /// <summary>
    /// Returns the episode numbers for a series (and thus the count).
    /// Parses the embedded <c>episodes</c> array; falls back to 1..episodes_count.
    /// </summary>
    public async Task<List<int>> FetchEpisodeNumbersAsync(int seriesId, CancellationToken ct = default)
    {
        string html = await _http.GetStringAsync($"{BaseUrl}/watch/?series_id={seriesId}", ct);

        var nums = new List<int>();
        string? epArray = JsonExtract.EpisodesArray(html);
        if (epArray is not null)
        {
            try
            {
                using var doc = JsonDocument.Parse(epArray);
                foreach (var e in doc.RootElement.EnumerateArray())
                    if (e.TryGetProperty("episode_number", out var n) && n.TryGetInt32(out int num))
                        nums.Add(num);
            }
            catch (JsonException) { /* fall through to count-based */ }
        }

        if (nums.Count == 0)
        {
            var m = EpisodesCountPattern().Match(html);
            if (m.Success && int.TryParse(m.Groups[1].Value, out int count))
                for (int i = 1; i <= count; i++) nums.Add(i);
        }

        nums.Sort();
        return nums;
    }

    // --------------------------------------------------------- 3. video url

    /// <summary><see cref="IMediaSource"/> entry point — rongyok serves a plain progressive MP4.</summary>
    public async Task<StreamInfo?> ResolveEpisodeAsync(Series series, int episodeNumber, CancellationToken ct = default)
    {
        string? url = await GetVideoUrlAsync(series.Id, episodeNumber, ct);
        return string.IsNullOrEmpty(url)
            ? null
            : new StreamInfo { Kind = StreamKind.Mp4Progressive, Url = url };
    }

    /// <summary>Resolves the direct (Discord CDN) MP4 URL for one episode. Null if unavailable.</summary>
    public async Task<string?> GetVideoUrlAsync(int seriesId, int ep, CancellationToken ct = default)
    {
        using var req = new HttpRequestMessage(HttpMethod.Get,
            $"{BaseUrl}/watch/get_video.php?series_id={seriesId}&ep={ep}");
        req.Headers.Referrer = new Uri($"{BaseUrl}/watch/?series_id={seriesId}&ep={ep}");
        req.Headers.Add("X-Requested-With", "XMLHttpRequest");

        using var resp = await _http.SendAsync(req, ct);
        resp.EnsureSuccessStatusCode();
        string body = await resp.Content.ReadAsStringAsync(ct);

        try
        {
            using var doc = JsonDocument.Parse(body);
            var root = doc.RootElement;
            bool ok = root.TryGetProperty("ok", out var okEl) &&
                      (okEl.ValueKind == JsonValueKind.True ||
                       (okEl.ValueKind == JsonValueKind.String && okEl.GetString() == "true"));
            if (!ok) return null;
            return root.TryGetProperty("video_url", out var u) ? u.GetString() : null;
        }
        catch (JsonException)
        {
            return null;
        }
    }

    // ------------------------------------------------------------- utilities

    /// <summary>Streams a URL (poster or video) to a callback-friendly HTTP response.</summary>
    public Task<HttpResponseMessage> GetStreamResponseAsync(string url, long resumeFrom, CancellationToken ct)
    {
        var req = new HttpRequestMessage(HttpMethod.Get, url);
        if (resumeFrom > 0)
            req.Headers.Range = new System.Net.Http.Headers.RangeHeaderValue(resumeFrom, null);
        return _http.SendAsync(req, HttpCompletionOption.ResponseHeadersRead, ct);
    }

    private static string GetStr(JsonElement el, string prop)
        => el.TryGetProperty(prop, out var p) && p.ValueKind == JsonValueKind.String ? (p.GetString() ?? "") : "";

    private static string ToAbsolute(string rel)
    {
        if (string.IsNullOrEmpty(rel)) return "";
        if (rel.StartsWith("http", StringComparison.OrdinalIgnoreCase)) return rel;
        return $"{BaseUrl}/{rel.TrimStart('/')}";
    }
}
