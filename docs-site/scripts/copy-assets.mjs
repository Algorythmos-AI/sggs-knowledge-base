// prebuild: the fonts the product already ships (frontend/public/fonts, with their OFL licences) and
// the diagram posters (docs/diagrams/posters) are copied into public/ so the wiki serves them itself.
// Nothing is duplicated in git: public/fonts and public/posters are ignored.
import { cpSync, existsSync, mkdirSync, readdirSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const here = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(here, '../..');
const copies = [
  ['frontend/public/fonts', 'docs-site/public/fonts', ['SantLipi-VF.woff2', 'SourceSerif4-latin.woff2', 'OFL.txt', 'OFL-SourceSerif4.txt']],
  ['docs/diagrams/posters', 'docs-site/public/posters', null],
];
for (const [from, to, only] of copies) {
  const src = path.join(root, from);
  if (!existsSync(src)) continue;
  mkdirSync(path.join(root, to), { recursive: true });
  const names = only ?? readdirSync(src).filter((n) => n.endsWith('.svg') || n.endsWith('.json'));
  for (const n of names) {
    if (!existsSync(path.join(src, n))) throw new Error(`copy-assets: ${from}/${n} is missing`);
    cpSync(path.join(src, n), path.join(root, to, n));
  }
  console.log(`copy-assets: ${names.length} file(s) ${from} -> ${to}`);
}
