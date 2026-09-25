import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import path from 'node:path';
import { repoMapHtml } from '../remark-repo-map.mjs';
import { readAdrs, adrTimelineHtml } from '../remark-adr-timeline.mjs';
import { parseChangelog, releasesHtml } from '../remark-releases.mjs';
import { REPO_ROOT } from '../paths.mjs';

test('the repo map renders nested details with links into each repository', () => {
  const html = repoMapHtml({ repositories: [{ repository: 'o/r', ref: 'main', purpose: 'p', entries: [{ path: 'a/', purpose: 'dir', children: [{ path: 'a/b.py', purpose: 'file' }] }] }] });
  assert.match(html, /<details class="repo-map__repo" open><summary>o\/r/);
  assert.match(html, /href="https:\/\/github\.com\/o\/r\/tree\/main\/a\/b\.py"/);
  assert.match(html, /— file/);
  assert.ok(!/<summary>[^<]*<a /.test(html) && !/<summary><code>[^<]*<\/code><a /.test(html), 'no link inside a summary');
  assert.match(html, /<summary><code>a\/<\/code>/);
});

test('every ADR is read with its status and date, in date order', () => {
  const adrs = readAdrs();
  assert.ok(adrs.length >= 12);
  for (const a of adrs) { assert.match(a.status, /^accepted$/, a.file); assert.match(a.date, /^\d{4}-\d{2}-\d{2}$/, a.file); assert.match(a.href, /^\/adr\//); }
  const html = adrTimelineHtml(adrs);
  assert.match(html, /ADR-0006: Banis/);
  assert.ok(html.indexOf('ADR-0001') < html.indexOf('ADR-0012'));
});

test('the changelog parses its Keep-a-Changelog and legacy sections', () => {
  const rel = parseChangelog(readFileSync(path.join(REPO_ROOT, 'CHANGELOG.md'), 'utf8'));
  const v139 = rel.find((r) => r.version === '1.3.9');
  assert.ok(v139 && v139.date === '2026-09-25' && !v139.legacy && v139.kinds.Added >= 1);
  assert.ok(rel.some((r) => r.legacy && /^2\./.test(r.version)));
  assert.ok(!rel.some((r) => r.version === 'Unreleased'));
  const html = releasesHtml(rel);
  assert.match(html, /releases\/tag\/v1\.3\.9/);
  assert.match(html, /data-text="1\.3\.9 2026-09-25/);
});
