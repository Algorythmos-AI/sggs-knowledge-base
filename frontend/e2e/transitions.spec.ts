import { test, expect } from '@playwright/test';

// PR2 adds Astro's <ClientRouter/> to the marketing shell so `/` ↔ `/learn` will feel app-like
// (the /learn route lands in PR3). Until it exists, this asserts the important guarantees hold:
//  * the marketing → Knowledge Base jump is a real, working navigation, and
//  * a theme choice made on the landing survives that jump (shared localStorage key 'theme').

test('landing → Knowledge Base is a working navigation and theme persists', async ({ page }, testInfo) => {
  test.skip(testInfo.project.name === 'mobile', 'uses the desktop theme button');
  await page.goto('/');
  // Make an explicit dark choice on the landing (system → light → dark).
  const btn = page.locator('#themeBtn');
  await btn.click();
  await btn.click();
  await expect(page.locator('html')).toHaveAttribute('data-theme', 'dark');
  expect(await page.evaluate(() => localStorage.getItem('theme'))).toBe('dark');

  // Jump to the Knowledge Base — a real navigation that must land on a working page.
  await page.locator('a[href="/search"]').first().click();
  await page.waitForURL(/\/search/);
  await expect(page.locator('#randomBtn')).toBeVisible();
  await expect(page.locator('#ver')).not.toBeEmpty();

  // The dark choice carried across.
  await expect(page.locator('html')).toHaveAttribute('data-theme', 'dark');
});

test('reduced motion: reveal content is visible without scrolling', async ({ browser }) => {
  const context = await browser.newContext({ reducedMotion: 'reduce' });
  const page = await context.newPage();
  await page.goto('/');
  // A .reveal block below the hero must be visible immediately (no scroll-triggered fade-in).
  await expect(page.locator('.verse-in.reveal')).toBeVisible();
  await expect(page.locator('p.verse[lang="pa"]')).toBeVisible();
  // The motion opt-in class is never armed under Reduce Motion.
  expect(await page.locator('html.js-motion').count()).toBe(0);
  await context.close();
});
