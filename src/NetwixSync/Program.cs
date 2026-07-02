using System.Net;
using System.Net.Http.Headers;
using System.Text.Json;

// ─────────────────────────────────────────────────────────────────────────────
// NetwixSync — mirror rongyok episodes that NetWix has imported into NetWix's
// own storage, so they play without depending on rongyok's expiring URLs.
//
//   dotnet run --project src/NetwixSync -- --token <NETWIX_INGEST_TOKEN>
//
// Options:
//   --token   <t>   NetWix ingest token (or env NETWIX_INGEST_TOKEN)   [required]
//   --netwix  <url> NetWix base URL            (default https://netwix.online)
//   --source  <s>   source to mirror           (default rongyok)
//   --limit   <n>   max episodes this run      (default 300)
//   --retries <n>   download attempts per ep   (default 3)
//
// The NetWix ingest token lives on the server at /home/admin/.netwix_ingest_token
// ─────────────────────────────────────────────────────────────────────────────

string? Arg(string name)
{
    var a = args;
    for (int i = 0; i < a.Length - 1; i++)
        if (a[i] == name) return a[i + 1];
    return null;
}

string baseUrl = (Arg("--netwix") ?? Environment.GetEnvironmentVariable("NETWIX_URL") ?? "https://netwix.online").TrimEnd('/');
string token = Arg("--token") ?? Environment.GetEnvironmentVariable("NETWIX_INGEST_TOKEN") ?? "";
string source = Arg("--source") ?? "rongyok";
int limit = int.TryParse(Arg("--limit"), out var l) ? l : 300;
int retries = int.TryParse(Arg("--retries"), out var r) ? r : 3;

if (string.IsNullOrWhiteSpace(token))
{
    Console.Error.WriteLine("ERROR: missing NetWix ingest token. Pass --token <t> or set NETWIX_INGEST_TOKEN.");
    return 1;
}

const string UA = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.0.0 Safari/537.36";
var jsonOpts = new JsonSerializerOptions { PropertyNameCaseInsensitive = true };

// rongyok client — keeps a cookie jar and looks like a browser (residential IP required).
using var rongHandler = new HttpClientHandler
{
    AutomaticDecompression = DecompressionMethods.All,
    CookieContainer = new CookieContainer(),
    UseCookies = true,
};
using var rong = new HttpClient(rongHandler) { Timeout = TimeSpan.FromSeconds(120) };
rong.DefaultRequestHeaders.UserAgent.ParseAdd(UA);
rong.DefaultRequestHeaders.AcceptLanguage.ParseAdd("th,en;q=0.8");

// NetWix client
using var netwix = new HttpClient { BaseAddress = new Uri(baseUrl), Timeout = TimeSpan.FromMinutes(15) };
netwix.DefaultRequestHeaders.Add("X-Ingest-Token", token);
netwix.DefaultRequestHeaders.Accept.ParseAdd("application/json");

Console.WriteLine($"NetwixSync → {baseUrl}  (source={source}, limit={limit})");

// 1) Ask NetWix what still needs mirroring.
List<PendingItem> pending;
try
{
    var body = await netwix.GetStringAsync($"/api/ingest/pending?source={source}&limit={limit}");
    pending = JsonSerializer.Deserialize<PendingResponse>(body, jsonOpts)?.Items ?? new();
}
catch (Exception ex)
{
    Console.Error.WriteLine($"ERROR: could not reach NetWix ingest API: {ex.Message}");
    return 1;
}

Console.WriteLine($"NetWix wants {pending.Count} episode(s) mirrored.\n");
if (pending.Count == 0) return 0;

