using System.Net;
using System.Net.Http.Headers;
using System.Text.Json;

// ─────────────────────────────────────────────────────────────────────────────
// NetwixSync — keeps NetWix's rongyok library mirrored to NetWix's own storage,
// so episodes play without depending on rongyok's residential-only expiring URLs.
//
//   One pass:      dotnet run --project src/NetwixSync -- --token <TOKEN>
//   Run forever:   dotnet run --project src/NetwixSync -- --loop 60 --token <TOKEN>
//
// Options:
//   --token   <t>   NetWix ingest token (or env NETWIX_INGEST_TOKEN, or token.txt)
//   --loop    [sec] run continuously, polling every [sec] seconds (default 60)
//   --netwix  <url> NetWix base URL            (default https://netwix.online)
//   --source  <s>   source to mirror           (default rongyok)
//   --limit   <n>   max episodes per pass      (default 300)
//   --retries <n>   download attempts per ep   (default 3)
//
// In loop mode, customer-requested episodes (★) are mirrored first, so a viewer
// who clicks an un-mirrored episode gets it within one poll cycle.
// The ingest token is on the server at /home/admin/.netwix_ingest_token
// ─────────────────────────────────────────────────────────────────────────────

string? Arg(string name)
{
    for (int i = 0; i < args.Length - 1; i++)
        if (args[i] == name) return args[i + 1];
    return null;
}

string TokenFromFile()
{
    var p = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData), "NetwixSync", "token.txt");
    return File.Exists(p) ? File.ReadAllText(p).Trim() : "";
}

string baseUrl = (Arg("--netwix") ?? Environment.GetEnvironmentVariable("NETWIX_URL") ?? "https://netwix.online").TrimEnd('/');
string token = Arg("--token") ?? Environment.GetEnvironmentVariable("NETWIX_INGEST_TOKEN") ?? TokenFromFile();
string source = Arg("--source") ?? "rongyok";
int limit = int.TryParse(Arg("--limit"), out var l) ? l : 300;
int retries = int.TryParse(Arg("--retries"), out var r) ? r : 4;
int loop = args.Contains("--loop") ? (int.TryParse(Arg("--loop"), out var iv) && iv > 0 ? iv : 60) : 0;

if (string.IsNullOrWhiteSpace(token))
{
    Console.Error.WriteLine("ERROR: missing NetWix ingest token. Pass --token <t>, set NETWIX_INGEST_TOKEN, or run install-startup.ps1.");
    return 1;
}

const string UA = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.0.0 Safari/537.36";
var jsonOpts = new JsonSerializerOptions { PropertyNameCaseInsensitive = true };

// rongyok client — cookie jar + browser UA (must run from a residential connection).
using var rongHandler = new HttpClientHandler
{
    AutomaticDecompression = DecompressionMethods.All,
    CookieContainer = new CookieContainer(),
    UseCookies = true,
};
using var rong = new HttpClient(rongHandler) { Timeout = TimeSpan.FromSeconds(120) };
rong.DefaultRequestHeaders.UserAgent.ParseAdd(UA);
rong.DefaultRequestHeaders.AcceptLanguage.ParseAdd("th,en;q=0.8");

using var netwix = new HttpClient { BaseAddress = new Uri(baseUrl), Timeout = TimeSpan.FromMinutes(15) };
netwix.DefaultRequestHeaders.Add("X-Ingest-Token", token);
netwix.DefaultRequestHeaders.Accept.ParseAdd("application/json");

Console.WriteLine($"NetwixSync → {baseUrl}  (source={source}, limit={limit}{(loop > 0 ? $", loop {loop}s" : "")})");

if (loop > 0)
{
    Console.WriteLine("Loop mode: polling continuously. Press Ctrl+C to stop.\n");
    while (true)
    {
        try { await RunOnce(); }
        catch (Exception ex) { Console.WriteLine($"[{Stamp()}] cycle error: {ex.Message}"); }
        await Task.Delay(TimeSpan.FromSeconds(loop));
    }
}

return await RunOnce() ? 0 : 1;

