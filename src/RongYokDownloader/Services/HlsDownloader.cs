using System.Diagnostics;
using System.IO;
using System.Net;
using System.Net.Http;
using RongYokDownloader.Models;

namespace RongYokDownloader.Services;

/// <summary>Progress tick from an HLS download: bytes so far, 0..1 fraction, current speed.</summary>
public readonly record struct HlsProgress(long ReceivedBytes, double Fraction, double SpeedBytesPerSec);

/// <summary>
/// Downloads an HLS (.m3u8) episode to a single .mp4.
///
/// wow-drama/getplay hide each MPEG-TS segment behind a ~70-byte PNG header served from TikTok's
/// image CDN, so we can't just point ffmpeg at the playlist. Instead we fetch every segment, strip
/// the PNG wrapper down to the MPEG-TS payload, concatenate the raw TS, then remux to .mp4 with a
/// stream copy (no re-encode → fast, no quality loss).
/// </summary>
public sealed class HlsDownloader
{
    private readonly HttpClient _http;

    public HlsDownloader(HttpClient? http = null)
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
            };
            _http = new HttpClient(handler) { Timeout = TimeSpan.FromSeconds(120) };
        }
        _http.DefaultRequestHeaders.UserAgent.ParseAdd(
            "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.0.0 Safari/537.36");
    }

    /// <summary>
    /// Download <paramref name="info"/> (an HLS playlist) to <paramref name="finalPath"/> (.mp4).
    /// Restarts from scratch on each call (HLS resume is segment-based; a paused job simply re-runs).
    /// </summary>
    public async Task DownloadAsync(StreamInfo info, string finalPath, IProgress<HlsProgress> progress, CancellationToken ct)
    {
        Directory.CreateDirectory(Path.GetDirectoryName(finalPath)!);
        string tsPart = finalPath + ".ts.part";
        TryDelete(tsPart);

        var segments = await GetSegmentUrlsAsync(info, ct);
        if (segments.Count == 0)
            throw new InvalidOperationException("เพลย์ลิสต์ HLS ว่างเปล่า (อาจโดนบล็อกหรือโครงสร้างเว็บเปลี่ยน)");

        long received = 0;
        var sw = Stopwatch.StartNew();
        long lastUiMs = -1000;
        long windowBytes = 0;
        long windowMs = 0;

        await using (var fs = new FileStream(tsPart, FileMode.Create, FileAccess.Write, FileShare.None, 1 << 16, useAsync: true))
        {
            for (int i = 0; i < segments.Count; i++)
            {
                ct.ThrowIfCancellationRequested();

                byte[] raw = await GetSegmentAsync(segments[i], info.Referer, ct);
                int tsStart = FindTsStart(raw);
                if (tsStart < 0) continue;                       // not a TS-bearing segment → skip

                await fs.WriteAsync(raw.AsMemory(tsStart), ct);
                received += raw.Length - tsStart;

                long nowMs = sw.ElapsedMilliseconds;
                if (nowMs - lastUiMs >= 150)
                {
                    double dt = (nowMs - windowMs) / 1000.0;
                    double speed = dt > 0 ? (received - windowBytes) / dt : 0;
                    windowBytes = received;
                    windowMs = nowMs;
                    lastUiMs = nowMs;
                    // reserve the last few % for the ffmpeg mux step
                    double frac = (i + 1) / (double)segments.Count * 0.97;
                    progress.Report(new HlsProgress(received, frac, speed));
                }
            }
            await fs.FlushAsync(ct);
        }

        ct.ThrowIfCancellationRequested();
        progress.Report(new HlsProgress(received, 0.98, 0));

        await MuxAsync(tsPart, finalPath, ct);
        TryDelete(tsPart);

        progress.Report(new HlsProgress(received, 1.0, 0));
    }

    // ------------------------------------------------------------- playlist

    private async Task<List<string>> GetSegmentUrlsAsync(StreamInfo info, CancellationToken ct)
    {
        string m3u8 = await GetStringWithRefererAsync(info.Url, info.Referer, ct);

        var baseUri = new Uri(info.Url);
        var segs = new List<string>();
        foreach (var line in m3u8.Split('\n'))
        {
            string s = line.Trim();
            if (s.Length == 0 || s[0] == '#') continue;         // comment / tag
            segs.Add(Uri.TryCreate(baseUri, s, out var abs) ? abs.ToString() : s);
        }
        return segs;
    }

    private async Task<string> GetStringWithRefererAsync(string url, string? referer, CancellationToken ct)
    {
        using var req = new HttpRequestMessage(HttpMethod.Get, url);
        if (!string.IsNullOrEmpty(referer)) req.Headers.Referrer = new Uri(referer);
        using var resp = await _http.SendAsync(req, ct);
        resp.EnsureSuccessStatusCode();
        return await resp.Content.ReadAsStringAsync(ct);
    }

    private async Task<byte[]> GetSegmentAsync(string url, string? referer, CancellationToken ct)
    {
        using var req = new HttpRequestMessage(HttpMethod.Get, url);
        if (!string.IsNullOrEmpty(referer)) req.Headers.Referrer = new Uri(referer);
        using var resp = await _http.SendAsync(req, HttpCompletionOption.ResponseHeadersRead, ct);
        resp.EnsureSuccessStatusCode();
        return await resp.Content.ReadAsByteArrayAsync(ct);
    }

    // --------------------------------------------------- PNG → TS extraction

    /// <summary>
    /// Locate the start of the MPEG-TS payload inside a segment. getplay appends the real TS after a
    /// tiny PNG whose last chunk is IEND (…49 45 4E 44 + 4-byte CRC), so TS begins 8 bytes past "IEND".
    /// Falls back to scanning for the 0x47 sync byte (validated one packet ahead). -1 = no TS found.
    /// </summary>
    private static int FindTsStart(byte[] data)
    {
        if (data.Length >= 188 && data[0] == 0x47 && data[188] == 0x47)
            return 0;   // already raw TS

        int iend = IndexOf(data, "IEND"u8);
        if (iend >= 0)
        {
            int start = iend + 8;                       // skip "IEND" + CRC32
            start = SkipToSync(data, start);
            if (start >= 0) return start;
        }

        return SkipToSync(data, 0);
    }

    /// <summary>First offset at/after <paramref name="from"/> where a TS packet chain begins.</summary>
    private static int SkipToSync(byte[] data, int from)
    {
        for (int i = Math.Max(0, from); i + 188 < data.Length; i++)
        {
            if (data[i] == 0x47 && data[i + 188] == 0x47)
                return i;
        }
        return -1;
    }

    private static int IndexOf(byte[] haystack, ReadOnlySpan<byte> needle)
    {
        for (int i = 0; i + needle.Length <= haystack.Length; i++)
        {
            bool ok = true;
            for (int j = 0; j < needle.Length; j++)
            {
                if (haystack[i + j] != needle[j]) { ok = false; break; }
            }
            if (ok) return i;
        }
        return -1;
    }

    // --------------------------------------------------------------- ffmpeg

    private static async Task MuxAsync(string tsPath, string finalPath, CancellationToken ct)
    {
        string ffmpeg = FfmpegLocator.ResolvePath();
        string tmpOut = finalPath + ".mux.mp4";
        TryDelete(tmpOut);

        var psi = new ProcessStartInfo
        {
            FileName = ffmpeg,
            UseShellExecute = false,
            CreateNoWindow = true,
            RedirectStandardError = true,
            RedirectStandardOutput = true,
        };
        // -c copy = remux without re-encoding; aac_adtstoasc fixes AAC coming out of MPEG-TS.
        foreach (var a in new[] { "-y", "-loglevel", "error", "-i", tsPath, "-c", "copy",
                                  "-bsf:a", "aac_adtstoasc", "-movflags", "+faststart", tmpOut })
            psi.ArgumentList.Add(a);

        Process proc;
        try
        {
            proc = Process.Start(psi) ?? throw new InvalidOperationException("start failed");
        }
        catch (Exception ex)
        {
            throw new InvalidOperationException(
                "เรียก ffmpeg ไม่สำเร็จ — ต้องมี ffmpeg.exe (แถมมากับโปรแกรม หรือใน PATH). " + ex.Message);
        }

        string err = await proc.StandardError.ReadToEndAsync(ct);
        await proc.WaitForExitAsync(ct);

        if (proc.ExitCode != 0 || !File.Exists(tmpOut))
        {
            TryDelete(tmpOut);
            throw new InvalidOperationException("รวมไฟล์วิดีโอด้วย ffmpeg ไม่สำเร็จ: " +
                (string.IsNullOrWhiteSpace(err) ? $"exit {proc.ExitCode}" : err.Trim()));
        }

        if (File.Exists(finalPath)) File.Delete(finalPath);
        File.Move(tmpOut, finalPath);
    }

    private static void TryDelete(string path)
    {
        try { if (File.Exists(path)) File.Delete(path); } catch { /* ignore */ }
    }
}
