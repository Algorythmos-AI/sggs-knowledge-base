import { test, expect } from '@playwright/test';

// PR4 — security-header smoke. These headers are added by Vercel (frontend/vercel.json) and are
// NOT emitted by serve.py, so this check is meaningful ONLY against a real deployment. It runs
// solely when SMOKE_BASE_URL points at a remote base (the production/staging deploy smoke); locally
// and in CI's serve.py run it is a no-op skip so it can never produce a false failure.
const SMOKE = process.env.SMOKE_BASE_URL;

test.describe('security headers @smoke', () => {
  test.skip(!SMOKE, 'header check runs only against a remote base (set SMOKE_BASE_URL)');

  test('the canonical host serves the security-header set', async ({ request }) => {
    const res = await request.get(SMOKE + '/');
    expect(res.status()).toBe(200);
    const h = res.headers();
    expect(h['x-content-type-options']).toBe('nosniff');
    expect(h['x-frame-options']).toBe('DENY');
    expect(h['referrer-policy']).toBe('no-referrer');
    expect(h['strict-transport-security']).toContain('max-age=');
    // Whichever CSP mode is configured must be present (enforced or report-only).
    const csp = h['content-security-policy'] || h['content-security-policy-report-only'];
    expect(csp, 'no CSP header present').toBeTruthy();
    expect(csp).toContain("default-src 'self'");
  });
});
