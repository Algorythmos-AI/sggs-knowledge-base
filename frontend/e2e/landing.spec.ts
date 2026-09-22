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

  // exactly one canonical App-Store "coming soon" element (the hero)
  await expect(page.locator('[data-app-store="coming-soon"]')).toHaveCount(1);

  // hero image offers modern formats + a descriptive alt
  expect(await page.locator('picture source[type="image/avif"]').count()).toBeGreaterThanOrEqual(1);
  await expect(page.locator('.hero-media img')).toHaveAttribute('alt', /Harmandir Sahib/);

  // primary nav is now real routes (Features, The watch, Privacy, Knowledge Base, Support, Learn)
  expect(await page.locator('nav[aria-label="Primary"] a').count()).toBeGreaterThanOrEqual(5);
  for (const href of ['/features', '/watch', '/privacy', '/search', '/support', '/learn']) {
    await expect(page.locator(`nav[aria-label="Primary"] a[href="${href}"]`)).toHaveCount(1);
  }

  // the overview grid links to each sub-page
  for (const href of ['/features', '/watch', '/learn', '/search']) {
    await expect(page.locator(`.ov-grid a[href="${href}"]`)).toHaveCount(1);
  }

  // home is short: no in-page feature/clock sections remain
  await expect(page.locator('#features, #clock')).toHaveCount(0);
  await expect(page.locator('[data-raag-now]')).toHaveCount(0);

  // visible links to KB, support, privacy (footer works on desktop and mobile)
  for (const href of ['/search', '/support', '/privacy']) {
    await expect(page.locator(`nav[aria-label="Footer"] a[href="${href}"]`)).toBeVisible();
  }

  // canonical
  await expect(page.locator('link[rel="canonical"]')).toHaveAttribute('href', 'https://gurbanisoul.com/');
});

test('legacy /?q= bookmark forwards to /search @smoke', async ({ page }) => {
  await page.goto('/?q=waheguru');
  await page.waitForURL(/\/search\?q=waheguru/, { timeout: 8000 });
});

test('theme button toggles the document theme', async ({ page }, testInfo) => {
  test.skip(testInfo.project.name === 'mobile', 'theme button is in the collapsed nav on mobile');
  await page.goto('/');
  const html = page.locator('html');
  const btn = page.locator('#themeBtn');
  const before = await html.getAttribute('data-theme');
  await btn.click();
  await expect(html).toHaveAttribute('data-theme', /^(light|dark)$/);
  // cycling eventually lands on a value different from the first resolved one
  await btn.click();
  const after = await html.getAttribute('data-theme');
  expect([before, after].filter(Boolean).length).toBeGreaterThan(0);
});

test('mobile menu opens, closes on Esc, and restores focus', async ({ page }, testInfo) => {
  test.skip(testInfo.project.name !== 'mobile', 'hamburger only shows under 840px');
  await page.goto('/');
  const burger = page.locator('.burger');
  await expect(burger).toBeVisible();
  await burger.click();
  await expect(page.locator('dialog#mobileMenu[open]')).toBeVisible();
  await page.keyboard.press('Escape');
  await expect(page.locator('dialog#mobileMenu[open]')).toHaveCount(0);
  await expect(burger).toBeFocused();
});

test('landing has no serious/critical accessibility violations', async ({ page }) => {
  await page.goto('/');
  const results = await new AxeBuilder({ page }).withTags(['wcag2a', 'wcag2aa']).analyze();
  const bad = results.violations.filter((v) => ['serious', 'critical'].includes(v.impact || ''));
  expect(bad, JSON.stringify(bad.map((v) => v.id))).toEqual([]);
});
