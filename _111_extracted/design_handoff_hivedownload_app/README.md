# Handoff: Hivedownload — Mobile App (8 screens)

> ภาษาไทย + English — copy in the app is bilingual (Thai primary, English secondary). This README is in English with the exact Thai/English copy quoted per screen.

## Overview
Hivedownload is a mobile app for streaming and downloading **series & movies** in both **vertical (แนวตั้ง / short-drama)** and **horizontal (แนวนอน)** formats. Core product promises, which the UI must reinforce everywhere:
- **Watch free** (ดูฟรี) — no annoying ads (ไม่มีโฆษณากวนใจ).
- **No coins per episode** (ไม่ต้องหยอดเหรียญดูทีละตอน) — all episodes are watchable free.
- **Offline download** available on **Pro** (โหลดเก็บดูออฟไลน์) — **129 THB / month**.
- Largest all-genre library, vertical + horizontal.

This bundle contains **8 mobile screens**: Onboarding, Home/Discover, Content Preview, Downloads/Offline, Go Pro, What's New, Menu/Settings, and Series Playback.

## About the Design Files
`Hivedownload Mobile.dc.html` (+ `support.js`) is a **design reference created in HTML** — a prototype showing the intended look and behaviour, laid out as a design board of 8 phone frames on a dark canvas. It is **not production code to copy directly**. The task is to **recreate these designs in the target codebase's environment** (React Native, Flutter, SwiftUI, Jetpack Compose, etc.) using its established patterns, navigation, and component libraries. If no environment exists yet, pick the framework best suited to a cross-platform streaming app (React Native or Flutter recommended) and implement there.

Open the HTML file in a browser to inspect exact pixels, or read the tokens/specs below (self-sufficient).

## Fidelity
**High-fidelity (hifi).** Final colors, typography, spacing, iconography style, and interaction intent are specified. Recreate pixel-faithfully, then adapt to real device safe-areas and OS conventions. Placeholder poster/artwork areas use CSS gradient "key-art" stand-ins — replace with real title artwork.

---

## Design Tokens

### Color — surfaces (warm, near-black)
| Token | Value | Use |
|---|---|---|
| board / app bg | `#0d0b08` | outermost canvas |
| screen base | `#14110b` | phone screen base (with glows layered on top, see below) |
| bezel gradient | `linear-gradient(160deg,#2a2117,#100d09)` | phone frame |
| text primary | `#F5EEDF` | headings, key text (warm cream) |
| text secondary | `#c9bfa9` | body |
| text muted | `#9a8f79` | captions |
| text faint | `#8a8069` / `#7a7260` | meta, inactive |
| hairline | `rgba(255,255,255,.06)`–`.1` | borders/dividers |

**Screen background** is layered (adds ambient depth), not flat:
```
radial-gradient(135% 78% at 50% -12%, <accent.softGlow>, transparent 56%),
radial-gradient(85% 55% at 108% 106%, rgba(124,224,211,.07), transparent 52%),
#14110b
```

### Color — accent (honey; default theme "honey")
| Token | Value |
|---|---|
| accent gradient (`g`) | `linear-gradient(135deg,#FFD766 0%,#F5A623 55%,#E07B00 100%)` |
| accent gem (faceted) | `conic-gradient(from 208deg at 50% 42%, #FFEEBC, #F5A623 22%, #A85400 44%, #FFD766 60%, #E07B00 80%, #FFEEBC)` |
| accent solid | `#F5A623` |
| accent soft (fill) | `rgba(245,166,35,.14)` |
| accent glow (shadow) | `rgba(245,166,35,.5)` |
| accent softGlow (ambient) | `rgba(245,166,35,.18)` |
| on-accent text | `#2a1c05` |

Two alternate themes exist as tweaks (not required for v1):
- **amber**: solid `#F2830E`, on `#2a1704`, gradient `linear-gradient(135deg,#FFC061,#F2830E 55%,#C85E00)`.
- **sunset**: solid `#F2705A`, on `#2a0d10`, gradient `linear-gradient(135deg,#FFCE7A,#F2705A 50%,#D6456B)`.
Background tone also has variants: warm `#14110b`, ink `#0f1216`, black `#0a0a0a`.

