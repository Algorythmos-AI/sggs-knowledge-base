import { test, expect } from '@playwright/test';
import AxeBuilder from '@axe-core/playwright';
import { mockApi } from './helpers';

test.describe('posters', () => {
  test('a poster is inlined as an accessible SVG with its steps', async ({ page }) => {
    await mockApi(page);
    await page.goto('/architecture/request-lifecycle/');
    const poster = page.locator('figure.poster[data-poster="08-request-lifecycle"]');
    await expect(poster.locator('svg[role="img"]')).toBeVisible();
    await expect(poster.locator('svg title')).toHaveCount(1);
    await expect(poster.locator('g[data-step]')).toHaveCount(8);
    await expect(poster.locator('figcaption a[href="/posters/08-request-lifecycle.svg"]')).toBeVisible();
  });

  test('the walkthrough steps with buttons and arrow keys and dims later steps', async ({ page }) => {
    await mockApi(page);
    await page.goto('/architecture/request-lifecycle/');
    const wt = page.locator('sggs-walkthrough[data-poster="08-request-lifecycle"]');
    await expect(wt.locator('.wt__counter')).toHaveText('8 steps');
    await wt.locator('.wt__next').click();
    await expect(wt.locator('.wt__counter')).toHaveText('Step 1 of 8');
    await expect(wt.locator('.wt__caption')).toContainText('Same-origin call');
    await expect(wt.locator('g[data-step].is-dim')).toHaveCount(7);
    await expect(wt.locator('g[data-step].is-active')).toHaveCount(1);
    await wt.focus();
    await page.keyboard.press('ArrowRight');
    await expect(wt.locator('.wt__counter')).toHaveText('Step 2 of 8');
    await page.keyboard.press('Home');
    await expect(wt.locator('.wt__counter')).toHaveText('8 steps');
    await expect(wt.locator('g[data-step].is-dim')).toHaveCount(0);
    await wt.locator('.wt__item').nth(4).click();
    await expect(wt.locator('.wt__caption a.wt__link')).toHaveAttribute('href', '/engineering/invariants/');
  });

  test('the lightbox opens full size, zooms, and closes with Escape returning focus', async ({ page }) => {
    await mockApi(page);
    await page.goto('/architecture/overview/');
    const wt = page.locator('sggs-walkthrough[data-poster="01-system-landscape"]');
    await wt.locator('.wt__zoom').click();
    const dlg = page.locator('dialog.lightbox');
    await expect(dlg).toBeVisible();
    await expect(dlg.locator('svg')).toBeVisible();
    await dlg.getByRole('button', { name: 'Zoom in' }).click();
    await expect(dlg.locator('svg')).toHaveAttribute('style', /scale\(1\.25\)/);
    await page.keyboard.press('Escape');
    await expect(dlg).toHaveCount(0);
    await expect(wt.locator('.wt__zoom')).toBeFocused();
  });

  for (const path of ['/architecture/request-lifecycle/', '/architecture/bounded-contexts-and-gateway/', '/diagrams/']) {
    test(`no accessibility violations: ${path}`, async ({ page }) => {
      await mockApi(page);
      await page.goto(path);
      const results = await new AxeBuilder({ page }).withTags(['wcag2a', 'wcag2aa', 'wcag21aa']).analyze();
      expect(results.violations, JSON.stringify(results.violations, null, 1)).toEqual([]);
    });
  }
});
