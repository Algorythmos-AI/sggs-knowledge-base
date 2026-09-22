import { test, expect } from '@playwright/test';

// The theme toggle (moved from core.ts to scripts/theme.ts in the PR1 web-foundations pass) must
// behave identically: #themeBtn, glyphs ☀/☾/◐, cycle order system→light→dark, and a choice that
// persists in localStorage across a reload. Exercised on /search (a Knowledge Base page).
test('theme toggle cycles system→light→dark and persists @smoke', async ({ page }) => {
  // Start from a clean "no stored choice" state. Clear once, then reload — NOT via addInitScript,
  // which would re-run on the persistence-check reload below and wipe the choice we're testing.
  const res = await page.goto('/search');
  expect(res?.status()).toBe(200);
  await page.evaluate(() => { try { localStorage.removeItem('theme'); } catch (e) {} });
  await page.reload();

  const btn = page.locator('#themeBtn');
  const html = page.locator('html');

  // Default (no stored choice) = system; the pre-paint script + initTheme resolve a concrete theme.
  await expect(btn).toHaveText('◐');
  await expect(html).toHaveAttribute('data-theme', /^(light|dark)$/);

  // system → light
  await btn.click();
  await expect(btn).toHaveText('☀');
  await expect(html).toHaveAttribute('data-theme', 'light');
  expect(await page.evaluate(() => localStorage.getItem('theme'))).toBe('light');

  // light → dark
  await btn.click();
  await expect(btn).toHaveText('☾');
  await expect(html).toHaveAttribute('data-theme', 'dark');
  expect(await page.evaluate(() => localStorage.getItem('theme'))).toBe('dark');

  // the explicit dark choice survives a reload
  await page.reload();
  await expect(html).toHaveAttribute('data-theme', 'dark');
  await expect(btn).toHaveText('☾');
  expect(await page.evaluate(() => localStorage.getItem('theme'))).toBe('dark');

  // dark → back to system
  await btn.click();
  await expect(btn).toHaveText('◐');
  expect(await page.evaluate(() => localStorage.getItem('theme'))).toBe('system');
});
