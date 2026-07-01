## Summary
<!-- what & why -->

## Release
This repo **auto-releases on merge to `main`** (version walks by itself).
Add ONE label to control the bump — default is `release:patch` if none:

- [ ] `release:major` — breaking change (1.2.3 → 2.0.0)
- [ ] `release:minor` — new feature (1.2.3 → 1.3.0)
- [ ] `release:patch` — bug fix (1.2.3 → 1.2.4) — **default**
- [ ] `release:build` — build number only (same X.Y.Z, build+1)
- [ ] `release:skip` — no release (docs / CI / refactor)

> Merging bumps `mobile/pubspec.yaml`, pushes tag `vX.Y.Z+B`, builds a signed
> APK and publishes a GitHub Release. Installed apps then offer the update in-app.
