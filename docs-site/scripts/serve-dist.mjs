// A small static server for the built site (dist/), used by the e2e suite and local review.
// Mirrors the hosting rules that matter: directory URLs serve index.html, a missing page serves
// 404.html with status 404, assets get their media type. No dependencies, no caching surprises.
//   node scripts/serve-dist.mjs [port] [dir]
import { createServer } from 'node:http';
import { createReadStream, existsSync, statSync } from 'node:fs';
import path from 'node:path';

const port = Number(process.argv[2] ?? 4323);
const dist = path.resolve(process.argv[3] ?? 'dist');
const types = { '.html': 'text/html; charset=utf-8', '.css': 'text/css', '.js': 'text/javascript', '.mjs': 'text/javascript', '.json': 'application/json',
  '.svg': 'image/svg+xml', '.png': 'image/png', '.jpg': 'image/jpeg', '.webp': 'image/webp', '.woff2': 'font/woff2', '.txt': 'text/plain; charset=utf-8',
  '.xml': 'application/xml', '.ico': 'image/x-icon', '.wasm': 'application/wasm', '.pf_meta': 'application/octet-stream', '.pf_index': 'application/octet-stream', '.pf_fragment': 'application/octet-stream', '.pagefind': 'application/octet-stream' };

const send = (res, file, status = 200) => {
  res.writeHead(status, { 'content-type': types[path.extname(file)] ?? 'application/octet-stream', 'cache-control': 'no-store' });
  createReadStream(file).pipe(res);
};

createServer((req, res) => {
  const url = decodeURIComponent(new URL(req.url, 'http://x').pathname);
  let file = path.join(dist, url);
  if (!file.startsWith(dist)) { res.writeHead(403).end(); return; }
  if (existsSync(file) && statSync(file).isDirectory()) file = path.join(file, 'index.html');
  if (!existsSync(file) && existsSync(file + '.html')) file += '.html';
  if (existsSync(file) && statSync(file).isFile()) return send(res, file);
  const nf = path.join(dist, '404.html');
  if (existsSync(nf)) return send(res, nf, 404);
  res.writeHead(404, { 'content-type': 'text/plain' }).end('not found');
}).listen(port, '127.0.0.1', () => console.log(`serve-dist: http://127.0.0.1:${port}/ -> ${dist}`));
