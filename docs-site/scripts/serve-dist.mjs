// A small static server for the built site (dist/), used by the e2e suite and local review.
// Mirrors the hosting rules that matter: directory URLs serve index.html, a missing page serves
// 404.html with status 404, assets get their media type — and every response carries the headers
// docs-site/vercel.json gives it in production (the CSP above all), so the e2e suite runs under
// the real Content-Security-Policy and a blocked script fails a pull request, not a deploy.
// No dependencies, no caching surprises.
//   node scripts/serve-dist.mjs [port] [dir]
import { createServer } from 'node:http';
import { createReadStream, existsSync, readFileSync, statSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const port = Number(process.argv[2] ?? 4323);
const dist = path.resolve(process.argv[3] ?? 'dist');
const types = { '.html': 'text/html; charset=utf-8', '.css': 'text/css', '.js': 'text/javascript', '.mjs': 'text/javascript', '.json': 'application/json',
  '.svg': 'image/svg+xml', '.png': 'image/png', '.jpg': 'image/jpeg', '.webp': 'image/webp', '.woff2': 'font/woff2', '.txt': 'text/plain; charset=utf-8',
  '.xml': 'application/xml', '.ico': 'image/x-icon', '.wasm': 'application/wasm', '.pf_meta': 'application/octet-stream', '.pf_index': 'application/octet-stream', '.pf_fragment': 'application/octet-stream', '.pagefind': 'application/octet-stream' };

// vercel.json "headers": each rule's `source` (path-to-regexp: `(.*)`, `:name*`) -> RegExp.
// Every matching rule applies, in order, as on Vercel. Cache-Control stays no-store locally.
const vercel = JSON.parse(readFileSync(fileURLToPath(new URL('../vercel.json', import.meta.url)), 'utf8'));
export function toRegExp(source) {
  let re = '';
  for (let i = 0; i < source.length;) {
    if (source[i] === '(') {                                   // a regex group: copied verbatim
      let depth = 0, j = i;
      do { if (source[j] === '(') depth++; else if (source[j] === ')') depth--; j++; } while (depth && j < source.length);
      re += source.slice(i, j); i = j;
    } else if (source[i] === ':') {                            // :name, :name* (zero or more segments)
      const m = /^:[A-Za-z_]\w*(\*)?/.exec(source.slice(i));
      re += m[1] ? '.*' : '[^/]+'; i += m[0].length;
    } else {
      re += source[i].replace(/[.*+?^${}|[\]\\]/g, '\\$&'); i++;
    }
  }
  return new RegExp('^' + re + '$');
}
const rules = (vercel.headers ?? []).map((r) => ({ re: toRegExp(r.source), headers: r.headers }));
export const headersFor = (urlPath) => Object.fromEntries(rules.filter((r) => r.re.test(urlPath))
  .flatMap((r) => r.headers.map((h) => [h.key.toLowerCase(), h.value]))
  .filter(([k]) => k !== 'cache-control'));

const send = (res, file, urlPath, status = 200) => {
  res.writeHead(status, { ...headersFor(urlPath), 'content-type': types[path.extname(file)] ?? 'application/octet-stream', 'cache-control': 'no-store' });
  createReadStream(file).pipe(res);
};

const server = createServer((req, res) => {
  const url = decodeURIComponent(new URL(req.url, 'http://x').pathname);
  let file = path.join(dist, url);
  if (!file.startsWith(dist)) { res.writeHead(403).end(); return; }
  if (existsSync(file) && statSync(file).isDirectory()) file = path.join(file, 'index.html');
  if (!existsSync(file) && existsSync(file + '.html')) file += '.html';
  if (existsSync(file) && statSync(file).isFile()) return send(res, file, url);
  const nf = path.join(dist, '404.html');
  if (existsSync(nf)) return send(res, nf, url, 404);
  res.writeHead(404, { 'content-type': 'text/plain' }).end('not found');
});
if (process.argv[1] && fileURLToPath(import.meta.url) === path.resolve(process.argv[1])) {
  server.listen(port, '127.0.0.1', () => console.log(`serve-dist: http://127.0.0.1:${port}/ -> ${dist}`));
}
