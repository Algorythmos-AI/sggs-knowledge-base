import { test, expect, type Page } from '@playwright/test';
import AxeBuilder from '@axe-core/playwright';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, resolve } from 'node:path';

const here = dirname(fileURLToPath(import.meta.url));
const fx = (name: string) => readFileSync(resolve(here, 'fixtures', name), 'utf8');

/** Search and verify answers depend on the query, so this mock routes by path AND query. */
async function mockEngines(page: Page, up = true) {
  await page.route('**/api/**', async (route) => {
    if (route.request().resourceType() === 'document') return route.fallback();   // the docs pages under /api/…
    const u = new URL(route.request().url());
    const q = u.searchParams.get('q') ?? '';
    const ok = (name: string) => route.fulfill({ status: 200, contentType: 'application/json', body: fx(name) });
    if (!up) return route.fulfill({ status: 503, contentType: 'application/json', body: '{"error":"mocked outage"}' });
    if (u.pathname === '/api/health') return ok('health.json');
    if (u.pathname === '/api/ang/1') return ok('ang-1.json');
    if (u.pathname === '/api/search') {
      if (q === 'sat nam') return ok('search-sat-nam.json');
      if (q === 'waheguru') return ok('search-waheguru.json');
      if (q === 'mercy') return ok('search-mercy.json');
      if (q === 'waheguru ji') return ok('search-honorific.json');
      return ok('search-none.json');
    }
    if (u.pathname === '/api/verify') {
      if (q === 'sochai soch na hovai je sochi lakh vaar' && u.searchParams.get('ang') === '5') return ok('verify-mismatch.json');
      if (q === 'sochai soch na hovai je sochi lakh vaar') return ok('verify-roman.json');
      if (q === 'sochai soch na hovai') return ok('verify-partial.json');
      return ok('verify-none.json');
    }
    return route.fulfill({ status: 404, contentType: 'application/json', body: '{"error":"unknown endpoint"}' });
  });
}

test.describe('search, verify and the API console', () => {
  test('the waterfall simulator runs the initial query, names the tier and lights the poster step', async ({ page }) => {
    await mockEngines(page);
    await page.goto('/architecture/search-waterfall/');
    const wf = page.locator('sggs-waterfall');
    await expect(wf.locator('.wf__tier .chip')).toContainText('mode: variant-match');
    await expect(wf.locator('.lines .line')).toHaveCount(5);
    const first = JSON.parse(fx('search-sat-nam.json')).results[0];
    await expect(wf.locator('.line__gm').first()).toHaveText(first.gurmukhi);
    await expect(wf.locator('.line__cite').first()).toContainText(`Sri Guru Granth Sahib Ji · Ang ${first.ang}`);
    const wt = page.locator('sggs-walkthrough[data-poster="05-search-waterfall"]');
    await expect(wt.locator('.wt__counter')).toHaveText('Step 7 of 12');
    await wf.locator('.wf__example[data-q="waheguru"]').click();
    await expect(wf.locator('.wf__tier .chip')).toContainText('seeker-lexicon');
    await expect(wt.locator('.wt__counter')).toHaveText('Step 6 of 12');
    await wf.locator('.wf__example[data-q="mercy"]').click();
    await expect(wt.locator('.wt__counter')).toHaveText('Step 6 of 12');   // the lexicon answers "mercy" too (daiaa)
    await wf.locator('.wf__input').fill('zzqxv plok');
    await wf.locator('.wf__go').click();
    await expect(wf.locator('.wf__empty')).toBeVisible();
    await expect(wt.locator('.wt__counter')).toHaveText('Step 11 of 12');
  });

  test('the simulator degrades when the API is down', async ({ page }) => {
    await mockEngines(page, false);
    await page.goto('/architecture/search-waterfall/');
    await expect(page.locator('sggs-waterfall .wf__status')).toContainText('not reachable');
    await expect(page.locator('sggs-waterfall .lines')).toHaveCount(0);
  });

  test('the verify playground climbs the ladder and shows the canonical line', async ({ page }) => {
    await mockEngines(page);
    await page.goto('/search/verification-engine/');
    const vf = page.locator('sggs-verify');
    const wt = page.locator('sggs-walkthrough[data-poster="07-verification-engine"]');
    await vf.locator('.vf__example').nth(0).click();
    await expect(vf.locator('.vf__verdict .chip').first()).toHaveText('VERIFIED');
    await expect(wt.locator('.wt__counter')).toHaveText('Step 5 of 7');
    const roman = JSON.parse(fx('verify-roman.json'));
    await expect(vf.locator('.line__gm')).toHaveText(roman.gurmukhi);
    await expect(vf.locator('.line__cite')).toContainText('Sri Guru Granth Sahib Ji · Ang 1');
    await vf.locator('.vf__example').nth(1).click();
    await expect(vf.locator('.vf__verdict .chip').first()).toHaveText('VERIFIED_PARTIAL');
    await expect(wt.locator('.wt__counter')).toHaveText('Step 4 of 7');
    await vf.locator('.vf__example').nth(2).click();
    await expect(vf.locator('.vf__verdict')).toContainText('+ANG_MISMATCH(actual=1)');
    await vf.locator('.vf__example').nth(3).click();
    await expect(vf.locator('.vf__verdict .chip').first()).toHaveText('NOT_FOUND');
    await expect(wt.locator('.wt__counter')).toHaveText('Step 7 of 7');
    await expect(vf.locator('.line__gm')).toHaveCount(0);
  });

  test('the API console builds a form from the spec, sends a request and shows headers', async ({ page }) => {
    await mockEngines(page);
    await page.goto('/api/');
    const at = page.locator('sggs-api-try');
    await expect(at.locator('.at__route')).toHaveValue('/api/ang/{n}');
    await expect(at.locator('.at__url')).toHaveText('/api/ang/712');
    await expect(at.locator('.at__curl')).toContainText("curl -s 'https://gurbanisoul.com/api/ang/712'");
    await at.locator('[name="n"]').fill('1');
    await expect(at.locator('.at__url')).toHaveText('/api/ang/1');
    await at.locator('.at__send').click();
    await expect(at.locator('.at__headers .chip').first()).toHaveText('200 OK');
    await expect(at.locator('.at__body')).toContainText('"ang": 1');
    await at.locator('.at__route').selectOption('/api/search');
    await expect(at.locator('[name="mode"]')).toBeVisible();
    await expect(at.locator('.at__url')).toHaveText('/api/search?q=sat+nam&mode=auto&limit=5');
    const options = await at.locator('.at__route option').count();
    expect(options).toBe(26);
  });

  test('the generated routes page lists every route and keeps its header', async ({ page }) => {
    await mockEngines(page);
    await page.goto('/api/routes/');
    await expect(page.locator('main')).toContainText('/api/verify');
    await expect(page.locator('main table').first()).toBeVisible();
  });

  for (const path of ['/architecture/search-waterfall/', '/search/', '/search/modes-and-tiers/', '/search/the-roman-fold/', '/search/verification-engine/', '/search/harnesses-and-golden-vectors/', '/api/', '/api/routes/', '/api/contract-and-openapi/', '/api/versioning-and-caching/']) {
    test(`no accessibility violations: ${path}`, async ({ page }) => {
      await mockEngines(page);
      await page.goto(path);
      const results = await new AxeBuilder({ page }).withTags(['wcag2a', 'wcag2aa', 'wcag21aa']).analyze();
      expect(results.violations, JSON.stringify(results.violations, null, 1)).toEqual([]);
    });
  }
});
