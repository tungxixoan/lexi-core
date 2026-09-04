# SP-8: App icon / logo (both platforms)

**Date:** 2026-09-04
**Status:** approved (autonomous execution per user instruction "Chạy tuần tự đến SP cuối cùng không cần hỏi lại")

Neither the Flutter app (Android / iOS / Flutter-web scaffold) nor the React
web app has a real icon — both ship the framework default. SP-8 gives both a
LexiCore icon derived from the existing **Bloom leaf mark**.

## The mark

The Bloom design system's brand mark (already drawn in-app by
`BloomLeafMark` in `lib/core/theme/bloom/bloom_labels.dart` and by
`.brand .leaf` in `apps/web/src/styles/bloom.css`):

- a rounded square, **three corners fully rounded (pill radius)** and the
  **bottom-right corner nearly sharp (~4px / ~6% radius)** — a stylised leaf/petal,
- filled with a **top-left → bottom-right linear gradient from `--accent`
  `#C9587A` to `--sage` `#6F9A87`** (`BloomGradients.leafMark`).

## Icon composition

Master art is authored once as SVG, at 1024×1024:

- **Standard icon** (`assets/branding/icon-master.svg`, 1024²): the leaf mark
  centred at ~62% of the canvas (≈634px), on a solid warm-cream ground
  `#FFF3EE` (`--bg-a`). A very subtle rounded-square clip is NOT applied here —
  the platform tooling rounds it.
- **Maskable / adaptive foreground** (`assets/branding/icon-foreground.svg`,
  1024²): the same leaf, smaller (~44%, ≈450px) and centred, on a
  **transparent** ground — so it survives Android's adaptive safe-zone crop
  and iOS/PWA masking. The adaptive **background** is the flat `#FFF3EE`.
- **Favicon**: the standard icon works down to 32px; at 16px the cream ground
  + leaf still reads. No separate favicon art.

Colour values are copied from `bloom.css` `:root` — if a Bloom token changes,
regenerate.

## Deliverables

### Flutter (`flutter_launcher_icons`)

Add `flutter_launcher_icons` as a dev dependency + a `flutter_launcher_icons.yaml`
config, run `dart run flutter_launcher_icons`. It regenerates from the master PNG:

- **Android**: `android/app/src/main/res/mipmap-*/ic_launcher.png` (legacy) +
  adaptive (`mipmap-anydpi-v26/ic_launcher.xml`, `ic_launcher_foreground`,
  a `@color/ic_launcher_background` = `#FFF3EE`).
- **iOS**: the full `ios/Runner/Assets.xcassets/AppIcon.appiconset/` set
  (icons have no alpha — the cream ground fills the square).
- **Flutter web**: `web/icons/Icon-192.png`, `Icon-512.png`,
  `Icon-maskable-192.png`, `Icon-maskable-512.png`, `web/favicon.png`.
- `web/manifest.json` `"theme_color"` / `"background_color"` set to `#FFF3EE`;
  `web/index.html` already links the icons — leave those links.

Config uses `adaptive_icon_background: "#FFF3EE"`,
`adaptive_icon_foreground: assets/branding/icon-foreground.png`,
`image_path: assets/branding/icon-master.png`,
`web: { generate: true, background_color: "#FFF3EE", theme_color: "#FFF3EE" }`.

### React web (`apps/web/`, Next.js App Router)

- `apps/web/src/app/icon.svg` — the master SVG (Next serves it as the favicon
  automatically, no `<link>` needed).
- `apps/web/src/app/apple-icon.png` — 180×180 (Next serves as
  `apple-touch-icon`).
- `apps/web/public/icon-192.png`, `icon-512.png`, `icon-maskable-512.png` —
  PWA icons.
- `apps/web/src/app/manifest.ts` — a Next `MetadataRoute.Manifest` with
  `name: "LexiCore"`, `short_name: "LexiCore"`, `theme_color: "#FFF3EE"`,
  `background_color: "#FFF3EE"`, `display: "standalone"`, the 3 icons
  (192 any, 512 any, 512 maskable).
- `apps/web/src/app/layout.tsx` — if it has a `metadata` export, ensure
  `title`/`description` are LexiCore-appropriate; add nothing icon-specific
  (the file-based conventions cover it).

## Rasterisation

`apps/web/node_modules/sharp` is available. A one-off Node script
(`scripts/gen-icons.mjs`, run with `node`) rasterises the two master SVGs to:
- `assets/branding/icon-master.png` (1024²) + `icon-foreground.png` (1024²) for `flutter_launcher_icons`,
- the 3 `apps/web/public/*.png` + `apps/web/src/app/apple-icon.png`.
The script is committed (reproducible) but is not part of any build.

## Non-goals

- No wordmark / logotype — just the icon.
- No animated / splash-screen work (Flutter's native splash is separate; not
  touched).
- No store listing art (feature graphic, screenshots).
- No change to `BloomLeafMark` / `.brand .leaf` in-app rendering.

## Testing / acceptance

- `flutter build web --release` succeeds and `build/web/icons/` has the new PNGs.
- `flutter analyze` unaffected (0). No new Dart code.
- `apps/web`: `npm run build` succeeds; `/icon.svg`, `/apple-icon.png`,
  `/manifest.webmanifest` resolve; `npm run typecheck` clean; `npm test` green
  (no test touches icons — count unchanged).
- Android/iOS: the generated resource files are present and well-formed
  (`ic_launcher.xml` references the two adaptive layers; `Contents.json` lists
  every size). A full native build is not run in this environment — the
  `flutter_launcher_icons` output is deterministic and its own tests cover
  correctness.
- Commit the two SVGs, the two master PNGs, `scripts/gen-icons.mjs`,
  `flutter_launcher_icons.yaml`, the regenerated platform assets, the web
  icon/manifest files, and the `pubspec.yaml` / `pubspec.lock` dep bump.
