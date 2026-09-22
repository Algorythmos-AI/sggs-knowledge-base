import { test, expect } from '@playwright/test';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, resolve } from 'node:path';
import { routes } from '../src/routes';

// Proof for the CSP flip (PR4): load every marketing AND Knowledge Base route under the ENFORCED
// Content-Security-Policy — the exact directive string from vercel.json with "-Report-Only" removed
// — and assert zero CSP violations. Report-Only never blocks anything, so this is the only way to
// know the enforced policy is safe before switching it on. If ANY route reports a violation, the
// vercel.json header must stay Report-Only.
//
// securitypolicyviolation is a DOM event (page.on('console') does NOT see it), so an init script
// records each violation on window.__csp before any page script runs.

const __dirname = dirname(fileURLToPath(import.meta.url));
const vercel = JSON.parse(readFileSync(resolve(__dirname, '../vercel.json'), 'utf8'));
const cspHeader = vercel.headers[0].headers.find((h: { key: string }) =>
  h.key.startsWith('Content-Security-Policy'));
// Enforce whatever is configured, whether it is currently Report-Only or already enforcing.
const ENFORCED_CSP: string = cspHeader.value;

// Every route in the manifest already includes /learn and every /learn/<slug>.
const paths = routes.map((r) => r.path);

declare global {
  interface Window { __csp?: string[]; }
}

for (const path of paths) {
  test(`no CSP violations on ${path} under the enforced policy`, async ({ page }) => {
    // Inject the enforced CSP onto the document response for this navigation.
    await page.route('**/*', async (route) => {
      if (route.request().resourceType() === 'document') {
        const resp = await route.fetch();
        const headers = { ...resp.headers() };
        delete headers['content-security-policy-report-only'];
        headers['content-security-policy'] = ENFORCED_CSP;
        await route.fulfill({ response: resp, headers });
      } else {
        await route.continue();
      }
    });

    await page.addInitScript(() => {
      (window as Window).__csp = [];
      document.addEventListener('securitypolicyviolation', (e) => {
        (window as Window).__csp!.push(`${e.violatedDirective} ${e.blockedURI}`);
      });
    });

    const res = await page.goto(path, { waitUntil: 'load' });
    expect(res?.status(), `${path} did not return 200`).toBe(200);

    // Exercise the interactive surfaces that inject/attach at runtime. Each click is guarded by a
    // visibility check + short timeout so a control hidden in a collapsed nav can never stall.
    const clickIfVisible = async (sel: string) => {
      const el = page.locator(sel).first();
      if ((await el.count()) && (await el.isVisible().catch(() => false))) {
        await el.click({ timeout: 2000 }).catch(() => {});
      }
    };
    await clickIfVisible('#themeBtn');   // theme toggle (visible on desktop marketing/KB)
    await clickIfVisible('.burger');     // mobile hamburger (opens the <dialog> menu)
    await page.waitForTimeout(300);

    const violations = await page.evaluate(() => (window as Window).__csp || []);
    expect(violations, `CSP violations on ${path}: ${JSON.stringify(violations)}`).toEqual([]);
  });
}
