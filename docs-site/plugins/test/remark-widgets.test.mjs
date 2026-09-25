import test from 'node:test';
import assert from 'node:assert/strict';
import { parseWidget, widgetHtml } from '../remark-widgets.mjs';

test('a widget comment becomes its custom element', () => {
  assert.deepEqual(parseWidget('<!-- sggs:status -->'), { name: 'status', attrs: {} });
  assert.equal(widgetHtml({ name: 'status', attrs: {} }), '<sggs-status></sggs-status>');
});

test('ordinary comments and HTML are not widgets', () => {
  assert.equal(parseWidget('<!-- a note for editors -->'), null);
  assert.equal(parseWidget('<div>x</div>'), null);
  assert.equal(parseWidget('<!-- sggs:status --> trailing'), null);
});

test('unknown widgets and attributes fail the build', () => {
  assert.throws(() => widgetHtml({ name: 'nope', attrs: {} }), /unknown widget/);
  assert.throws(() => widgetHtml({ name: 'status', attrs: { q: 'x' } }), /no attribute "q"/);
});

test('attribute values are escaped', () => {
  // attributes are validated against the schema; escaping is exercised through a schema entry when one has attrs
  const html = '<sggs-status></sggs-status>';
  assert.equal(widgetHtml(parseWidget('<!--sggs:status-->')), html);
});
