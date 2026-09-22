// gen-hero-placeholder.mjs — writes a small, warm-gradient 1920x1080 JPEG placeholder for the
// landing hero at src/assets/landing/harmandir-sahib-sunset.jpg. The OWNER replaces this file
// later with a real artistic rendering of Sri Harmandir Sahib at sunset; the FILENAME stays the
// same so index.astro's `import` and the alt text keep working. Idempotent: run
//   node scripts/gen-hero-placeholder.mjs
// Requires sharp (already a project dependency).
import sharp from "sharp";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";

const here = dirname(fileURLToPath(import.meta.url));
const out = join(here, "..", "src", "assets", "landing", "harmandir-sahib-sunset.jpg");

const W = 1920, H = 1080;
// A warm dusk gradient (deep ink → amber → soft gold) with a low glow near the horizon — a
// placeholder that reads as "sunset over water" without depicting anything, and stays tiny.
const svg = `<svg xmlns="http://www.w3.org/2000/svg" width="${W}" height="${H}">
  <defs>
    <linearGradient id="sky" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0%" stop-color="#1a120a"/>
      <stop offset="38%" stop-color="#3a2410"/>
      <stop offset="64%" stop-color="#8a5a18"/>
      <stop offset="82%" stop-color="#c98a2a"/>
      <stop offset="100%" stop-color="#e6ad45"/>
    </linearGradient>
    <radialGradient id="sun" cx="50%" cy="72%" r="42%">
      <stop offset="0%" stop-color="#ffd77a" stop-opacity="0.9"/>
      <stop offset="45%" stop-color="#f2b24d" stop-opacity="0.35"/>
      <stop offset="100%" stop-color="#f2b24d" stop-opacity="0"/>
    </radialGradient>
  </defs>
  <rect width="${W}" height="${H}" fill="url(#sky)"/>
  <rect width="${W}" height="${H}" fill="url(#sun)"/>
  <rect y="${Math.round(H * 0.78)}" width="${W}" height="${Math.round(H * 0.22)}" fill="#120c07" opacity="0.42"/>
</svg>`;

await sharp(Buffer.from(svg)).jpeg({ quality: 70, mozjpeg: true }).toFile(out);
console.log("wrote", out);
