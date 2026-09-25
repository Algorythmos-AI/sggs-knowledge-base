import { defineConfig, devices } from '@playwright/test';

// The live suite: the deployed wiki against the real, read-only production API — no mocks, no local
// server. Run after every staging deploy (deploy-docs), every six hours against production
// (docs-watch) and by hand:  DOCS_LIVE_URL=https://docs.gurbanisoul.com npx playwright test -c playwright.live.config.ts
// A protected staging alias needs VERCEL_BYPASS (the bypass secret; never printed).
const base = process.env.DOCS_LIVE_URL;
if (!base) throw new Error('set DOCS_LIVE_URL to the deployed wiki, e.g. https://docs.gurbanisoul.com');
const bypass = process.env.VERCEL_BYPASS;

export default defineConfig({
  testDir: './e2e-live',
  timeout: 60_000,
  retries: 2,                      // the network is real: one slow response is not an outage
  fullyParallel: false,            // a gentle client: the API sits behind a CDN with flood protection
  workers: 1,
  reporter: process.env.CI ? [['github'], ['list']] : 'list',
  use: {
    baseURL: base,
    trace: 'on-first-retry',
    extraHTTPHeaders: bypass ? { 'x-vercel-protection-bypass': bypass, 'x-vercel-set-bypass-cookie': 'true' } : undefined,
  },
  projects: [{ name: 'live', use: { ...devices['Desktop Chrome'] } }],
});
