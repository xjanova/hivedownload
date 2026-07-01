using System.Collections.ObjectModel;
using System.Diagnostics;
using System.IO;
using System.Net;
using RongYokDownloader.Data;
using RongYokDownloader.Models;
using RongYokDownloader.ViewModels;

namespace RongYokDownloader.Services;

/// <summary>
/// Owns the download queue and runs up to N transfers at once.
/// All shared state (<see cref="Jobs"/>, active count, per-job cancellation) is only ever
/// touched on the UI thread via <see cref="Ui"/>; the actual byte-pumping happens on the
/// thread pool and reports back through the captured synchronization context.
/// </summary>
public sealed class DownloadManager
{
    private readonly RongYokClient _client;
    private readonly Db _db;
    private readonly SettingsStore _settings;

    private readonly SynchronizationContext _ui;
    private readonly int _uiThreadId;
    private readonly Dictionary<DownloadJob, CancellationTokenSource> _cts = new();
    private readonly HashSet<int> _assetsReady = new();
    private int _active;

    /// <summary>The live queue, bound directly by the Downloads view.</summary>
    public ObservableCollection<DownloadJob> Jobs { get; } = new();

    /// <summary>Raised (on the UI thread) whenever queue counts change — for summary badges.</summary>
    public event Action? Changed;

    /// <summary>Raised (on the UI thread) when an episode finishes downloading: (seriesId, episodeNumber).</summary>
    public event Action<int, int>? EpisodeCompleted;

    /// <summary>Raised (on the UI thread) when an episode download fails: (seriesId, episodeNumber).</summary>
    public event Action<int, int>? EpisodeFailed;

    public DownloadManager(RongYokClient client, Db db, SettingsStore settings)
    {
        _client = client;
        _db = db;
        _settings = settings;
        _ui = SynchronizationContext.Current ?? new SynchronizationContext();
        _uiThreadId = Environment.CurrentManagedThreadId;
    }

    private void Ui(Action a)
    {
        if (Environment.CurrentManagedThreadId == _uiThreadId) a();
        else _ui.Post(_ => a(), null);
    }

    // ------------------------------------------------------------- queue ops

    /// <summary>Queue a set of episodes for a series. Already-completed / already-queued eps are skipped.</summary>
    public void Enqueue(Series series, IEnumerable<int> episodeNumbers)
    {
        string root = _settings.DownloadRoot;
        var existing = new HashSet<int>(
            Jobs.Where(j => j.Series.Id == series.Id).Select(j => j.EpisodeNumber));

        _db.UpsertSeries(new[] { series });

        int added = 0;
        foreach (int ep in episodeNumbers.Distinct().OrderBy(n => n))
        {
            if (existing.Contains(ep)) continue;

            var db = _db.GetEpisode(series.Id, ep);
            string finalPath = FileNamer.EpisodePath(root, series, ep);
            bool alreadyDone = db?.Status == DownloadStatus.Completed
                               && !string.IsNullOrEmpty(db.FilePath) && File.Exists(db.FilePath);
            if (alreadyDone) continue;

            var job = new DownloadJob { Series = series, EpisodeNumber = ep, FilePath = finalPath };
            Jobs.Add(job);
            added++;
        }

        if (added > 0)
        {
            _ = Task.Run(() => EnsureSeriesAssetsAsync(series));
            TryPump();
        }
    }

    public void Pause(DownloadJob job)
    {
        if (job.Status is DownloadStatus.Downloading)
        {
            job.Status = DownloadStatus.Paused;
            if (_cts.TryGetValue(job, out var cts)) cts.Cancel();
        }
        else if (job.Status is DownloadStatus.Queued)
        {
            job.Status = DownloadStatus.Paused;
        }
        Changed?.Invoke();
    }

    public void Resume(DownloadJob job)
    {
        if (job.Status is DownloadStatus.Paused or DownloadStatus.Failed)
        {
            job.Error = null;
            job.Status = DownloadStatus.Queued;
            TryPump();
        }
    }

