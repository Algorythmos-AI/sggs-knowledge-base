// @ts-check
import { defineConfig } from 'astro/config';
import tailwindcss from '@tailwindcss/vite';   // Tailwind v4 — compiles at build time, fully offline

// SGGS Knowledge Base — Path A (Offline Monolith).
// Astro compiles to STATIC files (output:'static') served by the local stdlib
// Python serve.py. 100% offline: NO CDN, no SSR, no adapter, no network at runtime.
export default defineConfig({
  output: 'static',
  // Canonical production origin — used for <link rel="canonical"> and og:url in the layouts.
  // Keep in step with frontend/src/site.ts SITE_URL and the App Store Connect URLs.
  site: 'https://gurbanisoul.com',
  // Build to frontend/dist/ — NEVER directly at webapp/static/. `astro build` empties
  // its outDir first, so pointing at webapp/static/ would destroy the live app between
  // build and the sync step. The sync script copies dist/ -> webapp/static/ with a backup.
  build: { outDir: './dist', assets: '_astro' },
  // serve.py serves at the root (localhost:7777/), so absolute /_astro/* asset URLs must
  // resolve at '/'. base must be '/'.
  base: '/',
  // MPA: emit reader.html (not reader/index.html); serve.py maps /reader -> reader.html.
  trailingSlash: 'never',
  // Astro 7 changed the default to 'jsx' (JSX whitespace rules). Pin the HTML-aware
  // compressor so inter-element whitespace in the shipped pages stays as it was on v6.
  compressHTML: true,
  // Keep things bundled + offline; inline tiny assets to avoid extra local requests.
  // Tailwind v4 runs as a Vite plugin (no tailwind.config.js — v4 is CSS-first via @theme).
  // cssTarget: Vite 8 minifies CSS with Lightning CSS, which otherwise rewrites
  // `max-width:` queries to range syntax (`width<=…`, Safari 16.4+/Chrome 104+ only).
  // Pin the pre-upgrade browser floor so the shipped media queries stay as they were.
  vite: {
    plugins: [tailwindcss()],
    build: { assetsInlineLimit: 4096, cssTarget: ['chrome107', 'safari16'] },
  },
});
