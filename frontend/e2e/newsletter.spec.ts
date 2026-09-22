import { test, expect } from '@playwright/test';

// PR4 — the launch-notice sign-up is ENV-GATED (PUBLIC_NEWSLETTER_FORM_URL). It is UNSET in CI,
// locally and in this build, so the section must be entirely absent: no form, and no request to
// Buttondown from the landing.

test('landing has no newsletter form and makes no Buttondown request (env unset) @smoke', async ({ page }) => {
  const buttondownRequests: string[] = [];
  page.on('request', (req) => {
    if (req.url().includes('buttondown.com')) buttondownRequests.push(req.url());
  });

  await page.goto('/');
  await page.waitForLoadState('networkidle').catch(() => {});

  await expect(page.locator('form.newsletter')).toHaveCount(0);
  expect(buttondownRequests, JSON.stringify(buttondownRequests)).toEqual([]);
});

// Documents the enabled-path behaviour for when PUBLIC_NEWSLETTER_FORM_URL is set at build time.
// Skipped here because this build ships with the env var unset (no form to drive):
//  * a single visible <input type="email" name="email" required> + a submit button render;
//  * on submit the honeypot (hp_name) short-circuits to a no-op if filled;
//  * otherwise it POSTs ONLY the email field (mode:'no-cors') to the form action, then shows
//    "Check your inbox to confirm — we sent one email.";
//  * offline / rejected fetch shows the "You appear to be offline…" hint;
//  * with JS disabled the native POST still reaches Buttondown's own confirmation page.
test.skip('enabled path: email-only submit, honeypot no-op, inline confirmation', async () => {
  // Enable by building with PUBLIC_NEWSLETTER_FORM_URL set to the Buttondown embed endpoint.
});
