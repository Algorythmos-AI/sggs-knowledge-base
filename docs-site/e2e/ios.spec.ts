import { test, expect } from '@playwright/test';
import AxeBuilder from '@axe-core/playwright';
import { mockApi } from './helpers';

test.describe('the iOS section', () => {
  test('poster 12 and the Swift excerpt are on their pages, read from the pinned app repository', async ({ page }) => {
    await mockApi(page);
    await page.goto('/ios/db-pair-and-launch-integrity/');
    await expect(page.locator('figure.poster[data-poster="12-ios-release-and-integrity"] g[data-step]')).toHaveCount(9);
    await expect(page.locator('.expressive-code').first()).toContainText('check_release_license.sh');
    await expect(page.locator('.excerpt__source a').first()).toHaveAttribute('href', /github\.com\/Algorythmos-AI\/gurbani-soul-ios\/blob\/[0-9a-f]{40}\//);
    await page.goto('/ios/contract-and-parity/');
    await expect(page.locator('.expressive-code').nth(1)).toContainText('func fold');
  });

  test('a pinned app document carries the canonical banner and the landing links reach it on the wiki', async ({ page }) => {
    await mockApi(page);
    await page.goto('/ios/nitnem/spec/');
    await expect(page.locator('aside.canonical')).toContainText('gurbani-soul-ios/docs/nitnem/spec.md');
    await page.goto('/ios/nitnem-for-engineers/');
    await expect(page.locator('.sl-markdown-content a[href="/ios/nitnem/spec/"]')).toHaveCount(1);
    await page.goto('/');
    await expect(page.locator('a[href="/ios/ios/testflight-launch-plan/"]').first()).toBeVisible();
  });

  for (const path of ['/ios/', '/ios/how-the-app-takes-a-release/', '/ios/contract-and-parity/', '/ios/db-pair-and-launch-integrity/', '/ios/nitnem-for-engineers/', '/ios/ios/testflight-launch-plan/', '/ios/nitnem/spec/']) {
    test(`no accessibility violations: ${path}`, async ({ page }) => {
      await mockApi(page);
      await page.goto(path);
      const results = await new AxeBuilder({ page }).withTags(['wcag2a', 'wcag2aa', 'wcag21aa']).analyze();
      expect(results.violations, JSON.stringify(results.violations, null, 1)).toEqual([]);
    });
  }
});
