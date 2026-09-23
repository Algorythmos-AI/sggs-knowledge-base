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

// Since v1.3.5 /privacy and /support render in the Gurbani Soul marketing shell (LegalPage), not
// the Knowledge Base's. The contents rail marks the section being read; a jump from the rail must
// mark exactly the section jumped to, even when the next section is short.
for (const route of ['/privacy', '/support']) {
  test(`${route} is in the marketing shell with a working contents rail`, async ({ page }) => {
    await page.goto(route);
    await expect(page.locator('#mnav')).toBeVisible();
    await expect(page.locator('h1')).toHaveCount(1);
    await expect(page.locator('#saroopBtn')).toHaveCount(0);
    const links = page.locator('.legal-toc a');
    const n = await links.count();
    expect(n).toBeGreaterThan(2);
    for (let i = n - 1; i >= 0; i--) {
      const a = links.nth(i);
      await a.click();
      await expect(a).toHaveAttribute('aria-current', 'true');
    }
  });
}

test('privacy policy discloses the website analytics honestly', async ({ page }) => {
  await page.goto('/privacy');
  const site = page.locator('#this-website');
  await expect(site).toContainText('Vercel Web Analytics');
  await expect(site).toContainText('no cookies');
});

test('support FAQ questions are visible headings with a jump list', async ({ page }) => {
  await page.goto('/support');
  const qs = page.locator('#faq h3');
  expect(await qs.count()).toBeGreaterThan(5);
  const first = page.locator('.faq-jump a').first();
  const target = (await first.getAttribute('href'))!.slice(1);
  await expect(page.locator(`#${target}`)).toHaveCount(1);
});
