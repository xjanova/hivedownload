# ffmpeg (bundled dependency)

wow-drama episodes are delivered as HLS. The app downloads the segments, strips the
PNG wrapper getplay-cdn hides them behind, then **remuxes the raw MPEG-TS into a clean
`.mp4` with ffmpeg** (`-c copy`, no re-encode). rongyok downloads are plain MP4 and do
**not** need ffmpeg.

## How the app finds ffmpeg

`Services/FfmpegLocator.cs` looks, in order:

1. `tools\ffmpeg\ffmpeg.exe` next to the app  ← put the binary here to bundle it
2. `ffmpeg\ffmpeg.exe` next to the app
3. `ffmpeg.exe` next to the app
4. `ffmpeg` on the system `PATH`  ← fallback

So the app already works if the user has ffmpeg installed. Bundling just removes that
requirement.

## To bundle it

1. Download a static Windows build (e.g. from https://www.gyan.dev/ffmpeg/builds/ —
   "ffmpeg-release-essentials.zip", or https://github.com/BtbN/FFmpeg-Builds).
2. Copy **`ffmpeg.exe`** into this folder (`src\RongYokDownloader\tools\ffmpeg\`).
3. Rebuild — the csproj copies it next to the app automatically.

The `.exe` is git-ignored on purpose (it's ~80 MB). Ship it with the installer, not the repo.
