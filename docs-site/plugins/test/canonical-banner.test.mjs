import test from 'node:test';
import assert from 'node:assert/strict';
import { canonicalBanner, rewriteLink, pinnedPageFor } from '../remark-repo-links.mjs';

const sources = { 'sggs-data': { repository: 'Algorythmos-AI/sggs-data', commit: 'c'.repeat(40), alias: 'data', include: ['docs/architecture/*.md'], files: { 'docs/architecture/database-schema.md': { sha256: '0'.repeat(64), blob: '0'.repeat(40) } } } };

test('a sibling page gets the pinned-copy banner; a platform page does not', () => {
  const b = canonicalBanner('docs-site/.sources/sggs-data/docs/architecture/database-schema.md', sources);
  assert.match(b, /Pinned copy/);
  assert.match(b, /github\.com\/Algorythmos-AI\/sggs-data\/blob\/c{40}\/docs\/architecture\/database-schema\.md/);
  assert.match(b, /sggs-data\/docs\/architecture\/database-schema\.md/);
  assert.equal(canonicalBanner('docs/architecture/overview.md', sources), null);
});

test('a sibling link to an unpublished Markdown file goes to GitHub at the pin, a code file too', () => {
  const from = 'docs-site/.sources/sggs-data/docs/architecture/database-schema.md';
  assert.match(rewriteLink('../design/00_Build-Plan.md', from, sources), /github\.com\/Algorythmos-AI\/sggs-data\/blob\/c{40}\/docs\/design\/00_Build-Plan\.md$/);
  assert.match(rewriteLink('../../pipeline/reconcile.py', from, sources), /blob\/c{40}\/pipeline\/reconcile\.py$/);
});

test('a GitHub link to a pinned sibling document stays on the wiki; others are left alone', () => {
  assert.equal(pinnedPageFor('https://github.com/Algorythmos-AI/sggs-data/blob/main/docs/architecture/database-schema.md#gotchas', sources), '/data/architecture/database-schema/#gotchas');
  assert.equal(rewriteLink('https://github.com/Algorythmos-AI/sggs-data/blob/main/docs/architecture/database-schema.md', 'docs/README.md', sources), '/data/architecture/database-schema/');
  assert.equal(pinnedPageFor('https://github.com/Algorythmos-AI/sggs-data/blob/main/docs/design/x.md', sources), null);
  assert.equal(rewriteLink('https://github.com/Algorythmos-AI/sggs-data/blob/main/pipeline/reconcile.py', 'docs/README.md', sources), 'https://github.com/Algorythmos-AI/sggs-data/blob/main/pipeline/reconcile.py');
});

test('a link to the generated API reference resolves to its virtual page', () => {
  assert.equal(rewriteLink('reference/', 'docs/api/README.md', sources), '/api/reference/');
  assert.equal(rewriteLink('../api/reference/#tag/search', 'docs/search/README.md', sources), '/api/reference/#tag/search');
});
