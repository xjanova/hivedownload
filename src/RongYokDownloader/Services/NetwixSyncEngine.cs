using System.Net.Http;
using System.Net.Http.Headers;
using System.IO;
using System.Text.Json;

namespace RongYokDownloader.Services;

/// <summary>
/// Keeps NetWix's imported rongyok library mirrored onto NetWix's own storage. rongyok only
/// serves fresh video URLs to residential IPs, so this runs here (home PC): it polls NetWix's
/// "please mirror these" worklist, downloads each episode via <see cref="RongYokClient"/>, and
/// uploads the file to NetWix's ingest API. NetWix is always the passive side — this dials out
/// to it, so the home IP changing never matters.
///
/// Raises events the NetWix Sync tab binds to (connection / status / queue / log).
/// </summary>
public sealed class NetwixSyncEngine : IDisposable
{
    private static readonly JsonSerializerOptions J = new() { PropertyNameCaseInsensitive = true };

    private readonly SettingsStore _settings;
    private readonly RongYokClient _rong = new();
    private HttpClient _netwix;
    private CancellationTokenSource? _cts;

    public event Action<string>? Log;
    public event Action<bool>? ConnectionChanged;  // reachable & authenticated with NetWix
    public event Action<string>? StatusChanged;     // one-line human status
    public event Action<int>? QueueChanged;         // how many episodes NetWix still wants

    public bool IsRunning { get; private set; }

    public NetwixSyncEngine(SettingsStore settings)
    {
        _settings = settings;
        _netwix = BuildClient();
    }

    private HttpClient BuildClient()
    {
        var c = new HttpClient { Timeout = TimeSpan.FromMinutes(15) };
        var url = _settings.NetWixUrl;
        if (!string.IsNullOrWhiteSpace(url) && Uri.TryCreate(url.TrimEnd('/'), UriKind.Absolute, out var u))
            c.BaseAddress = u;
        c.DefaultRequestHeaders.Add("X-Ingest-Token", _settings.NetWixToken);
        c.DefaultRequestHeaders.Accept.ParseAdd("application/json");
        return c;
    }

    public void Start()
    {
        if (IsRunning) return;
        _netwix.Dispose();
        _netwix = BuildClient();            // pick up the latest URL/token
        _cts = new CancellationTokenSource();
        IsRunning = true;
        _ = LoopAsync(_cts.Token);
    }

    public void Stop()
    {
        _cts?.Cancel();
        IsRunning = false;
        StatusChanged?.Invoke("หยุดแล้ว");
    }

    private async Task LoopAsync(CancellationToken ct)
    {
        while (!ct.IsCancellationRequested)
        {
            try { await RunOnceAsync(ct); }
            catch (OperationCanceledException) { break; }
            catch (Exception ex) { ConnectionChanged?.Invoke(false); Log?.Invoke("ผิดพลาด: " + ex.Message); }

            try { await Task.Delay(TimeSpan.FromSeconds(Math.Max(15, _settings.NetWixInterval)), ct); }
            catch (OperationCanceledException) { break; }
        }
    }

    /// <summary>One polling cycle: pull the worklist and mirror everything on it.</summary>
    public async Task RunOnceAsync(CancellationToken ct)
    {
        if (_netwix.BaseAddress is null) { StatusChanged?.Invoke("ยังไม่ได้ตั้งค่า NetWix URL"); return; }

        List<PendingItem> items;
        try
        {
            var body = await _netwix.GetStringAsync("/api/ingest/pending?source=rongyok&limit=300", ct);
            items = JsonSerializer.Deserialize<PendingResponse>(body, J)?.Items ?? new();
            ConnectionChanged?.Invoke(true);
        }
        catch
        {
            ConnectionChanged?.Invoke(false);
            StatusChanged?.Invoke("เชื่อมต่อ NetWix ไม่ได้ (ตรวจ URL / โทเคน / อินเทอร์เน็ต)");
            throw;
        }

        QueueChanged?.Invoke(items.Count);
        if (items.Count == 0) { StatusChanged?.Invoke("อัปเดตล่าสุดแล้ว — ไม่มีงานค้าง ✓"); return; }

        int i = 0;
        foreach (var it in items)
        {
            ct.ThrowIfCancellationRequested();
            i++;
            StatusChanged?.Invoke($"NetWix สั่งโหลด {i}/{items.Count} — {it.Title} ตอนที่ {it.Number}");

            if (!int.TryParse(it.SourceKey, out var seriesId)) { Log?.Invoke($"✗ {it.Title} — id ไม่ถูกต้อง"); continue; }
            if (await MirrorEpisodeAsync(seriesId, it, ct))
            {
                Log?.Invoke($"✓ {it.Title} ตอน {it.Number}");
            }
            else
            {
                Log?.Invoke($"✗ {it.Title} ตอน {it.Number} — ข้ามไปก่อน จะลองใหม่รอบถัดไป");
                await ReportFailedAsync(it.Episode_Id, ct);
            }
        }

        StatusChanged?.Invoke("รอบนี้เสร็จ");
        QueueChanged?.Invoke(0);
    }