    public void Remove(DownloadJob job)
    {
        if (_cts.TryGetValue(job, out var cts)) cts.Cancel();
        Jobs.Remove(job);
        if (job.Status != DownloadStatus.Completed)
        {
            TryDelete(job.FilePath + ".part");
        }
        Changed?.Invoke();
    }

    public void PauseAll() { foreach (var j in Jobs.ToList()) Pause(j); }
    public void ResumeAll() { foreach (var j in Jobs.ToList()) Resume(j); }
    public void ClearCompleted()
    {
        foreach (var j in Jobs.Where(j => j.Status == DownloadStatus.Completed).ToList())
            Jobs.Remove(j);
        Changed?.Invoke();
    }

    // --------------------------------------------------------------- pumping

    private void TryPump()
    {
        Ui(() =>
        {
            int max = _settings.MaxConcurrentDownloads;
            foreach (var job in Jobs)
            {
                if (_active >= max) break;
                if (job.Status != DownloadStatus.Queued) continue;
                StartJob(job);
            }
            Changed?.Invoke();
        });
    }

    private void StartJob(DownloadJob job)
    {
        var cts = new CancellationTokenSource();
        _cts[job] = cts;
        _active++;
        job.Status = DownloadStatus.Downloading;
        _ = Task.Run(() => RunJobAsync(job, cts.Token));
    }

    private async Task RunJobAsync(DownloadJob job, CancellationToken ct)
    {
        try
        {
            // Always re-resolve the (signed, short-lived) CDN URL at attempt time.
            string? url = await _client.GetVideoUrlAsync(job.Series.Id, job.EpisodeNumber, ct);
            if (string.IsNullOrEmpty(url))
                throw new InvalidOperationException("ไม่พบลิงก์วิดีโอสำหรับตอนนี้ (อาจยังไม่มีไฟล์บนเซิร์ฟเวอร์)");

            await DownloadToFileAsync(job, url, ct);

            Complete(job, () =>
            {
                job.Progress = 1;
                job.SpeedBytesPerSec = 0;
                job.Status = DownloadStatus.Completed;
                job.Error = null;
                PersistJob(job);
                EpisodeCompleted?.Invoke(job.Series.Id, job.EpisodeNumber);
            });
            _ = Task.Run(() => AfterEpisodeCompletedAsync(job.Series));
        }
        catch (OperationCanceledException)
        {
            // Paused or removed — leave the .part file for resume. Just free the slot.
            Complete(job, () => PersistJob(job));
        }
        catch (Exception ex)
        {
            Complete(job, () =>
            {
                job.Status = DownloadStatus.Failed;
                job.Error = Clean(ex.Message);
                job.SpeedBytesPerSec = 0;
                PersistJob(job);
                EpisodeFailed?.Invoke(job.Series.Id, job.EpisodeNumber);
            });
        }
    }

    /// <summary>Runs <paramref name="onUi"/> on the UI thread, frees the slot and re-pumps.</summary>
    private void Complete(DownloadJob job, Action onUi)
    {
        Ui(() =>
        {
            _cts.Remove(job);
            if (_active > 0) _active--;
            onUi();
            Changed?.Invoke();
        });
        TryPump();
    }

    // ------------------------------------------------------------ the bytes

