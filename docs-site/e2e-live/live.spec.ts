import { test, expect, type Page } from '@playwright/test';
import AxeBuilder from '@axe-core/playwright';

// The deployed wiki against the real production API (playwright.live.config.ts). Every widget that
// reads the API is exercised end to end. No scripture is typed here: the one line the verify test
// uses is read from /api/ang/1 at run time and pasted back in, exactly as the API returned it.

/** Collect anything a page reports as broken: a script the CSP blocked, an uncaught error, a failed API call. */
function watch(page: Page) {
  const problems: string[] = [];
  page.on('console', (m) => { if (m.type() === 'error' && /Content Security Policy|Refused to/i.test(m.text())) problems.push(`CSP: ${m.text()}`); });
  page.on('pageerror', (e) => problems.push(`uncaught: ${e.message}`));
  page.on('response', (r) => { if (new URL(r.url()).pathname.startsWith('/api/') && r.status() >= 400) problems.push(`${r.status()} ${new URL(r.url()).pathname}`); });
  return problems;
}

test('the status strip reports every health check green', async ({ page }) => {
  const problems = watch(page);
  await page.goto('/');
  const strip = page.locator('sggs-status .status');
  await expect(strip).not.toHaveClass(/status--pending/, { timeout: 20_000 });
  await expect(strip).toContainText(/\d+\/\d+ health checks/);
  const text = await strip.innerText();
  const [ok, all] = /(\d+)\/(\d+) health checks/.exec(text)!.slice(1).map(Number);
  expect(ok, text).toBe(all);
  expect(problems).toEqual([]);
});

test('the search simulator answers a real query, verbatim with its Ang', async ({ page }) => {
  const problems = watch(page);
  await page.goto('/architecture/search-waterfall/');
  const wf = page.locator('sggs-waterfall');
  await wf.locator('.wf__input').fill('sat nam');
  await wf.getByRole('button', { name: /run/i }).click();
  await expect(wf.locator('.wf__tier .chip').first()).toContainText('mode:', { timeout: 20_000 });
  await expect(wf.locator('.lines .line').first()).toBeVisible();
  await expect(wf.locator('.line__cite').first()).toContainText(/Sri Guru Granth Sahib Ji · Ang \d+/);
  expect(problems).toEqual([]);
});

test('the Ang explorer opens Angs 1, 712 and 1256 from the live API', async ({ page, request }) => {
  const problems = watch(page);
  await page.goto('/data/line-record/');
  const ax = page.locator('sggs-ang-explorer');
  for (const n of [1, 712, 1256]) {
    const want = (await (await request.get(`/api/ang/${n}`)).json()).lines.length;
    await ax.locator('.ax__input').fill(String(n));
    await ax.locator('.ax__go').click();
    await expect(ax.locator('.ax__status')).toContainText(`Ang ${n} · ${want} lines`, { timeout: 20_000 });
    await expect(ax.locator('tbody tr')).toHaveCount(want);
  }
  expect(problems).toEqual([]);
});

test('a line read from the API verifies as exact at its Ang', async ({ page, request }) => {
  const problems = watch(page);
  const ang1 = await (await request.get('/api/ang/1')).json();
  const line = ang1.lines.find((l: { is_header: number }) => l.is_header === 0);
  expect(line, 'Ang 1 has a verse line').toBeTruthy();
  await page.goto('/search/verification-engine/');
  const vf = page.locator('sggs-verify');
  await vf.locator('.vf__claim').fill(line.gurmukhi);
  await vf.locator('.vf__ang').fill('1');
  await vf.locator('.vf__go').click();
  await expect(vf.locator('.vf__verdict .chip').first()).toHaveText(/^VERIFIED_EXACT/, { timeout: 20_000 });
  await expect(vf.locator('.line__cite')).toContainText('Sri Guru Granth Sahib Ji · Ang 1');
  expect(problems).toEqual([]);
});

test('the API console sends a real request', async ({ page }) => {
  const problems = watch(page);
  await page.goto('/api/');
  const at = page.locator('sggs-api-try');
  await at.locator('[name="n"]').fill('1');
  await at.locator('.at__send').click();
  await expect(at.locator('.at__headers .chip').first()).toHaveText(/^200\b/, { timeout: 20_000 });   // HTTP/2 has no reason phrase
  await expect(at.locator('.at__body')).toContainText('"ang": 1');
  expect(problems).toEqual([]);
});

test('search (⌘K) finds a technical term on the deployed index', async ({ page }) => {
  await page.goto('/');
  const open = page.locator('button[data-open-modal]');
  await expect(open).toBeEnabled({ timeout: 20_000 });
  await open.click();
  await page.locator('dialog input[type="search"], dialog input.pagefind-ui__search-input').first().fill('comp_id');
  await expect(page.locator('dialog .pagefind-ui__result-link').first()).toBeVisible({ timeout: 20_000 });
});

for (const path of ['/', '/architecture/overview/', '/data/line-record/', '/search/verification-engine/', '/scripture/what-sggs-is/']) {
  test(`axe, as deployed: ${path}`, async ({ page }) => {
    const problems = watch(page);
    // the settled page: every widget has had its answer (the loading states are held to axe
    // deterministically by the mocked suite, e2e/site.spec.ts), so a slow API never flips this test
    const res = await page.goto(path, { waitUntil: 'networkidle' });
    expect(res?.status()).toBe(200);
    expect(res?.headers()['content-security-policy'], 'served with its CSP').toContain("script-src 'self'");
    const results = await new AxeBuilder({ page }).withTags(['wcag2a', 'wcag2aa', 'wcag21aa']).analyze();
    expect(results.violations, JSON.stringify(results.violations, null, 1)).toEqual([]);
    expect(problems).toEqual([]);
  });
}
