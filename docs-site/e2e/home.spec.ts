import { test, expect } from '@playwright/test';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, resolve } from 'node:path';
import { mockApi } from './helpers';

// The front door: the hero poster, ten minutes to a first search (the live simulator, limited to
// three results), the four path cards, the latest releases; the Brand index and its palette; the
// generated API reference inside the API group; a phone header that never cuts the scripture's name.
const here = dirname(fileURLToPath(import.meta.url));
const fx = (name: string) => readFileSync(resolve(here, 'fixtures', name), 'utf8');

test.describe('the home page', () => {
  test('hero poster, the four path cards, and the three newest releases without a filter', async ({ page }) => {
    await mockApi(page);
    await page.goto('/');
    await expect(page.locator('figure.poster').first()).toBeVisible();
    const cards = page.locator('ul.sggs-cards > li.sggs-card');
    await expect(cards).toHaveCount(4);
    await expect(cards.locator('a.sggs-card__title')).toHaveText(['Platform engineer', 'Data engineer', 'iOS engineer', 'Reviewer or scholar']);
    await expect(cards.first()).not.toContainText('—');                 // the Markdown dash stays on GitHub only
    const releases = page.locator('sggs-releases[limit="3"] .release');
    await expect(releases).toHaveCount(3);
    await expect(page.locator('sggs-releases[limit="3"] input')).toHaveCount(0);
  });

  test('the whole card is the link', async ({ page }) => {
    await mockApi(page);
    await page.goto('/');
    const card = page.locator('li.sggs-card').first();
    await card.scrollIntoViewIfNeeded();
    const box = (await card.boundingBox())!;
    await page.mouse.click(box.x + box.width - 12, box.y + box.height - 12);   // a corner, far from the title
    await expect(page).toHaveURL(/\/learning-paths\/platform-engineer\/$/);
  });

  test('the first search runs against the API with a limit of three', async ({ page }) => {
    let asked = '';
    await page.route('**/api/**', async (route) => {
      if (route.request().resourceType() === 'document') return route.fallback();
      const u = new URL(route.request().url());
      if (u.pathname === '/api/search') { asked = u.search; return route.fulfill({ status: 200, contentType: 'application/json', body: fx('search-sat-nam.json') }); }
      if (u.pathname === '/api/health') return route.fulfill({ status: 200, contentType: 'application/json', body: fx('health.json') });
      return route.fulfill({ status: 503, contentType: 'application/json', body: '{}' });
    });
    await page.goto('/');
    const sim = page.locator('sggs-waterfall');
    await sim.getByRole('button', { name: /run/i }).click();
    await expect(sim.locator('.wf__tier')).toBeVisible();
    expect(new URLSearchParams(asked).get('limit')).toBe('3');
    expect(new URLSearchParams(asked).get('q')).toBe('sat nam');
  });
});

test.describe('brand, the API reference and the header', () => {
  test('the Brand index renders the palette from the tokens, both legs', async ({ page }) => {
    await mockApi(page);
    const res = await page.goto('/brand/');
    expect(res?.status()).toBe(200);
    const groups = page.locator('.swatches table.swatches__group');
    await expect(groups).toHaveCount(4);
    const gold = page.locator('tr', { has: page.locator('th code', { hasText: 'soul.accentFill' }) });
    await expect(gold.locator('td').first()).toContainText('#FFBC0D');
    await expect(gold.locator('td').first()).toContainText('1.58:1');   // why gold is a fill, never text
  });

  test('the generated API reference sits inside the API group and renders an operation', async ({ page }) => {
    await mockApi(page);
    await page.goto('/api/');
    // the sidebar is in the DOM on a phone too (inside the menu), so count elements rather than roles
    const api = page.locator('nav[aria-label="Main"] details', { has: page.locator('> summary', { hasText: /^\s*API\s*$/ }) }).first();
    await expect(api.locator('a', { hasText: 'The JSON API' })).toHaveCount(1);
    await expect(api.locator('summary', { hasText: 'API reference' })).toHaveCount(1);
    const res = await page.goto('/api/reference/operations/meta/');
    expect(res?.status()).toBe(200);
    await expect(page.locator('h1')).toBeVisible();
    await expect(page.locator('main')).toContainText('/api/meta');
  });

  test('on a phone the header keeps the scripture\'s name whole and drops the suffix', async ({ page }, testInfo) => {
    await mockApi(page);
    await page.goto('/');
    const suffix = page.locator('.site-title__suffix');
    if (testInfo.project.name === 'mobile') {
      await expect(suffix).toHaveCSS('clip', 'rect(0px, 0px, 0px, 0px)');
      const title = page.locator('a.site-title');
      const fits = await title.evaluate((a) => (a.firstElementChild as HTMLElement).scrollWidth <= (a.firstElementChild as HTMLElement).clientWidth + 1);
      expect(fits, 'the visible title is not cut').toBe(true);
    } else {
      await expect(suffix).toBeVisible();
    }
    await expect(page.locator('a.site-title')).toHaveAccessibleName(/Sri Guru Granth Sahib Ji — Knowledge Base/);
  });
});
