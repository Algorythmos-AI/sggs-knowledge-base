import { test, expect } from '@playwright/test';
import AxeBuilder from '@axe-core/playwright';
import { mockApi } from './helpers';

test.describe('delivery, CI and the archive', () => {
  test('process pages carry their verified stamp in the footer', async ({ page }) => {
    await mockApi(page);
    await page.goto('/process/ci-gates/');
    const stamp = page.locator('p.verified');
    await expect(stamp).toContainText('Last verified against');
    await expect(stamp.locator('a')).toHaveAttribute('href', /github\.com\/Algorythmos-AI\/sggs-platform\/commit\/[0-9a-f]{7,40}/);
  });

  test('posters 10 and 11 are on their pages with their steps', async ({ page }) => {
    await mockApi(page);
    await page.goto('/process/ci-gates/');
    await expect(page.locator('figure.poster[data-poster="10-ci-gates-map"] g[data-step]')).toHaveCount(8);
    await page.goto('/process/branching/');
    await expect(page.locator('figure.poster[data-poster="11-delivery-pipeline"] g[data-step]')).toHaveCount(12);
  });

  test('the archive links history to GitHub, never to a missing page', async ({ page }) => {
    await mockApi(page);
    await page.goto('/archive/');
    const links = page.locator('main table a');
    const n = await links.count();
    expect(n).toBeGreaterThan(15);
    for (let i = 0; i < n; i++) {
      const href = await links.nth(i).getAttribute('href');
      expect(href, href ?? '').toMatch(/^(https:\/\/github\.com\/Algorythmos-AI\/sggs-platform\/blob\/|\/[a-z].*\/$)/);
    }
    await expect(page.locator('main a[href*="reports/archive/org-transfer.md"]')).toHaveCount(1);
  });

  for (const path of ['/process/ci-gates/', '/process/branching/', '/archive/', '/engineering/invariants/', '/process/environments/']) {
    test(`no accessibility violations: ${path}`, async ({ page }) => {
      await mockApi(page);
      await page.goto(path);
      const results = await new AxeBuilder({ page }).withTags(['wcag2a', 'wcag2aa', 'wcag21aa']).analyze();
      expect(results.violations, JSON.stringify(results.violations, null, 1)).toEqual([]);
    });
  }
});
