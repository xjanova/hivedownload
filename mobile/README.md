# Hive Download — Mobile (Flutter)

Streaming app for series/short-dramas from **rongyok.com**, built from the
`design_handoff_hivedownload_app` spec and sharing the desktop app's scraping
logic. **Everything is free to watch (streaming only — no downloads).**

- **Free**: watch every title/episode, with ads.
- **Pro — 129฿/month**: removes ads. That's the only difference. No offline/download.
- Ads are served from **`main.thaiprompt.online`** and shown only on the player
  screen for non-Pro users (rotating banner).

## Stack
Flutter 3.41.7 · `provider` · `dio` · `video_player` · `cached_network_image` ·
`google_fonts` (Bai Jamjuree + Anuphan) · `package_info_plus` · `ota_update`
(self-update) · `url_launcher` · `wakelock_plus`.

## Structure
```
lib/
├─ models/        series, ad, enums (DubType)
├─ services/
│   ├─ rongyok_client.dart   3 endpoints (catalog / episodes / video url) — port of C#
│   ├─ json_extract.dart     balanced-bracket JSON extractor (port of C#)
│   ├─ catalog_db.dart        SQLite cache (catalog / episodes / video-url / resume)
│   ├─ ad_service.dart        ad delivery + rotation (main.thaiprompt.online)
│   ├─ auto_updater.dart      GitHub-releases OTA + update_info.dart (version compare)
│   └─ settings_store.dart    language / Pro flag / skipped-update tag
├─ state/         app_state, catalog_state (provider)
├─ theme/         tokens, app_theme, hex (hexagon motif + gem crest)
├─ widgets/       common, poster_card, poster_image, ad_banner, update_sheet
└─ screens/       onboarding, home, catalog_grid (explore), series_detail,
                  playback, go_pro, whats_new, menu, app_shell
```

## rongyok.com API (shared with desktop)
1. `GET /category?category=all` → embedded `seriesData=[…]`
2. `GET /watch/?series_id={id}` → embedded `"episodes":[…]` + `episodes_count`
3. `GET /watch/get_video.php?series_id={id}&ep={n}` (needs `Referer` +
   `X-Requested-With: XMLHttpRequest`) → `{"ok":true,"video_url":"…mp4"}`.
   CDN MP4, H.264/AAC, no DRM, links expire ~24h → resolved fresh per play.

## Local cache (SQLite via `catalog_db.dart`)
Mirrors the desktop `rongyok.db` (minus download state) so the app opens instantly
and works offline-ish:
- **series** — the whole catalog (poster/jpg URLs, metadata). Home/Explore paint
  from cache first, then refresh from rongyok in the background and upsert.
- **series_episodes** — cached episode list per series (detail opens instantly).
- **video_cache** — resolved MP4 URLs + timestamp. Reused only within a 12h TTL
  (CDN links expire ~24h) — otherwise re-resolved. We deliberately do **not**
  keep stale video links.
- **resume** — last watched position per (series, episode) → seek-to-resume on
  play + a "Continue watching · ดูต่อ" rail on Home.

Poster **image bytes** live in `cached_network_image`'s on-disk cache; the DB
stores the **links + metadata**. Settings (language / Pro / skipped-update tag)
stay in `shared_preferences`.

## Ad API — to build on main.thaiprompt.online (Laravel)
The client (`AdService`) is wired and **degrades to a silent no-op until the
endpoint exists**, so shipping now is safe. Implement:

```
GET /api/ads?app=hivedownload&placement=player[&limit=N]     (public, no auth)

200 →
{
  "success": true,
  "data": [
    {
      "id": "ad_123",
      "image_url": "https://…/banner.jpg",   // required
      "click_url": "https://…",              // optional — opened on tap
      "weight": 1,                            // optional rotation weight
      "duration_ms": 8000,                    // optional per-ad time
      "placement": "player",
      "starts_at": "…", "ends_at": null       // optional scheduling
    }
  ],
  "rotate_ms": 8000                           // default rotation interval
}
```
Matches the ecosystem envelope (`{success,data,…}`, same host as `/api/pos/*`).
Placements requested by the app today: `player`, `home`.
Pro users are never shown ads (gated client-side in `AdBanner` on `!isPro`).

## Build & run
```bash
flutter pub get
flutter run                     # debug on a connected device
flutter build apk --release     # signed release (see below)
```

## Release / auto-update (GitHub Actions → GitHub Releases → in-app OTA)
`mobile/pubspec.yaml` `version: X.Y.Z+B` is the **single source of truth**:
`versionName = X.Y.Z`, `versionCode = B`, git tag `vX.Y.Z+B`.

**The version walks by itself.** Every merge to `main` auto-releases:
`.github/workflows/auto-version-bump.yml` reads the PR's `release:*` label
(default `patch`), bumps pubspec + `build+1`, pushes tag `vX.Y.Z+B`, then
dispatches `android-release.yml` to build the signed APK and publish the Release.
`AutoUpdater` then offers it in-app (`ota_update`).

> Note: a tag pushed by the default `GITHUB_TOKEN` does **not** fire a tag event,
> so the bump job *dispatches* the release workflow rather than relying on the
> tag push (documented pitfall).

| PR label | bump |
|---|---|
| `release:major` | 1.2.3 → 2.0.0 |
| `release:minor` | 1.2.3 → 1.3.0 |
| `release:patch` (default) | 1.2.3 → 1.2.4 |
| `release:build` | same X.Y.Z, build+1 |
| `release:skip` | no release (docs/CI/refactor) |

**Manual overrides**
- Actions → *Auto Version Bump* → Run workflow → pick a level (no PR needed).
- Or edit `pubspec.yaml` + `git tag vX.Y.Z+B && git push origin main --tags`.

`versionCode` = `B` and always increases (build is bumped every release).
`applicationId` (`com.hivedownload`) and the signing key must **never change**
across releases, or Android won't install the update over the old app.

> One-time repo setup: create the five `release:*` labels, and ensure `main`
> allows the `github-actions[bot]` push (no blocking branch protection, or
> exempt the bot). Add the signing secrets below.

**Required GitHub Secrets** (else the APK is debug-signed and can't update users):
`RELEASE_KEYSTORE_BASE64`, `RELEASE_STORE_PASSWORD`, `RELEASE_KEY_PASSWORD`,
`RELEASE_KEY_ALIAS`.

Local signing: copy `android/key.properties.example` → `android/key.properties`,
place `upload-keystore.jks` in `android/` (both gitignored).

### Android gotchas baked in
- `proguard-rules.pro` keeps Google Play Core (Flutter deferred-components) or
  R8 release minification fails.
- `isCoreLibraryDesugaringEnabled = true` + `desugar_jdk_libs` — required by
  `ota_update`.
- `AndroidManifest.xml` declares the `ota_update` FileProvider + install receiver
  and `REQUEST_INSTALL_PACKAGES` (Android 7+ install intent).

## Disclaimer
For personal/educational viewing only. Not affiliated with rongyok.com. Users
are responsible for complying with copyright and the source site's ToS.
