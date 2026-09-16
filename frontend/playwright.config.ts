import { defineConfig, devices } from '@playwright/test';

// Two modes:
//  * Local / PR CI (default): starts serve.py, which serves the built
//    webapp/static + /api on 7777 (run `npm run build:deploy` first).
//  * Remote smoke: set PLAYWRIGHT_BASE_URL to a deployed URL (staging, or an
//    unpromoted production deployment). No local server is started. If the URL
//    is behind Vercel Deployment Protection, VERCEL_AUTOMATION_BYPASS_SECRET is
//    sent as the documented bypass header.
const remote = process.env.PLAYWRIGHT_BASE_URL;
const bypass = process.env.VERCEL_AUTOMATION_BYPASS_SECRET;

export default defineConfig({
  testDir: './e2e',
  timeout: 45_000,
  fullyParallel: true,
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 2 : 0,
  reporter: process.env.CI ? [['github'], ['list']] : 'list',
  use: {
    baseURL: remote || 'http://127.0.0.1:7777',
    trace: 'on-first-retry',
    extraHTTPHeaders: bypass
      ? { 'x-vercel-protection-bypass': bypass, 'x-vercel-set-bypass-cookie': 'true' }
      : undefined,
  },
  projects: [
    { name: 'desktop', use: { ...devices['Desktop Chrome'] } },
    { name: 'mobile', use: { ...devices['iPhone 13'] } },
  ],
  webServer: remote
    ? undefined
    : {
        command: 'bash -c "cd ../webapp && SGGS_OPEN_BROWSER=0 SGGS_PORT=7777 python3 serve.py"',
        url: 'http://127.0.0.1:7777/api/health',
        reuseExistingServer: !process.env.CI,
        timeout: 60_000,
      },
});
