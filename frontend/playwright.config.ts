import { defineConfig, devices } from '@playwright/test';

// serve.py serves the built webapp/static + the /api backend on 7777.
// Build + sync (npm run build:deploy) must run before this in CI.
export default defineConfig({
  testDir: './e2e',
  timeout: 30_000,
  fullyParallel: true,
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 1 : 0,
  reporter: process.env.CI ? [['github'], ['list']] : 'list',
  use: {
    baseURL: 'http://127.0.0.1:7777',
    trace: 'on-first-retry',
  },
  projects: [
    { name: 'desktop', use: { ...devices['Desktop Chrome'] } },
    { name: 'mobile', use: { ...devices['iPhone 13'] } },
  ],
  webServer: {
    command: 'bash -c "cd ../webapp && SGGS_OPEN_BROWSER=0 SGGS_PORT=7777 python3 serve.py"',
    url: 'http://127.0.0.1:7777/api/health',
    reuseExistingServer: !process.env.CI,
    timeout: 60_000,
  },
});