int ok = 0, fail = 0, i = 0;
foreach (var item in pending)
{
    i++;
    string tag = $"[{i}/{pending.Count}] {Trim(item.Title, 32)} ตอนที่ {item.Number}";
    try
    {
        string? url = await ResolveVideoUrl(item.SourceKey, item.Number);
        if (url is null)
        {
            Console.WriteLine($"  ✗ {tag} — resolve failed (source returned no URL)");
            fail++;
            continue;
        }

        string tmp = Path.Combine(Path.GetTempPath(), $"netwixsync_{item.SourceKey}_{item.Number}.mp4");
        long bytes = await DownloadWithRetry(url, tmp, retries);
        await Upload(item.SourceKey, item.Number, tmp);
        TryDelete(tmp);

        Console.WriteLine($"  ✓ {tag} — {bytes / 1024 / 1024.0:0.0} MB");
        ok++;
    }
    catch (Exception ex)
    {
        Console.WriteLine($"  ✗ {tag} — {ex.Message}");
        fail++;
    }
}

Console.WriteLine($"\nDone. mirrored {ok}, failed {fail}.");
return 0;

// ── rongyok resolve: visit the watch page first (session cookie), then get_video.php ──
async Task<string?> ResolveVideoUrl(string seriesId, int ep)
{
    string watch = $"https://rongyok.com/watch/?series_id={seriesId}&ep={ep}";
    try { await rong.GetAsync(watch); } catch { /* establishing session is best-effort */ }

    using var req = new HttpRequestMessage(HttpMethod.Get, $"https://rongyok.com/watch/get_video.php?series_id={seriesId}&ep={ep}");
    req.Headers.Referrer = new Uri(watch);
    req.Headers.Add("X-Requested-With", "XMLHttpRequest");

    using var resp = await rong.SendAsync(req);
    if (!resp.IsSuccessStatusCode) return null;

    var body = await resp.Content.ReadAsStringAsync();
    try
    {
        using var doc = JsonDocument.Parse(body);
        var root = doc.RootElement;
        bool okFlag = root.TryGetProperty("ok", out var o) && (o.ValueKind == JsonValueKind.True || (o.ValueKind == JsonValueKind.String && o.GetString() == "true"));
        if (!okFlag) return null;
        return root.TryGetProperty("video_url", out var u) ? u.GetString() : null;
    }
    catch (JsonException) { return null; }
}

async Task<long> DownloadWithRetry(string url, string path, int attempts)
{
    Exception? last = null;
    for (int a = 1; a <= attempts; a++)
    {
        try { return await Download(url, path); }
        catch (Exception ex) { last = ex; await Task.Delay(800 * a); }
    }
    throw last ?? new Exception("download failed");
}

async Task<long> Download(string url, string path)
{
    using var resp = await rong.GetAsync(url, HttpCompletionOption.ResponseHeadersRead);
    resp.EnsureSuccessStatusCode();
    await using var fs = File.Create(path);
    await resp.Content.CopyToAsync(fs);
    return new FileInfo(path).Length;
}

async Task Upload(string seriesId, int ep, string path)
{
    using var form = new MultipartFormDataContent
    {
        { new StringContent(source), "source" },
        { new StringContent(seriesId), "source_key" },
        { new StringContent(ep.ToString()), "number" },
    };
    var fileContent = new StreamContent(File.OpenRead(path));
    fileContent.Headers.ContentType = new MediaTypeHeaderValue("video/mp4");
    form.Add(fileContent, "file", $"{ep}.mp4");

    using var resp = await netwix.PostAsync("/api/ingest/episode", form);
    string txt = await resp.Content.ReadAsStringAsync();
    if (!resp.IsSuccessStatusCode)
        throw new Exception($"upload HTTP {(int)resp.StatusCode}: {Trim(txt, 120)}");
}

static void TryDelete(string p) { try { File.Delete(p); } catch { } }
static string Trim(string? s, int n) { s ??= ""; return s.Length <= n ? s : s[..n] + "…"; }

// ── DTOs ──
record PendingResponse(int Count, List<PendingItem> Items);
record PendingItem(long Episode_Id, string Source, string Source_Key, int Number, string Title)
{
    public string SourceKey => Source_Key;
}
