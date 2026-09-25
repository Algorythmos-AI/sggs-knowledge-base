import { test, expect } from '@playwright/test';
import AxeBuilder from '@axe-core/playwright';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, resolve } from 'node:path';
import { mockApi } from './helpers';

// Every page the build produced, from the sitemap: axe on all of them (desktop project only — the
// sections' own suites cover phone width). A new page cannot ship with a violation.
const here = dirname(fileURLToPath(import.meta.url));
const sitemap = readFileSync(resolve(here, '..', 'dist', 'sitemap-0.xml'), 'utf8');
const urls = Array.from(sitemap.matchAll(/<loc>([^<]+)<\/loc>/g)).map((m) => new URL(m[1]).pathname).filter((p) => !p.startsWith('/api/reference/'));

test.describe('every page', () => {
  test.beforeEach(({}, testInfo) => { test.skip(testInfo.project.name !== 'desktop', 'desktop only'); });

  test('the sitemap lists the whole site', () => {
    expect(urls.length).toBeGreaterThan(100);
  });

  for (const path of urls) {
    test(`axe: ${path}`, async ({ page }) => {
      await mockApi(page);
      const res = await page.goto(path);
      expect(res?.status(), path).toBe(200);
      const results = await new AxeBuilder({ page }).withTags(['wcag2a', 'wcag2aa', 'wcag21aa']).analyze();
      expect(results.violations, JSON.stringify(results.violations, null, 1)).toEqual([]);
    });
  }
});

test.describe('the 404 page and the cards', () => {
  test('an unknown path answers 404 with the site\'s own page', async ({ page }) => {
    await mockApi(page);
    const res = await page.goto('/this/page/does/not/exist/');
    expect(res?.status()).toBe(404);
    await expect(page.locator('main')).toContainText(/not found|404/i);
    await expect(page.locator('a[href="/"]').first()).toBeVisible();
  });

  test('every page names an Open Graph card that exists', async ({ page, request }) => {
    await mockApi(page);
    for (const path of ['/', '/scripture/structure/', '/api/routes/']) {
      await page.goto(path);
      const og = await page.locator('meta[property="og:image"]').getAttribute('content');
      expect(og, path).toMatch(/\/og\/.+\.png$/);
      const res = await request.get(new URL(og!).pathname);
      expect(res.status(), og!).toBe(200);
      expect(res.headers()['content-type']).toContain('image/png');
    }
  });
});
