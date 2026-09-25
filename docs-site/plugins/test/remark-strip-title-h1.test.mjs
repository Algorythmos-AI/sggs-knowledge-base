import test from 'node:test';
import assert from 'node:assert/strict';
import { remarkStripTitleH1 } from '../remark-strip-title-h1.mjs';

const tree = (title) => ({ type: 'root', children: [
  { type: 'heading', depth: 1, children: [{ type: 'text', value: 'ADR-0002: keep ' }, { type: 'inlineCode', value: 'comp_id' }] },
  { type: 'paragraph', children: [{ type: 'text', value: 'body' }] },
]});
const file = (title) => ({ data: { astro: { frontmatter: { title } } } });

test('the H1 is dropped when it equals the frontmatter title (code spans read as text)', () => {
  const t = tree();
  remarkStripTitleH1()(t, file('ADR-0002: keep comp_id'));
  assert.equal(t.children.length, 1);
  assert.equal(t.children[0].type, 'paragraph');
});

test('a different H1 is kept', () => {
  const t = tree();
  remarkStripTitleH1()(t, file('Something else'));
  assert.equal(t.children.length, 2);
});
