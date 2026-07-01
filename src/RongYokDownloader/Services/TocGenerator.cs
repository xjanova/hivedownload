using System.IO;
using System.Net;
using System.Text;
using RongYokDownloader.Models;

namespace RongYokDownloader.Services;

/// <summary>
/// Writes a self-contained <c>index.html</c> "สารบัญ" (table of contents) into each series
/// folder, listing every episode with a click-to-play link to the local .mp4.
/// </summary>
public static class TocGenerator
{
    public static async Task WriteAsync(string seriesFolder, Series series, IReadOnlyList<Episode> episodes)
    {
        Directory.CreateDirectory(seriesFolder);
        string html = Build(series, episodes);
        await File.WriteAllTextAsync(Path.Combine(seriesFolder, "index.html"), html, new UTF8Encoding(false));
    }

    private static string Build(Series series, IReadOnlyList<Episode> episodes)
    {
        string title = WebUtility.HtmlEncode(string.IsNullOrWhiteSpace(series.CleanTitle) ? series.Title : series.CleanTitle);
        string desc = WebUtility.HtmlEncode(series.Description);
        string type = WebUtility.HtmlEncode(series.TypeThai);
        int done = 0;

        var rows = new StringBuilder();
        foreach (var e in episodes.OrderBy(x => x.EpisodeNumber))
        {
            bool ok = e.Status == DownloadStatus.Completed && !string.IsNullOrEmpty(e.FilePath) && File.Exists(e.FilePath!);
            if (ok) done++;
            string file = ok ? Uri.EscapeDataString(Path.GetFileName(e.FilePath!)) : "";
            string cell = ok
                ? $"<a class=\"ep done\" href=\"{file}\">ตอนที่ {e.EpisodeNumber}</a>"
                : $"<span class=\"ep pending\">ตอนที่ {e.EpisodeNumber}</span>";
            rows.Append(cell);
        }

        return $$"""
            <!DOCTYPE html>
            <html lang="th">
            <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1">
            <title>{{title}} — สารบัญ</title>
            <style>
              :root { color-scheme: dark; }
              * { box-sizing: border-box; }
              body { margin:0; font-family:"Segoe UI","Prompt",Tahoma,sans-serif; background:#0b1220; color:#e5e7eb; }
              .wrap { max-width:960px; margin:0 auto; padding:32px 20px 64px; }
              h1 { margin:0 0 4px; font-size:26px; }
              .meta { color:#94a3b8; margin-bottom:20px; }
              .badge { display:inline-block; background:#064e3b; color:#6ee7b7; border-radius:999px; padding:2px 12px; font-size:13px; }
              .poster { float:right; width:180px; border-radius:12px; margin:0 0 16px 20px; box-shadow:0 8px 30px rgba(0,0,0,.5); }
              p.desc { color:#cbd5e1; line-height:1.7; }
              .grid { display:grid; grid-template-columns:repeat(auto-fill,minmax(110px,1fr)); gap:10px; margin-top:24px; clear:both; }
              .ep { display:flex; align-items:center; justify-content:center; height:44px; border-radius:10px; text-decoration:none; font-size:14px; transition:.15s; }
              .ep.done { background:#10b981; color:#052e1f; font-weight:600; }
              .ep.done:hover { background:#34d399; transform:translateY(-2px); }
              .ep.pending { background:#1e293b; color:#64748b; }
              footer { margin-top:40px; color:#475569; font-size:12px; }
            </style>
            </head>
            <body>
              <div class="wrap">
                <img class="poster" src="poster.jpg" alt="ปก" onerror="this.style.display='none'">
                <h1>{{title}}</h1>
                <div class="meta"><span class="badge">{{type}}</span> &nbsp; ดาวน์โหลดแล้ว {{done}} / {{series.EpisodesCount}} ตอน</div>
                <p class="desc">{{desc}}</p>
                <div class="grid">
                  {{rows}}
                </div>
                <footer>สร้างโดย RongYok Downloader · แหล่งที่มา rongyok.com</footer>
              </div>
            </body>
            </html>
            """;
    }
}