    private async Task DownloadToFileAsync(DownloadJob job, string url, CancellationToken ct)
    {
        Directory.CreateDirectory(Path.GetDirectoryName(job.FilePath)!);
        string part = job.FilePath + ".part";
        long existing = File.Exists(part) ? new FileInfo(part).Length : 0;

        using var resp = await _client.GetStreamResponseAsync(url, existing, ct);

        bool resuming = existing > 0 && resp.StatusCode == HttpStatusCode.PartialContent;
        if (existing > 0 && !resuming) existing = 0; // server ignored Range → start over
        resp.EnsureSuccessStatusCode();

        long total = resuming && resp.Content.Headers.ContentRange?.Length is long len
            ? len
            : (resp.Content.Headers.ContentLength ?? 0) + (resuming ? existing : 0);

        long received = existing;
        UiUpdate(job, received, total, 0);

        var fileMode = resuming ? FileMode.Append : FileMode.Create;
        await using (var fs = new FileStream(part, fileMode, FileAccess.Write, FileShare.None, 1 << 16, useAsync: true))
        await using (var stream = await resp.Content.ReadAsStreamAsync(ct))
        {
            var buffer = new byte[81920];
            var sw = Stopwatch.StartNew();
            long windowStartBytes = received;
            long windowStartMs = 0;
            long lastUiMs = -1000;
            int read;
            while ((read = await stream.ReadAsync(buffer, ct)) > 0)
            {
                await fs.WriteAsync(buffer.AsMemory(0, read), ct);
                received += read;

                long nowMs = sw.ElapsedMilliseconds;
                if (nowMs - lastUiMs >= 100)
                {
                    double dt = (nowMs - windowStartMs) / 1000.0;
                    double speed = dt > 0 ? (received - windowStartBytes) / dt : 0;
                    windowStartBytes = received;
                    windowStartMs = nowMs;
                    lastUiMs = nowMs;
                    UiUpdate(job, received, total, speed);
                }
            }
            await fs.FlushAsync(ct);
        }

        ct.ThrowIfCancellationRequested();

        // Atomically swap .part → final .mp4
        if (File.Exists(job.FilePath)) File.Delete(job.FilePath);
        File.Move(part, job.FilePath);

        long finalTotal = total > 0 ? total : received;
        UiUpdate(job, finalTotal, finalTotal, 0);
    }

    private void UiUpdate(DownloadJob job, long received, long total, double speed)
    {
        Ui(() =>
        {
            job.DownloadedBytes = received;
            job.TotalBytes = total;
            job.Progress = total > 0 ? Math.Clamp((double)received / total, 0, 1) : 0;
            job.SpeedBytesPerSec = speed;
        });
    }

    // --------------------------------------------------------- side assets

    private async Task EnsureSeriesAssetsAsync(Series series)
    {
        if (!_assetsReady.Add(series.Id)) return;
        try
        {
            string folder = FileNamer.SeriesFolder(_settings.DownloadRoot, series);
            Directory.CreateDirectory(folder);

            if (_settings.SavePoster && !string.IsNullOrEmpty(series.JpgUrl))
            {
                string posterPath = Path.Combine(folder, "poster.jpg");
                if (!File.Exists(posterPath))
                {
                    using var resp = await _client.GetStreamResponseAsync(series.JpgUrl, 0, CancellationToken.None);
                    if (resp.IsSuccessStatusCode)
                    {
                        await using var fs = new FileStream(posterPath, FileMode.Create, FileAccess.Write, FileShare.None);
                        await resp.Content.CopyToAsync(fs);
                        Ui(() => { series.PosterLocalPath = posterPath; _db.UpdateSeriesPosterLocal(series.Id, posterPath); });
                    }
                }
                else
                {
                    Ui(() => series.PosterLocalPath = posterPath);
                }
            }
        }
        catch { /* poster is best-effort */ }
    }

    private async Task AfterEpisodeCompletedAsync(Series series)
    {
        try
        {
            if (!_settings.WriteToc) return;
            var episodes = _db.GetEpisodes(series.Id);
            string folder = FileNamer.SeriesFolder(_settings.DownloadRoot, series);
            await TocGenerator.WriteAsync(folder, series, episodes);
        }
        catch { /* TOC is best-effort */ }
    }

    // --------------------------------------------------------------- helpers

    private void PersistJob(DownloadJob job)
    {
        _db.SaveEpisode(new Episode
        {
            SeriesId = job.Series.Id,
            EpisodeNumber = job.EpisodeNumber,
            Status = job.Status,
            FilePath = job.Status == DownloadStatus.Completed ? job.FilePath : job.FilePath + ".part",
            DownloadedBytes = job.DownloadedBytes,
            TotalBytes = job.TotalBytes,
            DownloadedAt = job.Status == DownloadStatus.Completed ? DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss") : null,
            Error = job.Error,
        });
    }

    private static void TryDelete(string path)
    {
        try { if (File.Exists(path)) File.Delete(path); } catch { /* ignore */ }
    }

    private static string Clean(string msg) => msg.Replace("Exception:", "").Trim();
}
