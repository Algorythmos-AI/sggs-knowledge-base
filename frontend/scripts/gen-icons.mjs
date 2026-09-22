// gen-icons.mjs — regenerate the PWA / apple-touch icons under frontend/public/icons/.
//
// A gold Ik Onkar (ੴ, U+0A74) on warm ink (#171412), matching the Gurbani Soul mark. The glyph
// is rendered through satori (so the bundled Sant Lipi font is guaranteed, independent of any
// system Gurmukhi font), rasterised with resvg, then sized/encoded with sharp. Output is
// byte-deterministic across runs. Run:  node scripts/gen-icons.mjs
import satori from 'satori';
import { Resvg } from '@resvg/resvg-js';
import sharp from 'sharp';
import { readFileSync, writeFileSync, mkdirSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const HERE = dirname(fileURLToPath(import.meta.url));
const FRONTEND = join(HERE, '..');
const OUT = join(FRONTEND, 'public', 'icons');
mkdirSync(OUT, { recursive: true });

const INK = '#171412';
const GOLD = '#FFBC0D';
const sant = readFileSync(join(FRONTEND, 'src', 'og', 'fonts', 'SantLipi-og.ttf'));

// Render the mark at `size`, with the glyph occupying `ratio` of the box (smaller ratio = more
// padding, used for the maskable safe zone).
async function mark(size, ratio) {
  const svg = await satori(
    {
      type: 'div',
      props: {
        style: {
          display: 'flex', width: '100%', height: '100%',
          alignItems: 'center', justifyContent: 'center',
          background: INK, color: GOLD,
          fontFamily: 'Sant Lipi', fontSize: Math.round(size * ratio), lineHeight: 1,
        },
        children: 'ੴ',
      },
    },
    { width: size, height: size, fonts: [{ name: 'Sant Lipi', data: sant, weight: 600, style: 'normal' }] },
  );
  const png = new Resvg(svg, { fitTo: { mode: 'width', value: size }, background: INK }).render().asPng();
  return png;
}

async function write(name, size, ratio) {
  const png = await mark(size, ratio);
  const out = await sharp(png).png({ compressionLevel: 9, palette: false }).toBuffer();
  writeFileSync(join(OUT, name), out);
  console.log(`${name}  ${out.length} bytes`);
}

await write('icon-192.png', 192, 0.62);
await write('icon-512.png', 512, 0.62);
await write('apple-touch-icon.png', 180, 0.62);   // iOS applies its own rounding
await write('icon-maskable-512.png', 512, 0.46);  // glyph kept inside the ~80% maskable safe zone
console.log('icons written to', OUT);
