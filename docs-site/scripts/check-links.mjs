// After a build: every internal link, image, script and stylesheet in dist/ must resolve to a
// built file, and every `#fragment` on an internal link must be an id on the target page. This
// checks the real output (what a reader clicks), whichever directory the Markdown came from.
import { readFileSync, readdirSync, statSync, existsSync } from 'node:fs';
import path from 'node:path';

const dist = path.resolve(process.argv[2] ?? 'dist');
const pages = [];
const walk = (d) => { for (const n of readdirSync(d)) { const p = path.join(d, n); statSync(p).isDirectory() ? walk(p) : n.endsWith('.html') && pages.push(p); } };
walk(dist);

const idCache = new Map();
const idsOf = (file) => {
  if (!idCache.has(file)) {
    const html = readFileSync(file, 'utf8');
    idCache.set(file, new Set([...html.matchAll(/\sid="([^"]+)"/g)].map((m) => decodeURIComponent(m[1]))));
  }
  return idCache.get(file);
};
const resolve = (url) => {
  const clean = url.replace(/[?].*$/, '');
  const p = path.join(dist, decodeURIComponent(clean));
  if (clean.endsWith('/')) return existsSync(path.join(p, 'index.html')) ? path.join(p, 'index.html') : null;
  if (existsSync(p) && statSync(p).isFile()) return p;
  if (existsSync(path.join(p, 'index.html'))) return path.join(p, 'index.html');
  if (existsSync(p + '.html')) return p + '.html';
  return null;
};

const problems = [];
let checked = 0;
for (const page of pages) {
  const html = readFileSync(page, 'utf8');
  const rel = path.relative(dist, page);
  const refs = [
    ...[...html.matchAll(/<a\s[^>]*href="([^"]+)"/g)].map((m) => ['link', m[1]]),
    ...[...html.matchAll(/<(?:img|script)\s[^>]*src="([^"]+)"/g)].map((m) => ['asset', m[1]]),
    ...[...html.matchAll(/<link\s[^>]*href="([^"]+)"/g)].map((m) => ['asset', m[1]]),
  ];
  for (const [kind, raw] of refs) {
    const url = raw.replace(/&amp;/g, '&');
    if (/^(?:[a-z][a-z0-9+.-]*:|\/\/)/i.test(url)) continue;            // external, mailto:, tel:
    if (url.startsWith('#')) {
      checked++;
      if (url.length > 1 && !idsOf(page).has(decodeURIComponent(url.slice(1)))) problems.push(`${rel}: fragment ${url} has no target on the page`);
      continue;
    }
    if (!url.startsWith('/')) { problems.push(`${rel}: relative ${kind} "${url}" (site links must be absolute)`); continue; }
    checked++;
    const [pathPart, hash] = url.split('#');
    const target = resolve(pathPart);
    if (!target) { problems.push(`${rel}: ${kind} to "${url}" does not exist in the build`); continue; }
    if (hash && target.endsWith('.html') && !idsOf(target).has(decodeURIComponent(hash))) {
      problems.push(`${rel}: "${url}" — no element with id "${hash}" on ${path.relative(dist, target)}`);
    }
  }
}
if (problems.length) {
  console.error(`check-links: ${problems.length} problem(s) across ${pages.length} pages:\n  ` + problems.join('\n  '));
  process.exit(1);
}
console.log(`check-links: ${checked} internal references across ${pages.length} pages all resolve`);
