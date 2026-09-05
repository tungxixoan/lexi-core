// Generates the LexiCore app icon assets from the Bloom leaf mark.
//
//   dart run flutter_launcher_icons   # regenerate Android/iOS/Flutter-web first —
//   node scripts/gen-icons.mjs        # then this, LAST — it overwrites web/favicon.png
//                                      # with the flat favicon variant (see below).
//
// Requires `sharp` — resolved from apps/web/node_modules (the only place it is
// installed). Run from the repo root. Not part of any build; re-run whenever a
// Bloom colour token changes (values below are copied from
// apps/web/src/styles/bloom.css :root).
//
// The gradient leaf mark (accent -> sage) is the brand mark everywhere it's
// rendered at a real size — app icons, adaptive/launcher icons, the
// apple-touch icon, PWA manifest icons. At browser-favicon sizes (16-32px)
// the gradient blends into an illegible muddy blob, so the favicon
// specifically uses a FLAT single-colour rendering of the same shape — this
// is the only place that differs; BloomGradients.leafMark and the web
// `.brand .leaf` in-app renderings are untouched.
import { mkdir, writeFile } from "node:fs/promises";
import { dirname, join } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";
import { createRequire } from "node:module";

const ROOT = join(dirname(fileURLToPath(import.meta.url)), "..");
const require = createRequire(pathToFileURL(join(ROOT, "apps/web/package.json")));
const sharp = require("sharp");

// --- Bloom tokens (bloom.css :root) ---
const ACCENT = "#C9587A";
const SAGE = "#6F9A87";
const GROUND = "#FFF3EE"; // --bg-a

/** Path for the leaf mark: a square of side `s` at (x,y) with three pill
 *  corners and a near-sharp bottom-right corner (border-radius: 50% 50% 50% 6%). */
function leafPath(x, y, s) {
  const r = s / 2; // pill corners
  const rbr = s * 0.06; // bottom-right
  return [
    `M ${x + r} ${y}`,
    `L ${x + s - r} ${y}`,
    `A ${r} ${r} 0 0 1 ${x + s} ${y + r}`,
    `L ${x + s} ${y + s - rbr}`,
    `A ${rbr} ${rbr} 0 0 1 ${x + s - rbr} ${y + s}`,
    `L ${x + r} ${y + s}`,
    `A ${r} ${r} 0 0 1 ${x} ${y + s - r}`,
    `L ${x} ${y + r}`,
    `A ${r} ${r} 0 0 1 ${x + r} ${y}`,
    "Z",
  ].join(" ");
}

/** @param {{ground: string|null, leafFraction: number, fill: string}} opts */
function iconSvg({ ground, leafFraction, fill }) {
  const C = 1024;
  const s = Math.round(C * leafFraction);
  const off = (C - s) / 2;
  const bg = ground
    ? `<rect width="${C}" height="${C}" fill="${ground}"/>`
    : "";
  return `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${C} ${C}">
  ${bg}
  <path d="${leafPath(off, off, s)}" fill="${fill}"/>
</svg>`;
}

const GRADIENT_FILL = `url(#leaf)`;
const GRADIENT_DEFS = `<defs>
    <linearGradient id="leaf" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0" stop-color="${ACCENT}"/>
      <stop offset="1" stop-color="${SAGE}"/>
    </linearGradient>
  </defs>`;

function withGradientDefs(svg) {
  return svg.replace(/(<svg[^>]*>)/, `$1\n  ${GRADIENT_DEFS}`);
}

const MASTER_SVG = withGradientDefs(
  iconSvg({ ground: GROUND, leafFraction: 0.62, fill: GRADIENT_FILL }),
);
// flutter_launcher_icons adds its own 16% inset on the adaptive foreground, and
// Android crops to the ~61% safe zone — 0.72 here lands at ~0.49 of the final
// adaptive icon, comfortably inside the safe zone with clean breathing room.
const FOREGROUND_SVG = withGradientDefs(
  iconSvg({ ground: null, leafFraction: 0.72, fill: GRADIENT_FILL }),
);
// Browser-favicon sizes (16-32px): a flat single colour reads as a clean
// shape; the accent->sage gradient blends into an illegible muddy blob at
// that scale. Larger fraction (0.78) than the gradient master since there's
// no gradient "shape read" to protect by leaving extra margin.
const FAVICON_SVG = iconSvg({
  ground: GROUND,
  leafFraction: 0.78,
  fill: ACCENT,
});

async function write(path, buf) {
  const full = join(ROOT, path);
  await mkdir(dirname(full), { recursive: true });
  await writeFile(full, buf);
  console.log("wrote", path);
}

async function png(svg, size) {
  return sharp(Buffer.from(svg)).resize(size, size).png().toBuffer();
}

async function main() {
  // Master SVGs (committed, gradient — used at real sizes only).
  await write("assets/branding/icon-master.svg", MASTER_SVG);
  await write("assets/branding/icon-foreground.svg", FOREGROUND_SVG);
  await write("assets/branding/icon-favicon.svg", FAVICON_SVG);

  // Master PNGs for flutter_launcher_icons (Android/iOS/Flutter-web icons —
  // NOT the favicon, see below).
  await write("assets/branding/icon-master.png", await png(MASTER_SVG, 1024));
  await write("assets/branding/icon-foreground.png", await png(FOREGROUND_SVG, 1024));

  // React web PWA + apple-touch icons (gradient — 180px+, no legibility issue).
  await write("apps/web/public/icon-192.png", await png(MASTER_SVG, 192));
  await write("apps/web/public/icon-512.png", await png(MASTER_SVG, 512));
  await write("apps/web/public/icon-maskable-512.png", await png(FOREGROUND_SVG, 512));
  await write("apps/web/src/app/apple-icon.png", await png(MASTER_SVG, 180));

  // Favicons (flat) — Next's `icon.svg` file convention drives the browser-tab
  // favicon link; Flutter's web/favicon.png is a plain PNG. Run this script
  // AFTER `dart run flutter_launcher_icons`, which overwrites web/favicon.png
  // from the gradient master — this write must come last to win.
  await write("apps/web/src/app/icon.svg", FAVICON_SVG);
  await write("web/favicon.png", await png(FAVICON_SVG, 32));
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
