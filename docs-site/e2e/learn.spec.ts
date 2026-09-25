import { test, expect } from '@playwright/test';
import AxeBuilder from '@axe-core/playwright';
import { mockApi } from './helpers';

test.describe('learn, contribute and the reference pages', () => {
  test('a learning path remembers ticks in this browser and can start again', async ({ page }) => {
    await mockApi(page);
    await page.goto('/learning-paths/platform-engineer/');
    const prog = page.locator('sggs-progress');
    await expect(prog.locator('.progress__status')).toContainText('0 of 14 steps done');
    const boxes = page.locator('.progress__list .progress__box');
    await expect(boxes).toHaveCount(14);
    await boxes.nth(0).check(); await boxes.nth(2).check();
    await expect(prog.locator('.progress__status')).toContainText('2 of 14');
    await page.reload();
    await expect(page.locator('.progress__list .progress__box').nth(2)).toBeChecked();
    await page.locator('.progress__reset').click();
    await expect(page.locator('sggs-progress .progress__status')).toContainText('0 of 14');
  });

  test('the repository map, the decisions timeline and the releases render at build and link out', async ({ page }) => {
    await mockApi(page);
    await page.goto('/reference/repo-map/');
    await expect(page.locator('.repo-map details.repo-map__repo')).toHaveCount(3);
    await expect(page.locator('.repo-map a[href="https://github.com/Algorythmos-AI/sggs-platform/tree/integration/webapp/serve.py"]')).toHaveCount(1);
    await page.goto('/adr/');
    const adrs = page.locator('.adrs .adr');
    expect(await adrs.count()).toBeGreaterThanOrEqual(12);
    await expect(adrs.first().locator('a')).toHaveAttribute('href', /^\/adr\/0001-/);
    await page.goto('/reference/releases/');
    const rel = page.locator('.release');
    expect(await rel.count()).toBeGreaterThan(15);
    await page.locator('.releases__filter').fill('1.3.9');
    await expect(page.locator('.releases__count')).toContainText('1 of');
    await expect(page.locator('.release:not([hidden]) .release__v a')).toHaveAttribute('href', 'https://github.com/Algorythmos-AI/sggs-platform/releases/tag/v1.3.9');
  });

  test('the contributors page is generated and joins the corpus author names', async ({ page }) => {
    await mockApi(page);
    await page.goto('/reference/contributors/');
    await expect(page.locator('main')).toContainText('Guru Arjan Dev Ji (M5)');
    await expect(page.locator('main h2').first()).toContainText('The Gurus');
  });

  for (const path of ['/learning-paths/', '/learning-paths/reviewer-scholar/', '/exercises/', '/exercises/02-add-a-route/', '/contributing/', '/contributing/docs-gates/', '/reference/repo-map/', '/reference/releases/', '/reference/contributors/', '/adr/']) {
    test(`no accessibility violations: ${path}`, async ({ page }) => {
      await mockApi(page);
      await page.goto(path);
      const results = await new AxeBuilder({ page }).withTags(['wcag2a', 'wcag2aa', 'wcag21aa']).analyze();
      expect(results.violations, JSON.stringify(results.violations, null, 1)).toEqual([]);
    });
  }
});
