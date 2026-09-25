import test from 'node:test';
import assert from 'node:assert/strict';
import { idForRepoPath, sitePathForId, githubUrlForRepoPath, originOf } from '../paths.mjs';

const sources = { 'sggs-data': { repository: 'Algorythmos-AI/sggs-data', commit: 'a'.repeat(40), alias: 'data', include: ['docs/**/*.md', 'Answer-Protocol.md'] } };

test('platform pages map to ids and site paths', () => {
  assert.equal(idForRepoPath('docs/README.md'), 'index');
  assert.equal(sitePathForId('index'), '/');
  assert.equal(idForRepoPath('docs/engineering/README.md'), 'engineering');
  assert.equal(sitePathForId('engineering'), '/engineering/');
  assert.equal(idForRepoPath('docs/architecture/Overview.md'), 'architecture/overview');
  assert.equal(sitePathForId('architecture/overview'), '/architecture/overview/');
});

test('history and non-markdown are not published', () => {
  assert.equal(idForRepoPath('docs/reports/archive/Audit_Report.md'), null);
  assert.equal(idForRepoPath('docs/design/00_Build-Plan.md'), null);
  assert.equal(idForRepoPath('docs/brand/tokens.json'), null);
  assert.equal(idForRepoPath('CONTRIBUTING.md'), null);
  assert.equal(idForRepoPath('webapp/serve.py'), null);
});

test('pinned sibling docs publish under their alias at the pinned commit', () => {
  assert.equal(idForRepoPath('docs-site/.sources/sggs-data/docs/architecture/scripture-integrity.md', sources), 'data/architecture/scripture-integrity');
  assert.equal(idForRepoPath('docs-site/.sources/sggs-data/Answer-Protocol.md', sources), 'data/answer-protocol');
  assert.equal(idForRepoPath('docs-site/.sources/unknown-repo/docs/x.md', sources), null);
  const o = originOf('docs-site/.sources/sggs-data/pipeline/build_db.py', sources);
  assert.equal(o.kind, 'sibling');
  assert.equal(githubUrlForRepoPath('docs-site/.sources/sggs-data/pipeline/build_db.py', { sources }), `https://github.com/Algorythmos-AI/sggs-data/blob/${'a'.repeat(40)}/pipeline/build_db.py`);
});

test('platform files link to the trunk on GitHub', () => {
  assert.equal(githubUrlForRepoPath('webapp/serve.py'), 'https://github.com/Algorythmos-AI/sggs-platform/blob/integration/webapp/serve.py');
  assert.equal(githubUrlForRepoPath('docs/design', { isDir: true }), 'https://github.com/Algorythmos-AI/sggs-platform/tree/integration/docs/design');
});
