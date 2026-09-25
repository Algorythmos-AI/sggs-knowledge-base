import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, writeFileSync, mkdirSync } from 'node:fs';
import { tmpdir } from 'node:os';
import path from 'node:path';
import { findSymbol, parseLines, parseElement, excerptNodes, resolveTarget } from '../remark-code-excerpt.mjs';

const PY = `import os\n\n# ---- helpers\n@decorated\ndef fix_text(s):\n    """doc"""\n    if s:\n        return s\n    return None\n\n\ndef other():\n    pass\n`;
const JS = `export const A = 1;\nexport function build(spec) {\n  const x = { a: '}' };\n  return x;\n}\nconst B = 2;\n`;
const SWIFT = `struct Manifest {\n    let a: Int\n}\nfunc check() -> Bool {\n    return true\n}\n`;

test('python: a def runs to the end of its block and includes decorators', () => {
  assert.deepEqual(findSymbol(PY, 'fix_text', 'python'), [4, 9]);
  assert.deepEqual(findSymbol(PY, 'other', 'python'), [12, 13]);
  assert.equal(findSymbol(PY, 'missing', 'python'), null);
});

test('js and swift: braces are balanced, strings ignored', () => {
  assert.deepEqual(findSymbol(JS, 'build', 'js'), [2, 5]);
  assert.deepEqual(findSymbol(JS, 'A', 'js'), [1, 1]);
  assert.deepEqual(findSymbol(SWIFT, 'Manifest', 'swift'), [1, 3]);
  assert.deepEqual(findSymbol(SWIFT, 'check', 'swift'), [4, 6]);
});

test('lines= is validated', () => {
  assert.deepEqual(parseLines('3-9'), [3, 9]);
  assert.throws(() => parseLines('9-3'), /lines=/);
  assert.throws(() => parseLines('x'), /lines=/);
});

test('the element emitted by remark-widgets is parsed', () => {
  assert.deepEqual(parseElement('<sggs-code file="a.py" symbol="f"></sggs-code>'), { file: 'a.py', symbol: 'f' });
  assert.equal(parseElement('<sggs-status></sggs-status>'), null);
});

test('an excerpt is a titled code block plus a commit-pinned GitHub link; missing targets fail', () => {
  const repo = mkdtempSync(path.join(tmpdir(), 'excerpt-'));
  mkdirSync(path.join(repo, 'pipeline'));
  writeFileSync(path.join(repo, 'pipeline', 'x.py'), PY);
  const sources = { 'sggs-data': { repository: 'Algorythmos-AI/sggs-data', commit: 'a'.repeat(40), alias: 'data', include: [], files: { 'pipeline/x.py': { sha256: '0'.repeat(64), blob: '0'.repeat(40) } } } };
  const t = resolveTarget({ file: 'pipeline/x.py', repo: 'sggs-data' }, sources);
  assert.match(t.url(4, 9), /sggs-data\/blob\/a{40}\/pipeline\/x\.py#L4-L9$/);
  assert.throws(() => resolveTarget({ file: 'pipeline/y.py', repo: 'sggs-data' }, sources), /does not pin/);
  assert.throws(() => resolveTarget({ file: 'x.py', repo: 'nope' }, sources), /unknown repo/);
  assert.throws(() => resolveTarget({ file: '../etc/passwd' }, sources), /bad file/);
  // platform target resolved against the real repository: this test file itself
  const nodes = excerptNodes({ file: 'docs-site/plugins/test/remark-code-excerpt.test.mjs', lines: '1-2' }, { sources, commit: 'b'.repeat(40) });
  assert.equal(nodes[0].type, 'code'); assert.equal(nodes[0].lang, 'js');
  assert.match(nodes[0].meta, /title='?"?docs-site\/plugins\/test\/remark-code-excerpt\.test\.mjs · lines 1–2/);
  assert.match(nodes[1].value, /blob\/b{40}\/docs-site\/plugins\/test\/remark-code-excerpt\.test\.mjs#L1-L2/);
  assert.throws(() => excerptNodes({ file: 'docs-site/plugins/test/remark-code-excerpt.test.mjs', symbol: 'nothingHere' }, { sources }), /not found/);
  assert.throws(() => excerptNodes({ file: 'docs-site/plugins/test/remark-code-excerpt.test.mjs' }, { sources }), /symbol= or lines=/);
});

test('python: a module-level assignment is a symbol whose block is its indented continuation', () => {
  const src = `A = 1\nLINE_COLS = ('id, ang, '\n             'gurmukhi')   # v2\n\nNEXT = 2\n`;
  assert.deepEqual(findSymbol(src, 'LINE_COLS', 'python'), [2, 3]);
  assert.deepEqual(findSymbol(src, 'NEXT', 'python'), [5, 5]);
});
