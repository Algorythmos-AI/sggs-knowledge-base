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

  // v2 product story: numbered chapters, at least one photo band, a five-fact proof strip
  expect(await page.locator('[data-chapter]').count()).toBeGreaterThanOrEqual(6);
  expect(await page.locator('.photo-band').count()).toBeGreaterThanOrEqual(1);
  await expect(page.locator('ul.proof > li')).toHaveCount(5);
  await expect(page.locator('ul.proof')).toContainText('network calls in the app');
  // the story links on to the sub-pages
  for (const href of ['/watch', '/learn', '/privacy', '/search']) {
    expect(await page.locator(`main a[href="${href}"]`).count()).toBeGreaterThanOrEqual(1);
  }
  // exactly one verse on Home; the download band uses its own coming-soon marker
  await expect(page.locator('p.verse')).toHaveCount(1);
  await expect(page.locator('[data-app-store="coming-soon-foot"]')).toHaveCount(1);

  // the Raag Clock story is a static screenshot: no live clock (that lives on /watch)
  await expect(page.locator('#features, #clock')).toHaveCount(0);
  await expect(page.locator('[data-raag-now]')).toHaveCount(0);
  await expect(page.locator('#story-watch[data-theme="dark"]')).toHaveCount(1);

  // visible links to KB, support, privacy (footer works on desktop and mobile)
  for (const href of ['/search', '/support', '/privacy']) {
    await expect(page.locator(`nav[aria-label="Footer"] a[href="${href}"]`)).toBeVisible();
  }
  // the shared footer: four columns in ONE footer nav, and the artwork + type credits
  await expect(page.locator('nav[aria-label="Footer"]')).toHaveCount(1);
  await expect(page.locator('nav[aria-label="Footer"] .mfoot-col')).toHaveCount(4);
  await expect(page.locator('footer .credits')).toContainText('Artwork:');
  await expect(page.locator('footer .credits')).toContainText('SIL Open Font License');

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

// gurbanisoul.com is LIGHT-FIRST (v2): with no stored choice the marketing pages render light even
// when the OS is dark — the pre-paint default, the theme.ts default hook and the removed
// OS-appearance CSS block together. Emulating a dark OS proves the OS does not win.
test.describe('light-first default', () => {
  test.use({ colorScheme: 'dark' });

  test('marketing default is light with no stored choice', async ({ page }) => {
    await page.goto('/');
    await page.evaluate(() => { try { localStorage.removeItem('theme'); } catch (e) {} });
    await page.reload();
    await expect(page.locator('html')).toHaveAttribute('data-theme', 'light');
    await expect(page.locator('#themeBtn')).toHaveText('☀');
    // the browser chrome follows the PAGE theme, not the OS
    await expect(page.locator('meta[name="theme-color"]')).toHaveCount(1);
    await expect(page.locator('meta[name="theme-color"]')).toHaveAttribute('content', '#FBF7F0');
    // the page surface really is paper, not warm ink
    const bg = await page.evaluate(() => getComputedStyle(document.body).backgroundColor);
    expect(bg).toBe('rgb(251, 247, 240)');
    // nothing was written: the default is not a stored choice
    expect(await page.evaluate(() => localStorage.getItem('theme'))).toBeNull();
  });

  test('an explicit dark choice still wins on the marketing site', async ({ page }, testInfo) => {
    test.skip(testInfo.project.name === 'mobile', 'theme button is in the collapsed nav on mobile');
    await page.goto('/features');
    await page.evaluate(() => { try { localStorage.setItem('theme', 'dark'); } catch (e) {} });
    await page.reload();
    await expect(page.locator('html')).toHaveAttribute('data-theme', 'dark');
    await expect(page.locator('meta[name="theme-color"]')).toHaveAttribute('content', '#171412');
    // ☾ → ◐ (system, which resolves to the emulated dark OS) → ☀
    const btn = page.locator('#themeBtn');
    await btn.click();
    await expect(btn).toHaveText('◐');
    await btn.click();
    await expect(btn).toHaveText('☀');
    await expect(page.locator('html')).toHaveAttribute('data-theme', 'light');
    await expect(page.locator('meta[name="theme-color"]')).toHaveAttribute('content', '#FBF7F0');
  });
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
