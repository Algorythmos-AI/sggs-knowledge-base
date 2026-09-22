import { test, expect } from '@playwright/test';
import AxeBuilder from '@axe-core/playwright';

const TODI = 'ਟੋਡੀ ਮਹਲਾ ੫ ਘਰੁ ੨ ਚਉਪਦੇ';

test('Reader renders the printed heading on Ang 712 @smoke', async ({ page }) => {
  await page.goto('/reader?ang=712');
  await expect(page.locator('body')).toContainText(TODI, { timeout: 15_000 });
});

test('search → composition sheet shows the heading (the v1.1.0 fix) @smoke', async ({ page }) => {
  await page.goto('/search');
  await page.locator('#q').fill('Maya magan swad lobh');
  await page.locator('#q').press('Enter');
  const firstCard = page.locator('#results .card[role="button"]').first();
  await expect(firstCard).toBeVisible({ timeout: 15_000 });
  await firstCard.click();
  const panel = page.locator('#panel');
  await expect(panel).toHaveClass(/on/);
  await expect(page.locator('#pbody')).toContainText(TODI, { timeout: 10_000 });
  // ੴ invocation is also present, and the searched verse
  await expect(page.locator('#pbody')).toContainText('ੴ ਸਤਿਗੁਰ ਪ੍ਰਸਾਦਿ');
});

test('home page has no serious/critical accessibility violations', async ({ page }) => {
  await page.goto('/search');
  const results = await new AxeBuilder({ page })
    .withTags(['wcag2a', 'wcag2aa'])
    .analyze();
  const serious = results.violations.filter((v) => ['serious', 'critical'].includes(v.impact || ''));
  expect(serious, JSON.stringify(serious.map((v) => v.id))).toEqual([]);
});
