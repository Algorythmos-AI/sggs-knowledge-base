import test from 'node:test';
import assert from 'node:assert/strict';
import { remarkTaskLists } from '../remark-task-lists.mjs';

const item = (checked) => ({ type: 'listItem', checked, children: [{ type: 'paragraph', children: [{ type: 'text', value: 'read the invariants' }] }] });

test('a task item becomes a labelled glyph and keeps its class', () => {
  const t = { type: 'root', children: [{ type: 'list', children: [item(false), item(true)] }] };
  remarkTaskLists()(t);
  const [a, b] = t.children[0].children;
  assert.equal(a.checked, null);
  assert.deepEqual(a.data.hProperties.className, ['task-list-item']);
  assert.match(a.children[0].children[0].value, /aria-label="not done"/);
  assert.match(b.children[0].children[0].value, /aria-label="done"/);
  assert.equal(a.children[0].children[1].value, 'read the invariants');
});

test('a plain list item is untouched', () => {
  const t = { type: 'root', children: [{ type: 'list', children: [{ type: 'listItem', checked: null, children: [] }] }] };
  remarkTaskLists()(t);
  assert.equal(t.children[0].children[0].children.length, 0);
});
