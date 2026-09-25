// The visual pass the build cannot judge: screenshots of one page per section in light, dark and
// phone width, for the owner's walkthrough before a promotion. Writes under docs-site/qa-shots/
// (git-ignored). The API is proxied to production so live widgets render real data.
//   node scripts/visual-qa.mjs [base-url]      default: the built dist/ on a local port
import { spawn } from 'node:child_process';
import { mkdirSync } from 'node:fs';
import { chromium } from 'playwright';

const PAGES = ['/', '/onboarding/', '/scripture/structure/', '/scripture/what-sggs-is/', '/learning-paths/platform-engineer/', '/exercises/01-trace-a-search/',
  '/architecture/overview/', '/architecture/search-waterfall/', '/data/line-record/', '/data/architecture/database-schema/', '/search/verification-engine/', '/api/',
  '/api/routes/', '/ios/db-pair-and-launch-integrity/', '/engineering/invariants/', '/process/ci-gates/', '/brand/', '/adr/', '/glossary/', '/reference/repo-map/', '/archive/', '/nope/'];
const API = 'https://sggs-knowledge-base.onrender.com';
let base = process.argv[2], server = null;
if (!base) {
  server = spawn('node', ['scripts/serve-dist.mjs', '4340'], { stdio: 'ignore' }); base = 'http://127.0.0.1:4340';
  for (let i = 0; i < 60; i++) { try { if ((await fetch(base + '/')).ok) break; } catch { /* not yet */ } await new Promise((r) => setTimeout(r, 500)); }
}
mkdirSync('qa-shots', { recursive: true });
const browser = await chromium.launch();
const name = (p) => (p === '/' ? 'home' : p.replace(/^\/|\/$/g, '').replace(/\//g, '_'));
for (const [label, viewport, theme] of [['light', { width: 1440, height: 1100 }, 'light'], ['dark', { width: 1440, height: 1100 }, 'dark'], ['phone', { width: 390, height: 844 }, 'light']]) {
  const ctx = await browser.newContext({ viewport, reducedMotion: 'reduce', isMobile: viewport.width < 500 });
  const page = await ctx.newPage();
  await page.route('**/api/**', async (route) => {
    if (route.request().resourceType() === 'document') return route.fallback();
    try { const u = new URL(route.request().url()); const r = await fetch(API + u.pathname + u.search); return route.fulfill({ status: r.status, contentType: 'application/json', body: await r.text() }); }
    catch { return route.fulfill({ status: 503, body: '{}' }); }
  });
  await page.addInitScript((t) => { try { localStorage.setItem('starlight-theme', t); } catch { /* private window */ } }, theme);
  for (const p of PAGES) {
    await page.goto(base + p, { waitUntil: 'networkidle' }).catch(() => {});
    await page.waitForTimeout(600);
    const wide = await page.evaluate(() => document.documentElement.scrollWidth > document.documentElement.clientWidth + 1);
    if (wide) console.log(`::warning::horizontal scroll at ${label} ${p}`);
    await page.screenshot({ path: `qa-shots/${name(p)}--${label}.png`, fullPage: false });
  }
  await ctx.close();
}
await browser.close(); if (server) server.kill();
console.log(`visual-qa: ${PAGES.length} pages × 3 → docs-site/qa-shots/`);