// ── one polling cycle: fetch the worklist and mirror everything on it ──
async Task<bool> RunOnce()
{
    List<PendingItem> pending;
    try
    {
        var body = await netwix.GetStringAsync($"/api/ingest/pending?source={source}&limit={limit}");
        pending = JsonSerializer.Deserialize<PendingResponse>(body, jsonOpts)?.Items ?? new();
    }
    catch (Exception ex)
    {
        Console.Error.WriteLine($"[{Stamp()}] cannot reach NetWix ingest API: {ex.Message}");
        return false;
    }

    if (pending.Count == 0)
    {
        Console.WriteLine($"[{Stamp()}] up to date — nothing to mirror.");
        return true;
    }

    Console.WriteLine($"[{Stamp()}] mirroring {pending.Count} episode(s)…");
    int ok = 0, fail = 0, i = 0;
    foreach (var item in pending)
    {
        i++;
        string flag = item.Requested ? $"★[ลูกค้าขอ {item.Requests}×] " : "";
        string tag = $"[{i}/{pending.Count}] {flag}{Trim(item.Title, 30)} ตอนที่ {item.Number}";
        if (await MirrorEpisode(item.SourceKey, item.Number, tag)) ok++;
        else { Console.WriteLine($"  ✗ {tag} — ข้ามไปก่อน (จะลองใหม่รอบถัดไป)"); fail++; await ReportFailed(item.Episode_Id); }
    }
    Console.WriteLine($"[{Stamp()}] done: mirrored {ok}, failed {fail}.");
    return true;
}

// ── rongyok resolve: visit the watch page first (session cookie), then get_video.php ──
async Task<string?> ResolveVideoUrl(string seriesId, int ep)
{
    string watch = $"https://rongyok.com/watch/?series_id={seriesId}&ep={ep}";
    try { await rong.GetAsync(watch); } catch { /* best-effort session */ }

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

// Resilient per-episode mirror: RE-RESOLVE a fresh URL on every attempt (rongyok's Discord links
// expire, so retrying the same URL is useless) with a small backoff.
async Task<bool> MirrorEpisode(string seriesId, int ep, string tag)
{
    string tmp = Path.Combine(Path.GetTempPath(), $"netwixsync_{seriesId}_{ep}.mp4");
    for (int attempt = 1; attempt <= retries; attempt++)
    {
        try
        {
            string? url = await ResolveVideoUrl(seriesId, ep);   // fresh session + fresh URL
            if (url is null) throw new Exception("หา URL ไม่เจอ");

            long bytes = await Download(url, tmp);
            await Upload(seriesId, ep, tmp);
            TryDelete(tmp);
            Console.WriteLine($"  ✓ {tag} — {bytes / 1024 / 1024.0:0.0} MB{(attempt > 1 ? $" (ลอง {attempt} ครั้ง)" : "")}");
            return true;
        }
        catch (Exception ex)
        {
            TryDelete(tmp);
            if (attempt >= retries) { Console.WriteLine($"     ↳ {Trim(ex.Message, 70)}"); return false; }
            await Task.Delay(1000 * attempt); // 1s, 2s, 3s… then re-resolve
        }
    }
    return false;
}

async Task<long> Download(string url, string path)
{
    using var resp = await rong.GetAsync(url, HttpCompletionOption.ResponseHeadersRead);
    resp.EnsureSuccessStatusCode();
    await using var fs = File.Create(path);
    await resp.Content.CopyToAsync(fs);
    return new FileInfo(path).Length;
}

// Tell NetWix we couldn't mirror this one, so it backs it off / eventually drops it.
async Task ReportFailed(long episodeId)
{
    try { await netwix.PostAsync($"/api/ingest/episode/{episodeId}/failed", null); }
    catch { /* best-effort */ }
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
static string Stamp() => DateTime.Now.ToString("HH:mm:ss");

// ── DTOs ──
record PendingResponse(int Count, List<PendingItem> Items);
record PendingItem(long Episode_Id, string Source, string Source_Key, int Number, string Title, bool Requested = false, int Requests = 0)
{
    public string SourceKey => Source_Key;
}