### Cinematic "key-art" poster fills (placeholders for real artwork)
```
poster:  radial-gradient(118% 92% at 22% 10%, rgba(255,192,84,.55), transparent 52%),
         radial-gradient(105% 88% at 90% 94%, rgba(118,208,255,.32), transparent 50%),
         linear-gradient(155deg,#241a12,#0e0b08)
posterB: radial-gradient(120% 92% at 82% 12%, rgba(140,232,214,.5), transparent 52%),
         radial-gradient(112% 92% at 10% 96%, rgba(255,118,152,.34), transparent 50%),
         linear-gradient(150deg,#121a1c,#0b0b0c)
posterC: radial-gradient(120% 92% at 24% 16%, rgba(192,150,255,.5), transparent 52%),
         radial-gradient(112% 92% at 92% 92%, rgba(255,182,92,.34), transparent 52%),
         linear-gradient(150deg,#181425,#0c0a10)
avatar:  radial-gradient(78% 66% at 50% 28%, rgba(255,214,152,.62), transparent 60%),
         linear-gradient(160deg,#4a3a24,#241a12)
```

### Glass card
```
background: linear-gradient(180deg, rgba(255,255,255,.085), rgba(255,255,255,.02));
border: 1px solid rgba(255,255,255,.1);
box-shadow: inset 0 1px 0 rgba(255,255,255,.14), 0 12px 30px -16px rgba(0,0,0,.75);
```

### Typography
- **Display / headings / numerals**: `Bai Jamjuree` (500/600/700) — geometric, techy, covers Thai + Latin.
- **Body / labels**: `Anuphan` (400/500/600/700) — clean, covers Thai + Latin.
- Both from Google Fonts. Type scale in use: 30 (app title), 24–25 (screen hero), 19–21 (screen title), 16 (section), 13–15 (body/buttons), 10–12 (meta), 8–10 (badges/nav labels). Letter-spacing `-.01em`/`-.02em` on large display only.

### Radius / geometry
- Phone frame radius 48px (padding 11px), screen radius 38px.
- Cards/media 12–18px; chips/pills 100px (fully round); buttons 16px.
- **Hexagon motif** (brand): flat-side clip-path `polygon(50% 0,100% 25%,100% 75%,50% 100%,0 75%,0 25%)`. Used for logo, avatars, nav icons, category/badge accents, "gem" crests. Hero hexes use the **gem** conic-gradient + glow shadow for a faceted "crystal / diamond" (ผลึกเพชร) look.

### Shadows
- Phone: `0 34px 70px -24px rgba(0,0,0,.85), inset 0 0 0 1px rgba(255,255,255,.06)`.
- Media cards: `0 12px 26px -14px rgba(0,0,0,.75)`.
- Accent buttons: `0 12px 26px -8px <accent.glow>`.
- Gem crests: `0 16px 36px -10px <accent.glow>`.

### Status bar (every screen, top ~50px)
Time `9:41` (Bai Jamjuree 700/14, `#F5EEDF`) left; centered dynamic-island pill 88×25 `#000` radius 16; right: 4 signal bars + battery outline (16×11, 1.5px border, ~80% fill). Replace with real OS status bar in implementation.

### Bottom nav (Home, Downloads screens; 66px)
`rgba(14,11,7,.92)`, top border `rgba(255,255,255,.06)`. 4 items, each = hexagon icon (19×21) + Thai label (Anuphan 600, 8px). Active: icon `#F5A623`, label `#F5EEDF`; inactive: icon `#5a5346`, label `#7a7260`. Items: **หน้าแรก · สำรวจ · ดาวน์โหลด · เมนู**.

---

## Screens / Views

Phone content area is 320px wide × 664px tall (design units). Scale to device width, respect safe areas.

### 01 — Onboarding · เริ่มต้นใช้งาน
- **Purpose**: First-run pitch + entry.
- **Layout**: hero hex cluster (faceted gem + 3 crystal facets, ambient blurred glow behind), 3-dot pager (first active, accent), headline, subhead, primary + secondary buttons stacked.
- **Copy**: H2 `ดูฟรีทุกเรื่อง / ไม่มีโฆษณากวนใจ`; accent line `Series & movies — free, no ads.`; sub `แนวตั้ง–แนวนอน ทุกประเภท ครบที่สุด · ไม่ต้องหยอดเหรียญ / โหลดเก็บดูออฟไลน์ได้ Pro เพียง 129฿/เดือน`.
- **Buttons**: primary `เริ่มเลย · Get Started` (accent gradient, on-accent text, 54px, radius 16, glow shadow); secondary `เข้าสู่ระบบ · Sign in` (transparent, 1px `rgba(255,255,255,.12)` border, 50px).

