import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import path from 'node:path';
import { compactSpec, apiTryHtml } from '../remark-api-try.mjs';
import { REPO_ROOT } from '../paths.mjs';

const spec = JSON.parse(readFileSync(path.join(REPO_ROOT, 'contract', 'openapi.json'), 'utf8'));

test('the compact spec lists every GET route with its parameters', () => {
  const c = compactSpec(spec);
  assert.equal(c.routes.length, Object.keys(spec.paths).length);
  const ang = c.routes.find((r) => r.path === '/api/ang/{n}');
  assert.equal(ang.params[0].in, 'path');
  assert.equal(ang.params[0].schema.maximum, 1430);
  const search = c.routes.find((r) => r.path === '/api/search');
  assert.ok(search.params.find((p) => p.name === 'mode').schema.enum.includes('theme'));
});

test('the element embeds the spec as JSON, safely', () => {
  const html = apiTryHtml(' route="/api/ang/{n}"', { info: { title: 'T' }, paths: { '/x': { get: { summary: 'a<b' } } } });
  assert.match(html, /^<sggs-api-try route="\/api\/ang\/\{n\}"><script type="application\/json" class="api-try__spec">/);
  assert.ok(!html.includes('a<b'));
  assert.ok(html.includes('a\\u003cb'));
});
