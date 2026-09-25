// Performance budget: the JavaScript a page loads (gzip) and the page's own HTML size.
// Widgets and Starlight's UI together must stay small enough for a phone on a slow connection.
import { readFileSync, readdirSync, statSync, existsSync } from 'node:fs';
import { gzipSync } from 'node:zlib';
import path from 'node:path';

const dist = process.argv[2] ?? 'dist';
const JS_BUDGET = 60 * 1024;   // gzip bytes of scripts per page (Pagefind loads lazily on search)
const HTML_BUDGET = 400 * 1024; // raw bytes of the largest page
const gz = new Map();
const gzOf = (p) => { if (!gz.has(p)) gz.set(p, existsSync(p) ? gzipSync(readFileSync(p)).length : 0); return gz.get(p); };
let worstJs = { page: '', bytes: 0 }, worstHtml = { page: '', bytes: 0 }, pages = 0;
const walk = (d) => {
  for (const n of readdirSync(d)) {
    const p = path.join(d, n);
    if (statSync(p).isDirectory()) walk(p);
    else if (n.endsWith('.html')) {
      pages++;
      const html = readFileSync(p, 'utf8');
      const size = Buffer.byteLength(html);
      if (size > worstHtml.bytes) worstHtml = { page: p, bytes: size };
      let js = 0;
      for (const m of html.matchAll(/<script[^>]+src="([^"]+)"/g)) {
        const src = m[1];
        if (src.startsWith('/')) js += gzOf(path.join(dist, src));
      }
      if (js > worstJs.bytes) worstJs = { page: p, bytes: js };
    }
  }
};
walk(dist);
console.log(`check-budget: ${pages} pages; heaviest JS ${(worstJs.bytes / 1024).toFixed(1)} KB gz (${worstJs.page}); largest HTML ${(worstHtml.bytes / 1024).toFixed(0)} KB (${worstHtml.page})`);
let fail = false;
if (worstJs.bytes > JS_BUDGET) { console.error(`::error::JS budget exceeded: ${worstJs.bytes} > ${JS_BUDGET} gz bytes on ${worstJs.page}`); fail = true; }
if (worstHtml.bytes > HTML_BUDGET) { console.error(`::error::HTML budget exceeded: ${worstHtml.bytes} > ${HTML_BUDGET} bytes on ${worstHtml.page}`); fail = true; }
process.exit(fail ? 1 : 0);