### 02 — Home / Discover · หน้าแรก
- **Purpose**: Browse free content.
- **Layout**: greeting row (`สวัสดีตอนบ่าย · Good afternoon` / `สวัสดี, พลอย 🐝`) + hex avatar; search field `ค้นหาซีรีส์ หนัง · Search series, movies…`; category chips (active = accent gradient): **ทั้งหมด · All / แนวตั้ง · Vertical / หนัง · Movies / ซีรีส์ · Series**; section **แนวตั้ง · Vertical** + `ดูฟรี` badge + `ทั้งหมด ›`; horizontal rail of **portrait cards** 86×122 radius 13 (poster fills), each with top-left free/new badge and bottom-left episode-count badge (`80 ตอน`, `EP 12`, `60 ตอน`), title below (รักซ่อนเร้น / แค้นรักซีอีโอ / ตำนานรัก); section **หนังใหม่ · New movies** with a wide 16:9 featured card (posterC, left-dark gradient overlay, badges `ดูฟรี` + `ไม่มีโฆษณา`, title `Midnight City`, meta `2026 · แอ็กชัน · HD · แนวนอน`, round accent play button 44px). Bottom nav (Home active).

### 03 — Content Preview · ดูตัวอย่าง
- **Purpose**: Preview a title, then download. Reinforces "preview first" + free.
- **Layout**: 16:9 player placeholder (poster) with back button, `ตัวอย่าง · PREVIEW` pill (accent), centered play button (58px), scrubber at 38% + timecodes `04:36 / 12:04`; title `Neon Dreams — Full Set`; meta `1080p · 214 MB · 12:04 · MP4`; **Quality** chips `480p / 720p(selected, accent outline) / 1080p (PRO badge)`; **Offline** glass row with toggle + PRO badge (offline = Pro); primary CTA `ดาวน์โหลด · Download 720p` (download-arrow glyph, accent, 56px), secondary `เล่นตัวอย่างเต็ม · Play full preview`.

### 04 — Downloads / Offline · ดาวน์โหลด
- **Purpose**: Manage downloads; upsell offline (Pro).
- **Layout**: title `ดาวน์โหลด · Downloads`; storage glass card `พื้นที่จัดเก็บ · Storage` `18.2 / 64 GB` with 28% accent bar; tabs `กำลังโหลด (active, accent underline) · เสร็จแล้ว · ออฟไลน์`; **active item** = hex thumb + `Neon Dreams — Full Set` + 62% accent progress + `62% · 4.2 MB/s` + `132 / 214 MB` + pause button; **queued item** (dimmed) `Lo-fi Study Pack` 12% neutral bar `รอคิว · Queued`; **Pro unlock banner** (accent soft, accent-glow border) hex ★ + `ปลดล็อกออฟไลน์ · Unlock Offline` / `เก็บไฟล์ได้ไม่จำกัดด้วย Pro`. Bottom nav (Downloads active).

### 05 — Go Pro · สมัคร Pro
- **Purpose**: Monthly subscription. 129 THB/mo.
- **Layout**: top accent wash; gem ★ crest (floating); title `Hivedownload Pro`; sub `ปลดล็อกทุกอย่าง · Unlock everything`; benefit list (accent-soft check circles): `โหลดออฟไลน์ไม่จำกัด · Unlimited offline`, `ไม่มีโฆษณา ไม่ต้องหยอดเหรียญ · No ads, no coins`, `4K/HDR แนวตั้ง–แนวนอน ครบทุกเรื่อง`; **plan card** (accent-outline, `ยอดนิยม · POPULAR` tab) `รายเดือน · Monthly` **฿129 /เดือน**; secondary row `รายปี · Yearly` `ประหยัด 36%` **฿990**; CTA `สมัคร Pro · Start Pro`; fine print `ยกเลิกได้ทุกเมื่อ · Cancel anytime`.

### 06 — What's New / Update · อัปเดต
- **Purpose**: Release notes / update prompt.
- **Layout**: gem hex crest (down-arrow, floating, glow); title `มีอะไรใหม่ · What's New`; version pill `v4.2.0` + `1 ก.ค. 2026`; changelog (hex bullets): `ตัวอย่างเต็มรูปแบบ · Full-screen previews`, `ออฟไลน์เร็วขึ้น 2 เท่า · 2× faster offline`, `แก้บั๊กและปรับปรุง · Fixes & polish`; CTA `อัปเดตเลย · Update now · 24 MB`; text link `ภายหลัง · Later`.

