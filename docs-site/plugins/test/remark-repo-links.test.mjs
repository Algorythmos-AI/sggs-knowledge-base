import test from 'node:test';
import assert from 'node:assert/strict';
import { rewriteLink } from '../remark-repo-links.mjs';

const from = 'docs/engineering/README.md';
const sources = {};

test('links to published pages become site paths, anchors kept', () => {
  assert.equal(rewriteLink('invariants.md', from, sources), '/engineering/invariants/');
  assert.equal(rewriteLink('invariants.md#prime-directive', from, sources), '/engineering/invariants/#prime-directive');
  assert.equal(rewriteLink('../architecture/overview.md', from, sources), '/architecture/overview/');
  assert.equal(rewriteLink('../README.md', from, sources), '/');
});

test('links to directories resolve to their index page or the GitHub tree', () => {
  assert.equal(rewriteLink('../adr/', from, sources), '/adr/');   // docs/adr/README.md is the decisions index
  assert.equal(rewriteLink('../design/', from, sources), 'https://github.com/Algorythmos-AI/sggs-platform/tree/integration/docs/design');   // never published
  assert.equal(rewriteLink('../process/', from, sources), 'https://github.com/Algorythmos-AI/sggs-platform/tree/integration/docs/process');
  assert.equal(rewriteLink('../', from, sources), '/');
  assert.equal(rewriteLink('../website/', from, sources), '/website/');
});

test('links to code, data and history go to GitHub', () => {
  assert.equal(rewriteLink('../../CONTRIBUTING.md', from, sources), 'https://github.com/Algorythmos-AI/sggs-platform/blob/integration/CONTRIBUTING.md');
  assert.equal(rewriteLink('../brand/tokens.json', from, sources), 'https://github.com/Algorythmos-AI/sggs-platform/blob/integration/docs/brand/tokens.json');
  assert.equal(rewriteLink('../reports/archive/Audit_Report.md', from, sources), 'https://github.com/Algorythmos-AI/sggs-platform/blob/integration/docs/reports/archive/Audit_Report.md');
});

test('absolute, anchor and mailto links are untouched', () => {
  for (const u of ['https://example.com/x.md', '/architecture/', '#section', 'mailto:support@gurbanisoul.com', '//cdn.example.com/a']) {
    assert.equal(rewriteLink(u, from, sources), u);
  }
});
