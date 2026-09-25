import { test, expect } from '@playwright/test';
import AxeBuilder from '@axe-core/playwright';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, resolve } from 'node:path';
import { mockApi } from './helpers';

const here = dirname(fileURLToPath(import.meta.url));
const ang = (n: number) => JSON.parse(readFileSync(resolve(here, 'fixtures', `ang-${n}.json`), 'utf8'));
const FIX = { '/api/health': 'health.json', '/api/ang/1': 'ang-1.json', '/api/ang/712': 'ang-712.json' };

test.describe('data & pipeline', () => {
  test('the Ang explorer lists every line record verbatim, with column definitions', async ({ page }) => {
    await mockApi(page, FIX);
    await page.goto('/data/line-record/');
    const ax = page.locator('sggs-ang-explorer');
    const a1 = ang(1);
    await expect(ax.locator('tbody tr')).toHaveCount(a1.lines.length);
    await expect(ax.locator('.ax__status')).toContainText(`Ang 1 · ${a1.lines.length} lines`);
    await expect(ax.locator('tbody tr').first().locator('td[data-col="gurmukhi"] [lang="pa"]')).toHaveText(a1.lines[0].gurmukhi);
    await expect(ax.locator('tbody tr').first().locator('td[data-col="author"]')).toHaveText('null');
    await expect(ax.locator('th abbr[title]')).toHaveCount(8);       // English column hidden until asked
    await ax.locator('.ax__en-box').check();
    await expect(ax.locator('th abbr[title]')).toHaveCount(9);
  });

  test('quick picks, filters and prev/next drive the explorer', async ({ page }) => {
    await mockApi(page, FIX);
    await page.goto('/data/line-record/');
    const ax = page.locator('sggs-ang-explorer');
    const a712 = ang(712);
    await ax.locator('.ax__pick[data-ang="712"]').click();
    await expect(ax.locator('.ax__status')).toContainText('continues from Ang 711');
    await expect(ax.locator('tbody tr')).toHaveCount(a712.lines.length);
    await ax.locator('.ax__filter[data-filter="headers"]').click();
    await expect(ax.locator('tbody tr')).toHaveCount(a712.lines.filter((l: any) => l.is_header === 1).length);
    await expect(ax.locator('tbody tr.is-header')).toHaveCount(a712.lines.filter((l: any) => l.is_header === 1).length);
    await ax.locator('.ax__filter[data-filter="rahao"]').click();
    await expect(ax.locator('tbody tr')).toHaveCount(a712.lines.filter((l: any) => l.is_rahao === 1).length);
    await ax.locator('.ax__filter[data-filter="all"]').click();
    await ax.locator('.ax__prev').click();                      // 711 is not mocked -> outage text
    await expect(ax.locator('.ax__status')).toContainText('not reachable');
    await ax.locator('.ax__input').fill('1');
    await ax.locator('.ax__go').click();
    await expect(ax.locator('.ax__status')).toContainText('Ang 1 ·');
  });

  test('the explorer degrades to prose when the API is down', async ({ page }) => {
    await mockApi(page, { '/api/health': 'health.json' });
    await page.goto('/data/line-record/');
    await expect(page.locator('sggs-ang-explorer .ax__status')).toContainText('not reachable');
    await expect(page.locator('sggs-ang-explorer table')).toHaveCount(0);
  });

  test('code excerpts are read from the source and link to the exact commit', async ({ page }) => {
    await mockApi(page, FIX);
    await page.goto('/data/pipeline/');
    const frames = page.locator('.expressive-code');
    await expect(frames).toHaveCount(4);
    await expect(page.locator('.expressive-code .title').first()).toContainText('sggs-data/pipeline/sggs_pipeline.py · fix_text · lines');
    await expect(page.locator('.expressive-code').first()).toContainText('def fix_text(s):');
    const links = page.locator('.excerpt__source a');
    await expect(links).toHaveCount(4);
    await expect(links.first()).toHaveAttribute('href', /github\.com\/Algorythmos-AI\/sggs-data\/blob\/[0-9a-f]{40}\/pipeline\/sggs_pipeline\.py#L\d+-L\d+/);
  });

  test('a pinned sggs-data page carries the canonical banner and keeps its links', async ({ page }) => {
    await mockApi(page, FIX);
    await page.goto('/data/architecture/database-schema/');
    const banner = page.locator('aside.canonical');
    await expect(banner).toContainText('Pinned copy');
    await expect(banner.locator('a').first()).toHaveAttribute('href', /github\.com\/Algorythmos-AI\/sggs-data\/blob\/[0-9a-f]{40}\/docs\/architecture\/database-schema\.md/);
    await expect(page.locator('a.edit-link').first()).toHaveAttribute('href', /sggs-data\/edit\/[0-9a-f]{40}\//);
    // the landing page's GitHub link to this document now stays on the wiki
    await page.goto('/');
    await expect(page.locator('a[href="/data/architecture/database-schema/"]').first()).toBeVisible();
  });

  for (const path of ['/data/', '/data/line-record/', '/data/pipeline/', '/data/dataset-pin/', '/data/editorial-ledger/', '/data/architecture/scripture-integrity/', '/engineering/known-issues/']) {
    test(`no accessibility violations: ${path}`, async ({ page }) => {
      await mockApi(page, FIX);
      await page.goto(path);
      const results = await new AxeBuilder({ page }).withTags(['wcag2a', 'wcag2aa', 'wcag21aa']).analyze();
      expect(results.violations, JSON.stringify(results.violations, null, 1)).toEqual([]);
    });
  }
});
