// @ts-check
import { defineConfig } from 'astro/config';

// SGGS Knowledge Base — Path A (Offline Monolith).
// Astro compiles to STATIC files (output:'static') served by the local stdlib
// Python serve.py. 100% offline: NO CDN, no SSR, no adapter, no network at runtime.
export default defineConfig({
  output: 'static',
  // Build to frontend/dist/ — NEVER directly at webapp/static/. `astro build` empties
  // its outDir first, so pointing at webapp/static/ would destroy the live app between
  // build and the sync step. The sync script copies dist/ -> webapp/static/ with a backup.
  build: { outDir: './dist', assets: '_astro' },
  // serve.py serves at the root (localhost:7777/), so absolute /_astro/* asset URLs must
  // resolve at '/'. base must be '/'.
  base: '/',
  // MPA: emit reader.html (not reader/index.html); serve.py maps /reader -> reader.html.
  trailingSlash: 'never',
  // Keep things bundled + offline; inline tiny assets to avoid extra local requests.
  vite: { build: { assetsInlineLimit: 4096 } },
});
