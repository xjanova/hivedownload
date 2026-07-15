# NetWix — Mobile (Flutter)

The official **NetWix** Android app — streams movies, series & vertical dramas
from **netwix.online** (`/api/app/*`), MP4 + HLS. **Everything is free to watch
(streaming only — no downloads).**

- **Free**: watch every title/episode, with ads.
- **Pro — 129฿/month**: removes ads. That's the only difference. No offline/download.
- Ads are served from **`main.thaiprompt.online`** and shown only on the player
  screen for non-Pro users (rotating banner).

## Stack
Flutter 3.41.7 · `provider` · `dio` · `video_player` · `cached_network_image` ·
`google_fonts` (Kanit) · `shared_preferences` · `sqflite` · `package_info_plus` ·
`ota_update` (self-update) · `flutter_web_auth_2` (web sign-in bridge) ·
`share_plus` · `url_launcher` · `wakelock_plus`.

## Structure
```
lib/
├─ models/     content, episode, member, referral, ad
├─ services/
│   ├─ netwix_api.dart     NetWix content API (/api/app/*): home, titles, detail, search, source, auth
│   ├─ netwix_client.dart  membership / coins / referral / social (/api/*)
│   ├─ auth_service.dart   web sign-in bridge (Google/LINE/email) + netwix:// deep link
│   ├─ catalog_db.dart     SQLite cache (catalog / episodes / resume)
│   ├─ ad_service.dart     ad delivery + rotation (main.thaiprompt.online)
│   ├─ auto_updater.dart   in-app OTA via netwix.online + update_info.dart (version compare)
│   └─ account_store · settings_store · reward_config · format
├─ state/      app_state, catalog_state, member_state (provider)
├─ theme/      tokens, app_theme, hex (NetWix neon)
├─ widgets/    poster_card, ad_banner, comment_sheet, referral_promo_card,
│              update_sheet, login_sheet, unlock_sheet, common
└─ screens/    onboarding, intro, home, catalog_grid (explore), series_detail,
               playback, earn_coins, reward_watch, go_pro, whats_new, menu, app_shell
```

## Content API — netwix.online (`/api/app/*`)
All content + playback come from NetWix (envelope `{success, data}`). NetWix
resolves each episode's stream **server-side on demand** — a fresh signed CDN MP4
(rongyok) or an HMAC-signed HLS proxy (wow-drama) — and the client plays the
returned URL directly, no headers, from any IP.

| purpose | endpoint |
|---|---|
| home hero + rails | `GET /api/app/home` |
| titles by type (`movie`/`series`/`vertical`, `?type=anime`) | `GET /api/app/titles` |
| detail + episodes | `GET /api/app/titles/{slug}` |
| search | `GET /api/app/search?q=` |
| resolve stream | `GET /api/app/episodes/{id}/source` → `{ ready, kind: mp4\|hls, url }` |
| member sign-in | `POST /api/app/auth/exchange` · `GET /api/app/auth/me` |

Member data (likes, ratings, my-list, comments, watch progress, coins, referral)
is served under the same host, gated by a bearer token.

## Local cache (SQLite via `catalog_db.dart`)
Caches the catalog, episode lists and resume position so the app opens instantly
and shows a **"Continue watching · ดูต่อ"** rail. Poster **bytes** live in
`cached_network_image`'s on-disk cache; the DB holds **links + metadata**.
Settings (language / Pro / skipped-update tag) stay in `shared_preferences`.

## Ad API — to build on main.thaiprompt.online (Laravel)
The client (`AdService`) is wired and **degrades to a silent no-op until the
endpoint exists**, so shipping now is safe. Implement:

```
GET /api/ads?app=netwix&placement=player[&limit=N]     (public, no auth)

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
Placements requested by the app today: `player`, `home`.
Pro users are never shown ads (gated client-side in `AdBanner` on `!isPro`).

## Build & run
```bash
flutter pub get
flutter run                     # debug on a connected device
flutter build apk --release     # signed release (see below)
```

## Release / auto-update (GitHub Actions → Release → netwix.online mirror → in-app OTA)
`mobile/pubspec.yaml` `version: X.Y.Z` is the **single source of truth** and is
**plain semver — no `+build` suffix**. `versionName = X.Y.Z`; `versionCode` is the
CI run number (always increases); git tag `vX.Y.Z`.

**The version walks by itself.** Every merge to `main` auto-releases:
`.github/workflows/auto-version-bump.yml` reads the PR's `release:*` label
(default `patch`), bumps pubspec, pushes tag `vX.Y.Z`, then dispatches
`android-release.yml` to build the signed APK and publish the Release.

The **app never talks to that Release directly.** netwix.online mirrors the new
APK to its own storage on first request, and `AutoUpdater` checks
`GET /api/app/version` and downloads `/download/apk` — both on our own domain, so
the client never contacts or reveals where the build actually lives.

> Note: a tag pushed by the default `GITHUB_TOKEN` does **not** fire a tag event,
> so the bump job *dispatches* the release workflow rather than relying on the
> tag push (documented pitfall).

| PR label | bump |
|---|---|
| `release:major` | 1.2.3 → 2.0.0 |
| `release:minor` | 1.2.3 → 1.3.0 |
| `release:patch` (default) | 1.2.3 → 1.2.4 |
| `release:skip` | no release (docs/CI/refactor) |

**Manual overrides**
- Actions → *Auto Version Bump* → Run workflow → pick a level (no PR needed).
- Or edit `pubspec.yaml` + `git tag vX.Y.Z && git push origin main vX.Y.Z`.

`applicationId` (`com.netwix.app`) and the signing key must **never change**
across releases, or Android won't install the update over the old app. (Both were
reset once, from `com.hivedownload`, for the NetWix rebrand — locked from now on.)

> One-time repo setup: create the four `release:*` labels, and ensure `main`
> allows the `github-actions[bot]` push (no blocking branch protection, or
> exempt the bot). Add the signing secrets below.

**Required GitHub Secrets** (else the APK is debug-signed and can't update users):
`RELEASE_KEYSTORE_BASE64`, `RELEASE_STORE_PASSWORD`, `RELEASE_KEY_PASSWORD`,
`RELEASE_KEY_ALIAS`.

Local signing: place `upload-keystore.jks` + `key.properties` in `android/`
(both gitignored).

### Android gotchas baked in
- `proguard-rules.pro` keeps Google Play Core (Flutter deferred-components) or
  R8 release minification fails.
- `isCoreLibraryDesugaringEnabled = true` + `desugar_jdk_libs` — required by
  `ota_update`.
- `AndroidManifest.xml` declares the `ota_update` FileProvider + install receiver
  and `REQUEST_INSTALL_PACKAGES` (Android 7+ install intent).

## Disclaimer
For personal / educational viewing only. Content is served via **netwix.online**.
