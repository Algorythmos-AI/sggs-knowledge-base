// serve-dist applies docs-site/vercel.json's headers, so the e2e suite runs under the production CSP.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { toRegExp, headersFor } from '../../scripts/serve-dist.mjs';

test('vercel source patterns become anchored regexps', () => {
  assert.ok(toRegExp('/(.*)').test('/architecture/overview/'));
  assert.ok(toRegExp('/(.*)').test('/'));
  assert.ok(toRegExp('/_astro/:path*').test('/_astro/a/b.js'));
  assert.ok(!toRegExp('/_astro/:path*').test('/fonts/x.woff2'));
  assert.ok(toRegExp('/api/:name').test('/api/health'));
  assert.ok(!toRegExp('/api/:name').test('/api/health/x'));
  assert.ok(!toRegExp('/a.b').test('/aXb'));                   // literals are escaped
});

test('every page gets the production security headers, including the CSP', () => {
  const h = headersFor('/scripture/structure/');
  assert.match(h['content-security-policy'], /default-src 'self'/);
  assert.equal(h['x-content-type-options'], 'nosniff');
  assert.equal(h['x-frame-options'], 'DENY');
  assert.equal(h['cache-control'], undefined);                 // local serving stays no-store
});
