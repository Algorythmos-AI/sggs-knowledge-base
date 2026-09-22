import { test, expect } from '@playwright/test';
import AxeBuilder from '@axe-core/playwright';

// The gurbanisoul.com landing at / — App Review and first-time visitors see this first.
test('landing renders the brand, the verse and the CTAs @smoke', async ({ page }) => {
  const res = await page.goto('/');
  expect(res?.status()).toBe(200);
  await expect(page.locator('h1')).toHaveText('Gurbani Soul');
  // verbatim verse present, cited by Ang
  await expect(page.locator('p.verse[lang="pa"]')).toContainText('ੴ ਸਤਿ ਨਾਮੁ');
  await expect(page.locator('.cite')).toContainText('Ang 1');
  // exactly one of: App Store badge OR the "coming soon" note
  const badge = page.locator('a[aria-label*="App Store"]');
  const soon = page.locator('[data-app-store="coming-soon"]');
  expect(await badge.count() + await soon.count()).toBe(1);
  // hero image offers modern formats + alt
  await expect(page.locator('picture source[type="image/avif"]').first()).toHaveCount(1);
  await expect(page.locator('.hero-media img')).toHaveAttribute('alt', /Harmandir Sahib/);
  // links to KB, support, privacy
  for (const href of ['/search', '/support', '/privacy']) {
    await expect(page.locator(`a[href="${href}"]`).first()).toBeVisible();
  }
  // canonical
  await expect(page.locator('link[rel="canonical"]')).toHaveAttribute('href', 'https://gurbanisoul.com/');
});

test('legacy /?q= bookmark forwards to /search @smoke', async ({ page }) => {
  await page.goto('/?q=waheguru');
  await page.waitForURL(/\/search\?q=waheguru/, { timeout: 8000 });
});

test('landing has no serious/critical accessibility violations', async ({ page }) => {
  await page.goto('/');
  const results = await new AxeBuilder({ page }).withTags(['wcag2a', 'wcag2aa']).analyze();
  const bad = results.violations.filter((v) => ['serious', 'critical'].includes(v.impact || ''));
  expect(bad, JSON.stringify(bad.map((v) => v.id))).toEqual([]);
});