    /// <summary>
    /// Mirror one episode, re-resolving a FRESH video URL on every attempt — rongyok's Discord
    /// links expire, so retrying the same URL is pointless. A few attempts with backoff smooth
    /// out the source's intermittent 404s; anything still failing is left for the next cycle.
    /// </summary>
    private async Task<bool> MirrorEpisodeAsync(int seriesId, PendingItem it, CancellationToken ct)
    {
        var tmp = Path.Combine(Path.GetTempPath(), $"netwixsync_{it.SourceKey}_{it.Number}.mp4");
        const int attempts = 4;
        for (int a = 1; a <= attempts; a++)
        {
            ct.ThrowIfCancellationRequested();
            try
            {
                var url = await _rong.GetVideoUrlAsync(seriesId, it.Number, ct);
                if (string.IsNullOrEmpty(url)) throw new Exception("หา URL ไม่เจอ");

                await DownloadAsync(url, tmp, ct);
                await UploadAsync(it.SourceKey, it.Number, tmp, ct);
                try { File.Delete(tmp); } catch { /* ignore */ }
                return true;
            }
            catch (OperationCanceledException) { throw; }
            catch
            {
                try { File.Delete(tmp); } catch { /* ignore */ }
                if (a >= attempts) return false;
                try { await Task.Delay(1000 * a, ct); } catch (OperationCanceledException) { throw; }
            }
        }
        return false;
    }

    private async Task ReportFailedAsync(long episodeId, CancellationToken ct)
    {
        try { await _netwix.PostAsync($"/api/ingest/episode/{episodeId}/failed", null, ct); }
        catch { /* best-effort */ }
    }

    private async Task<long> DownloadAsync(string url, string path, CancellationToken ct)
    {
        using var resp = await _rong.GetStreamResponseAsync(url, 0, ct);
        resp.EnsureSuccessStatusCode();
        await using var fs = File.Create(path);
        await resp.Content.CopyToAsync(fs, ct);
        return new FileInfo(path).Length;
    }

    private async Task UploadAsync(string seriesId, int ep, string path, CancellationToken ct)
    {
        using var form = new MultipartFormDataContent
        {
            { new StringContent("rongyok"), "source" },
            { new StringContent(seriesId), "source_key" },
            { new StringContent(ep.ToString()), "number" },
        };
        var fileContent = new StreamContent(File.OpenRead(path));
        fileContent.Headers.ContentType = new MediaTypeHeaderValue("video/mp4");
        form.Add(fileContent, "file", $"{ep}.mp4");

        using var resp = await _netwix.PostAsync("/api/ingest/episode", form, ct);
        if (!resp.IsSuccessStatusCode)
            throw new Exception($"อัปโหลดไม่สำเร็จ HTTP {(int)resp.StatusCode}");
    }

    public void Dispose()
    {
        _cts?.Cancel();
        _netwix.Dispose();
    }

    // ── worklist DTOs (JSON is case-insensitive; underscores line up with source_key) ──
    private sealed record PendingResponse(int Count, List<PendingItem> Items);
    private sealed record PendingItem(long Episode_Id, string Source_Key, int Number, string Title)
    {
        public string SourceKey => Source_Key;
    }
}
