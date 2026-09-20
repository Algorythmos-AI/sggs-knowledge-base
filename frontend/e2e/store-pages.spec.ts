import { test, expect } from '@playwright/test';

// /privacy and /support are the URLs entered in App Store Connect. A 404, a stale app name or a
// missing disclosure there is an App Review problem, so they are part of the smoke set.

test('privacy policy names the app and covers every on-device feature @smoke', async ({ page }) => {
  const res = await page.goto('/privacy');
  expect(res?.status()).toBe(200);
  const body = page.locator('#v-privacy');
  await expect(body).toContainText('Gurbani Soul');
  await expect(body).toContainText('Data Not Collected');
  for (const topic of ['Location', 'Reminders', 'Live Activity', 'Nitnem', 'Widgets', 'Diagnostics']) {
    await expect(body.locator('strong', { hasText: topic }).first()).toBeVisible();
  }
});

test('support page names the app and offers a contact @smoke', async ({ page }) => {
  const res = await page.goto('/support');
  expect(res?.status()).toBe(200);
  const body = page.locator('#v-support');
  await expect(body).toContainText('Gurbani Soul');
  await expect(body.locator('a[href^="mailto:"]').first()).toBeVisible();
  await expect(body.locator('a[href="/privacy"]').first()).toBeVisible();
});
