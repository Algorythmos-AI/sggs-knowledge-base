// Build every poster spec in docs-site/posters/*.mjs into docs/diagrams/posters/NN-slug.svg and
// NN-slug.steps.json. `--check` fails when a committed poster differs from its spec (CI).
import { readdirSync, readFileSync, writeFileSync, mkdirSync, existsSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { buildPoster } from '../posters/kit.mjs';

const here = path.dirname(fileURLToPath(import.meta.url));
const specsDir = path.resolve(here, '../posters');
const outDir = path.resolve(here, '../../docs/diagrams/posters');
const check = process.argv.includes('--check');
mkdirSync(outDir, { recursive: true });
let stale = 0, built = 0;
for (const f of readdirSync(specsDir).filter((n) => /^\d\d-.*\.mjs$/.test(n)).sort()) {
  const spec = (await import(pathToFileURL(path.join(specsDir, f)).href)).default;
  const { svg, steps } = buildPoster(spec);
  const base = `${spec.number}-${spec.slug}`;
  const targets = [[path.join(outDir, base + '.svg'), svg], [path.join(outDir, base + '.steps.json'), JSON.stringify(steps, null, 2) + '\n']];
  for (const [file, content] of targets) {
    const same = existsSync(file) && readFileSync(file, 'utf8') === content;
    if (check) { if (!same) { console.error(`stale: ${path.relative(process.cwd(), file)} — run: node scripts/build-posters.mjs`); stale++; } }
    else if (!same) { writeFileSync(file, content); built++; }
  }
}
if (check) { console.log(stale ? `build-posters: ${stale} file(s) stale` : 'build-posters: every poster is current'); process.exit(stale ? 1 : 0); }
console.log(`build-posters: ${built} file(s) written`);
