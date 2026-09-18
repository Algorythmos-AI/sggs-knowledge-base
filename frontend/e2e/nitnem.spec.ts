import { test, expect } from '@playwright/test';

const MOOL = 'ੴ ਸਤਿ ਨਾਮੁ ਕਰਤਾ ਪੁਰਖੁ';

test('Nitnem lists the banis and opens Japji Sahib verbatim @smoke', async ({ page }) => {
  await page.goto('/nitnem');
  const japji = page.locator('.bani-tile[data-key="japji"]');
  await expect(japji).toBeVisible({ timeout: 15_000 });
  await japji.click();
  await expect(page.locator('#baniOut')).toContainText(MOOL, { timeout: 15_000 });
  await expect(page.locator('#baniHead')).toContainText('Sri Guru Granth Sahib Ji · Ang 1–8');
});

test('the non-SGGS layer is labelled by source, never as an Ang', async ({ page }) => {
  await page.goto('/nitnem?bani=rehras');
  await expect(page.locator('#baniOut')).toContainText('Sri Dasam Granth', { timeout: 15_000 });
  const extra = page.locator('#baniOut .sline.extra').first();
  await expect(extra).toBeVisible();
  await expect(extra.locator('.cite')).not.toContainText('Ang');
});
