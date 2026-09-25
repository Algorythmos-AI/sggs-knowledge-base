import { test, expect } from '@playwright/test';
import AxeBuilder from '@axe-core/playwright';
import { mockApi } from './helpers';

const PAGES = ['/', '/architecture/overview/', '/engineering/invariants/', '/process/runbooks/deploy/', '/glossary/', '/adr/0007-three-repositories/'];

test.describe('the wiki', () => {
  test('home page identifies the build and the scripture', async ({ page }) => {
    await mockApi(page);
    await page.goto('/');
    await expect(page).toHaveTitle(/Sri Guru Granth Sahib Ji/);
    const commit = await page.locator('meta[name="sggs-docs-commit"]').getAttribute('content');
    expect(commit).toMatch(/^[0-9a-f]{7,40}$|^unknown$/);
  });

  test('the live status strip renders from /api/health and degrades on an outage', async ({ page }) => {
    await mockApi(page);
    await page.goto('/');
    const status = page.locator('sggs-status .status');
    await expect(status).toContainText('v1.3.9');
    await expect(status).toContainText('7/7 health checks');
    await expect(status.locator('.chip--ok')).toHaveCount(1);

    await mockApi(page, { '/api/health': null });
    await page.goto('/');
    await expect(page.locator('sggs-status .status')).toContainText('unavailable');
  });

  test('overflowing code and tables are keyboard-scrollable', async ({ page }) => {
    await mockApi(page);
    await page.goto('/process/runbooks/deploy/');
    const focusable = page.locator('.sl-markdown-content :is(pre, table)[tabindex="0"]');
    await expect(focusable.first()).toBeVisible();
    await focusable.first().focus();
    await expect(focusable.first()).toBeFocused();
  });

  test('Mermaid diagrams are inline, accessible SVG — never a code block', async ({ page }) => {
    await mockApi(page);
    await page.goto('/architecture/overview/');
    const figures = page.locator('figure[data-diagram="mermaid"]');
    await expect(figures).toHaveCount(3);
    // drawn in both palettes; exactly one is shown (the light one in a light scheme), one title read out
    await expect(figures.first().locator('.mmd--light svg')).toBeVisible();
    await expect(figures.first().locator('.mmd--dark svg')).toBeHidden();
    await expect(figures.first().locator('svg:visible title')).toHaveCount(1);
    await expect(page.locator('pre code.language-mermaid')).toHaveCount(0);
  });

  test('in the dark scheme the diagrams are drawn in the dark palette', async ({ page }) => {
    await mockApi(page);
    await page.addInitScript(() => { try { localStorage.setItem('starlight-theme', 'dark'); } catch { /* private window */ } });
    await page.goto('/architecture/overview/');
    const first = page.locator('figure[data-diagram="mermaid"]').first();
    await expect(first.locator('.mmd--dark svg')).toBeVisible();
    await expect(first.locator('.mmd--light svg')).toBeHidden();
    const bg = await first.evaluate((f) => getComputedStyle(f).backgroundColor);
    expect(bg).toBe('rgb(30, 26, 23)');   // the ink card, not a cream card on a dark page
  });

  test('relative links written for GitHub resolve on the site', async ({ page }) => {
    await mockApi(page);
    await page.goto('/engineering/');
    const link = page.locator('.sl-markdown-content a[href="/engineering/invariants/"]').first();
    await expect(link).toBeVisible();
    await link.click();
    await expect(page).toHaveURL(/\/engineering\/invariants\/$/);
    // a link to a file that is not a wiki page goes to GitHub at the trunk
    await page.goto('/engineering/');
    await expect(page.locator('.sl-markdown-content a[href^="https://github.com/Algorythmos-AI/sggs-platform/blob/integration/"]').first()).toBeVisible();
  });

  test('search is indexed and finds a technical term', async ({ page, isMobile }) => {
    test.skip(isMobile, 'the search dialog is exercised on desktop');
    await mockApi(page);
    await page.goto('/');
    const open = page.locator('button[data-open-modal]');
    await expect(open).toBeEnabled({ timeout: 15_000 });   // enabled once Pagefind has loaded
    await open.click();
    await page.locator('dialog input[type="search"], dialog input.pagefind-ui__search-input').first().fill('comp_id');
    await expect(page.locator('dialog .pagefind-ui__result-link').first()).toBeVisible({ timeout: 15_000 });
  });

  test('dark and light themes both set an explicit page background', async ({ page }) => {
    await mockApi(page);
    await page.goto('/');
    for (const theme of ['dark', 'light']) {
      await page.evaluate((t) => document.documentElement.setAttribute('data-theme', t), theme);
      const bg = await page.evaluate(() => getComputedStyle(document.body).backgroundColor);
      expect(bg).not.toBe('rgba(0, 0, 0, 0)');
    }
  });

  test('edit link points at the page\'s real home in the repository', async ({ page }) => {
    await mockApi(page);
    await page.goto('/architecture/overview/');
    const edit = page.locator('a.edit-link', { hasText: 'Edit this page' });
    await expect(edit).toHaveAttribute('href', 'https://github.com/Algorythmos-AI/sggs-platform/edit/integration/docs/architecture/overview.md');
  });

  for (const path of PAGES) {
    test(`no accessibility violations, no console errors: ${path}`, async ({ page }) => {
      const errors: string[] = [];
      page.on('console', (m) => { if (m.type() === 'error') errors.push(m.text()); });
      page.on('pageerror', (e) => errors.push(e.message));
      await mockApi(page, { '/api/health': 'health.json', '/api/search': 'search-sat-nam.json' });   // the home page runs a first search
      await page.goto(path);
      const results = await new AxeBuilder({ page }).withTags(['wcag2a', 'wcag2aa', 'wcag21aa']).analyze();
      expect(results.violations, JSON.stringify(results.violations, null, 1)).toEqual([]);
      expect(errors).toEqual([]);
    });
  }
});
