import { defineConfig, devices } from '@playwright/test';

// The wiki's end-to-end suite runs against the built site (scripts/serve-dist.mjs over dist/). Every
// call to /api is intercepted and answered from e2e/fixtures, so the suite never depends on
// production; the live path is proven separately by scripts/ci/docs_smoke.py after a deploy.
export default defineConfig({
  testDir: './e2e',
  timeout: 45_000,
  fullyParallel: true,
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 2 : 0,
  reporter: process.env.CI ? [['github'], ['list'], ['html', { open: 'never' }]] : 'list',
  use: {
    baseURL: 'http://127.0.0.1:4323',
    trace: 'on-first-retry',
  },
  projects: [
    { name: 'desktop', use: { ...devices['Desktop Chrome'] } },
    // phone viewport on Chromium: the only browser CI installs (the iPhone preset would need WebKit)
    { name: 'mobile', use: { ...devices['Pixel 7'], defaultBrowserType: 'chromium' } },
  ],
  webServer: {
    command: 'node scripts/serve-dist.mjs 4323',
    url: 'http://127.0.0.1:4323/',
    reuseExistingServer: !process.env.CI,
    timeout: 60_000,
  },
});
