import { test, expect } from '@playwright/test';
import AxeBuilder from '@axe-core/playwright';

// The Learn section (PR3): /learn index, the eight articles, RSS and per-article OG cards.
test('learn index lists the eight articles @smoke', async ({ page }) => {
  const res = await page.goto('/learn');
  expect(res?.status()).toBe(200);
  await expect(page.locator('h1')).toContainText('Learn');
  await expect(page.locator('.learn-card')).toHaveCount(8);
});

test('an article renders verbatim, cited and labelled @smoke', async ({ page }) => {
  const res = await page.goto('/learn/what-is-an-ang');
  expect(res?.status()).toBe(200);

  // verbatim Gurmukhi, in a lang=pa verse paragraph
  const verse = page.locator('p.verse[lang="pa"]').first();
  await expect(verse).toBeVisible();

  // cited by Ang
  await expect(page.locator('.cite').first()).toContainText('Ang');

  // interpretation is visibly labelled (Answer-Protocol)
  await expect(page.getByText('Explanation (interpretation, not scripture)').first()).toBeVisible();
});

test('rss feed is served as xml with learn items @smoke', async ({ request }) => {
  const res = await request.get('/rss.xml');
  expect(res.status()).toBe(200);
  expect(res.headers()['content-type']).toContain('xml');
  const body = await res.text();
  expect(body).toContain('<item>');
  expect(body).toContain('/learn/');
});

test('per-article OG card is a png @smoke', async ({ request }) => {
  const res = await request.get('/og/learn-what-is-an-ang.png');
  expect(res.status()).toBe(200);
  expect(res.headers()['content-type']).toContain('image/png');
});

test('learn index has no serious/critical accessibility violations', async ({ page }) => {
  await page.goto('/learn');
  const results = await new AxeBuilder({ page }).withTags(['wcag2a', 'wcag2aa']).analyze();
  const bad = results.violations.filter((v) => ['serious', 'critical'].includes(v.impact || ''));
  expect(bad, JSON.stringify(bad.map((v) => v.id))).toEqual([]);
});

test('an article has no serious/critical accessibility violations', async ({ page }) => {
  await page.goto('/learn/how-gurbani-soul-verifies-scripture');
  const results = await new AxeBuilder({ page }).withTags(['wcag2a', 'wcag2aa']).analyze();
  const bad = results.violations.filter((v) => ['serious', 'critical'].includes(v.impact || ''));
  expect(bad, JSON.stringify(bad.map((v) => v.id))).toEqual([]);
});
