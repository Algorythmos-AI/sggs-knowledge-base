import { test, expect } from '@playwright/test';
import AxeBuilder from '@axe-core/playwright';

// The multi-page marketing site: each nav item is its own route. These cover the two new pages
// (/features, /watch), the pathname-based nav active state, and that the shared chrome (theme
// toggle, mobile menu) keeps working off the landing.

test('/features renders the capability list and device shots @smoke', async ({ page }) => {
  const res = await page.goto('/features');
  expect(res?.status()).toBe(200);
  await expect(page.locator('h1')).toBeVisible();

  // the six-capability definition list is present
  expect(await page.locator('dl.feat-list .feat-row dt').count()).toBe(6);

  // all four app screenshots appear across the page (reader + nitnem + hukam + raag clock)
  for (const alt of ['Reader', 'Nitnem', 'Hukam', 'Raag Clock']) {
    await expect(page.locator(`img[alt*="${alt}" i]`).first()).toBeVisible();
  }

  await expect(page.locator('link[rel="canonical"]')).toHaveAttribute('href', 'https://gurbanisoul.com/features');
});

test('/watch renders the live dial, its caption and the raag list @smoke', async ({ page }) => {
  const res = await page.goto('/watch');
  expect(res?.status()).toBe(200);
  await expect(page.locator('h1')).toBeVisible();

  // the live caption resolves to a pahar
  await expect(page.locator('[data-raag-now]')).toHaveText(/pahar/, { timeout: 8000 });

  // the arc dial is present
  await expect(page.locator('svg.raag-arc')).toBeVisible();

  // the current watch's raag <li> is shown (exactly one un-hidden pahar), the rest hidden
  await expect(page.locator('ul.raags li[data-pahar]:not([hidden])')).toHaveCount(1);
  expect(await page.locator('ul.raags li[data-pahar]').count()).toBe(8);

  // CTA to the Knowledge Base Raag Clock tool
  await expect(page.locator('a[href="/raag-clock"]')).toBeVisible();

  await expect(page.locator('link[rel="canonical"]')).toHaveAttribute('href', 'https://gurbanisoul.com/watch');
});

test('nav active state marks the current route @smoke', async ({ page }, testInfo) => {
  test.skip(testInfo.project.name === 'mobile', 'primary nav is collapsed on mobile');
  await page.goto('/features');
  await expect(page.locator('nav[aria-label="Primary"] a[href="/features"]')).toHaveAttribute('aria-current', 'page');
  // exactly one active link
  await expect(page.locator('nav[aria-label="Primary"] a[aria-current="page"]')).toHaveCount(1);

  await page.goto('/watch');
  await expect(page.locator('nav[aria-label="Primary"] a[href="/watch"]')).toHaveAttribute('aria-current', 'page');
  await expect(page.locator('nav[aria-label="Primary"] a[href="/features"]')).not.toHaveAttribute('aria-current', 'page');
});

test('theme button works on a sub-page', async ({ page }, testInfo) => {
  test.skip(testInfo.project.name === 'mobile', 'theme button is in the collapsed nav on mobile');
  await page.goto('/features');
  const html = page.locator('html');
  const btn = page.locator('#themeBtn');
  await btn.click();
  await expect(html).toHaveAttribute('data-theme', /^(light|dark)$/);
});

test('mobile menu opens and closes on a sub-page', async ({ page }, testInfo) => {
  test.skip(testInfo.project.name !== 'mobile', 'hamburger only shows under 840px');
  await page.goto('/watch');
  const burger = page.locator('.burger');
  await expect(burger).toBeVisible();
  await burger.click();
  await expect(page.locator('dialog#mobileMenu[open]')).toBeVisible();
  await page.keyboard.press('Escape');
  await expect(page.locator('dialog#mobileMenu[open]')).toHaveCount(0);
});

// Under Reduce Motion the reveal-on-scroll content is fully visible (never opacity:0), so axe
// measures the real, settled colours rather than a mid-fade frame.
test('/features has no serious/critical accessibility violations', async ({ page }) => {
  await page.emulateMedia({ reducedMotion: 'reduce' });
  await page.goto('/features');
  const results = await new AxeBuilder({ page }).withTags(['wcag2a', 'wcag2aa']).analyze();
  const bad = results.violations.filter((v) => ['serious', 'critical'].includes(v.impact || ''));
  expect(bad, JSON.stringify(bad.map((v) => v.id))).toEqual([]);
});

test('/watch has no serious/critical accessibility violations', async ({ page }) => {
  await page.emulateMedia({ reducedMotion: 'reduce' });
  await page.goto('/watch');
  const results = await new AxeBuilder({ page }).withTags(['wcag2a', 'wcag2aa']).analyze();
  const bad = results.violations.filter((v) => ['serious', 'critical'].includes(v.impact || ''));
  expect(bad, JSON.stringify(bad.map((v) => v.id))).toEqual([]);
});