### 07 — Menu / Settings · เมนู (bilingual)
- **Purpose**: Account + settings; **shows Thai + English together**.
- **Layout**: profile glass card (hex avatar, `พลอย จันทรา`, `Ploy Chantra · แผนฟรี Free`, `Pro` chip); **Language row** (accent soft) `ภาษา · Language` with a TH|EN segmented toggle (ไทย active); menu list rows, each **bilingual** (Thai bold + English muted) with hex icon + chevron/value: `บัญชี · Account`, `พื้นที่จัดเก็บ · Storage` (value `18.2 GB`), `การแจ้งเตือน · Notifications`, `เกี่ยวกับ · About`; bottom **upgrade banner** (accent gradient) `อัปเกรดเป็น Pro` / `Go Pro · ฿129/เดือน`.

### 08 — Series Playback · เล่นซีรีส์
- **Purpose**: Watch an episode; browse the episode list.
- **Layout**: full-width **video player** (posterB) extending under status bar, top-left back, top-right HD + fullscreen, center transport (prev / 58px accent play-pause / next), bottom scrubber at 44% `18:22 / 41:50`; below: title `Neon Dreams`, `ซีซั่น 1 · ตอนที่ 3 · S1 · EP3` (accent), `ดราม่า · 2026 · 8 ตอน`, hex **ดาวน์โหลด** action; **Episodes** header `ตอนทั้งหมด · Episodes` + `ซีซั่น 1 ▾`; episode rows (64×40 thumb + title + meta): EP1 `1. คืนแรก` `ดูจบแล้ว · Watched · 38m` (check, dimmed), EP2 `2. เงาสะท้อน` `42m · 320 MB`, **EP3 now-playing** (accent-soft highlight, 44% progress, `กำลังเล่น`), EP4 `4. ปลายทาง` `45 นาที · ดูฟรี` + `โหลด·Pro` badge. **All episodes are free to watch; only download is Pro.**

---

## Interactions & Behavior
- **Navigation**: bottom tab bar (หน้าแรก / สำรวจ / ดาวน์โหลด / เมนู). Cards → Content Preview (03) or Series Playback (08). Preview/Download CTAs → download flow. Go Pro reachable from offline locks, menu banner, Pro badges.
- **Video**: play/pause toggles center transport; scrubber draggable; prev/next episode; autoplay-next recommended; fullscreen; **vertical player** for แนวตั้ง titles should be a full-screen portrait variant of screen 08 (swipe up = next episode) — not yet designed, flagged as next step.
- **Downloads**: item states = queued → downloading (live % + speed) → paused → complete → offline-available. Progress bar animates; pause/resume.
- **Offline gating**: watching is always free & ad-free; **download/offline requires Pro (129 THB/mo)**. Locked download actions open Go Pro (05).
- **Language**: TH|EN toggle in Menu sets primary language; labels shown bilingually throughout. Persist choice.
- **Motion**: hero gem crests use a gentle float (`translateY 0→-6px`, 5s ease-in-out, infinite). Buttons: press/scale + accent glow. Keep transitions ~150–250ms ease.

## State Management
- `language`: `'th' | 'en'` (default th) — persisted.
- `theme.accent`: `'honey' | 'amber' | 'sunset'` (default honey); `theme.bgTone`: `'warm' | 'ink' | 'black'` (default warm). (These are design tweaks; ship honey/warm unless product wants theming.)
- `subscription`: `'free' | 'pro'` — gates download/offline.
- `downloads[]`: `{ id, title, status: queued|downloading|paused|done, progress, speed, sizeMB, offline }`.
- `player`: `{ titleId, episodeId, positionSec, durationSec, playing, quality }` — persist last position per title.
- Catalog data: titles with `format: 'vertical' | 'horizontal'`, `type: 'series' | 'movie'`, genres, episodes, artwork.

## Assets
- **Fonts**: Google Fonts `Bai Jamjuree`, `Anuphan` (bundle or link).
- **Artwork**: all poster/thumbnail/avatar/player areas are **CSS gradient placeholders** — replace with real title artwork (portrait for vertical, 16:9 for horizontal) and user avatars.
- **Icons**: drawn with CSS/box-shape primitives (play/pause/download/search/battery/signal/lock/check/chevron). Replace with the codebase's icon set; keep the **hexagon** brand motif for logo, nav, avatars, and gem crests.
- **Logo**: hexagon "gem" with a download arrow. **No brand logo file was provided** — if the client supplies the real Hivedownload logo, re-tint the accent palette to match it (all accent tokens are centralized).

## Files
- `Hivedownload Mobile.dc.html` — the 8-screen design board (open in a browser to inspect). Requires `support.js` beside it.
- `support.js` — runtime for the HTML prototype (reference only; do not port).
