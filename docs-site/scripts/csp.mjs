// The docs site's Content-Security-Policy lets exactly the inline scripts the build emits run, by
// hash — no 'unsafe-inline'. Starlight and the site's Head inline a few small scripts (the theme
// picker, the widget bootstrap); their sha256 lives in the script-src directive of
// docs-site/vercel.json, which Vercel serves and scripts/serve-dist.mjs mirrors for the e2e suite.
//
//   node scripts/csp.mjs --check [dist]   CI: fail when an inline script in dist/ is not listed,
//                                         a listed hash is used by no page, 'unsafe-inline' is back,
//                                         or any page has an inline on*= handler / javascript: URL
//   node scripts/csp.mjs --write [dist]   rewrite script-src in vercel.json from dist/
import { createHash } from 'node:crypto';
import { readdirSync, readFileSync, writeFileSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const VERCEL_JSON = fileURLToPath(new URL('../vercel.json', import.meta.url));
const DATA_TYPES = new Set(['application/json', 'application/ld+json']);   // data blocks never execute

export function inlineScripts(html) {
  const out = [];
  for (const m of html.matchAll(/<script\b([^>]*)>([\s\S]*?)<\/script\s*>/gi)) {
    const attrs = m[1];
    if (/\ssrc\s*=/i.test(' ' + attrs)) continue;
    const type = (/\btype\s*=\s*["']?([^"'\s>]+)/i.exec(attrs)?.[1] ?? '').toLowerCase();
    if (DATA_TYPES.has(type)) continue;
    out.push(m[2]);
  }
  return out;
}

export const hashOf = (text) => `'sha256-${createHash('sha256').update(text, 'utf8').digest('base64')}'`;

export function unsafeMarkup(html) {
  const found = [];
  for (const m of html.matchAll(/<[a-z][a-z0-9-]*\s[^>]*?\bon[a-z]+\s*=\s*["'][^>]*>/gi)) found.push(m[0].slice(0, 80));
  for (const m of html.matchAll(/<[a-z][^>]*\b(?:href|src|action)\s*=\s*["']\s*javascript:[^>]*>/gi)) found.push(m[0].slice(0, 80));
  return found;
}

function* htmlFiles(dir) {
  for (const e of readdirSync(dir, { withFileTypes: true })) {
    const p = path.join(dir, e.name);
    if (e.isDirectory()) yield* htmlFiles(p);
    else if (e.name.endsWith('.html')) yield p;
  }
}

export function scan(dist) {
  const hashes = new Map();   // hash -> first page using it
  const unsafe = [];
  let pages = 0, scripts = 0;
  for (const file of htmlFiles(dist)) {
    const html = readFileSync(file, 'utf8');
    pages++;
    for (const s of inlineScripts(html)) {
      scripts++;
      const h = hashOf(s);
      if (!hashes.has(h)) hashes.set(h, path.relative(dist, file));
    }
    for (const u of unsafeMarkup(html)) unsafe.push(`${path.relative(dist, file)}: ${u}`);
  }
  return { hashes, unsafe, pages, scripts };
}

/** The CSP header object in vercel.json and its script-src tokens. */
export function policy(vercel) {
  const header = (vercel.headers ?? []).flatMap((r) => r.headers).find((h) => h.key.toLowerCase() === 'content-security-policy');
  if (!header) throw new Error('docs-site/vercel.json has no Content-Security-Policy header');
  const directives = header.value.split(';').map((d) => d.trim()).filter(Boolean);
  const scriptSrc = directives.find((d) => d.startsWith('script-src '));
  if (!scriptSrc) throw new Error('the Content-Security-Policy has no script-src directive');
  return { header, directives, tokens: scriptSrc.split(/\s+/).slice(1) };
}

export function withHashes(value, hashes) {
  return value.split(';').map((d) => d.trim()).filter(Boolean).map((d) => {
    if (!d.startsWith('script-src ')) return d;
    const keep = d.split(/\s+/).slice(1).filter((t) => !t.startsWith("'sha256-") && t !== "'unsafe-inline'");
    return ['script-src', ...keep, ...[...hashes].sort()].join(' ');
  }).join('; ');
}

function main() {
  const mode = process.argv[2];
  const dist = path.resolve(process.argv[3] ?? 'dist');
  if (mode !== '--check' && mode !== '--write') { console.error('usage: node scripts/csp.mjs --check|--write [dist]'); process.exit(2); }
  const raw = readFileSync(VERCEL_JSON, 'utf8');
  const vercel = JSON.parse(raw);
  const { header, tokens } = policy(vercel);
  const { hashes, unsafe, pages, scripts } = scan(dist);
  const summary = `${scripts} inline script(s), ${hashes.size} distinct, across ${pages} pages`;
  if (mode === '--write') {
    const value = withHashes(header.value, hashes.keys());
    const next = raw.replace(JSON.stringify(header.value), JSON.stringify(value));
    if (next === raw && value !== header.value) throw new Error('could not locate the CSP value in vercel.json');
    writeFileSync(VERCEL_JSON, next);
    console.log(`csp: script-src now lists ${hashes.size} hash(es) (${summary})`);
    return;
  }
  const listed = new Set(tokens.filter((t) => t.startsWith("'sha256-")));
  const errors = [];
  if (tokens.includes("'unsafe-inline'")) errors.push("script-src allows 'unsafe-inline' — inline scripts must be allowed by hash");
  for (const [h, page] of hashes) if (!listed.has(h)) errors.push(`inline script not allowed by the CSP: ${h} (first on ${page})`);
  for (const h of listed) if (!hashes.has(h)) errors.push(`stale hash in the CSP (no page uses it): ${h}`);
  for (const u of unsafe) errors.push(`inline handler or javascript: URL (CSP blocks it): ${u}`);
  if (errors.length) {
    for (const e of errors) console.log(`::error file=docs-site/vercel.json::${e}`);
    console.log('csp: fix the markup, or after a Starlight/Head change run `npm run csp:write` and review the diff');
    process.exit(1);
  }
  console.log(`csp: ${summary}; every one allowed by hash, nothing else inline`);
}

if (process.argv[1] && fileURLToPath(import.meta.url) === path.resolve(process.argv[1])) main();
