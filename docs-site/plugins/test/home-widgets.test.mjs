// The home page's build-time widgets: cards (a Markdown list as a card grid), the palette swatches
// and a limited release list.
import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import path from 'node:path';
import { remarkCards } from '../remark-cards.mjs';
import { swatchesHtml, contrast } from '../remark-swatches.mjs';
import { parseChangelog, releasesHtml } from '../remark-releases.mjs';
import { REPO_ROOT } from '../paths.mjs';

const list = (items) => ({
  type: 'list', ordered: false, children: items.map(([text, url, rest]) => ({
    type: 'listItem', children: [{ type: 'paragraph', children: [{ type: 'link', url, children: [{ type: 'text', value: text }] }, { type: 'text', value: rest }] }],
  })),
});

test('cards: the list after the marker becomes a card grid; the marker is removed', () => {
  const tree = { type: 'root', children: [{ type: 'html', value: '<sggs-cards></sggs-cards>' }, list([['Platform engineer', '/p/', ' — the API, in order.']])] };
  remarkCards()(tree, { path: 'x.md' });
  assert.equal(tree.children.length, 1);
  const ul = tree.children[0];
  assert.deepEqual(ul.data.hProperties.className, ['sggs-cards']);
  assert.deepEqual(ul.children[0].data.hProperties.className, ['sggs-card']);
  const [link, rest] = ul.children[0].children[0].children;
  assert.deepEqual(link.data.hProperties.className, ['sggs-card__title']);
  assert.equal(rest.value, 'the API, in order.');               // the leading " — " is dropped on the site
});

test('cards: a marker without a list, or an item without a link, fails the build', () => {
  const noList = { type: 'root', children: [{ type: 'html', value: '<sggs-cards></sggs-cards>' }, { type: 'paragraph', children: [] }] };
  assert.throws(() => remarkCards()(noList, { path: 'x.md' }), /followed directly by a list/);
  const noLink = { type: 'root', children: [{ type: 'html', value: '<sggs-cards></sggs-cards>' }, { type: 'list', children: [{ type: 'listItem', children: [{ type: 'paragraph', children: [{ type: 'text', value: 'plain' }] }] }] }] };
  assert.throws(() => remarkCards()(noLink, { path: 'x.md' }), /starts with a link/);
});

test('swatches: every token, both legs, with contrast computed from the file', () => {
  const tokens = JSON.parse(readFileSync(path.join(REPO_ROOT, 'docs/brand/tokens.json'), 'utf8'));
  const html = swatchesHtml(tokens);
  for (const [group, roles] of Object.entries(tokens)) {
    if (!['surfaces', 'soul', 'brand', 'status'].includes(group)) continue;
    for (const name of Object.keys(roles)) assert.match(html, new RegExp(`<code>${group}\\.${name}</code>`));
  }
  assert.match(html, /#FFBC0D<\/code> <span class="swatch__ratio">1\.58:1</);   // gold on paper: why it is a fill, never text
  assert.match(html, / on accentFill/);                                        // a label colour is measured on its fill
  assert.ok(Math.abs(contrast('#FFFFFF', '#000000') - 21) < 1e-9);
});

test('releases: limit keeps the newest N and marks the element (no filter box)', () => {
  const rel = parseChangelog(readFileSync(path.join(REPO_ROOT, 'CHANGELOG.md'), 'utf8'));
  const html = releasesHtml(rel, 3);
  assert.match(html, /^<sggs-releases limit="3">/);
  assert.equal((html.match(/class="release"/g) ?? []).length, 3);
  assert.equal((releasesHtml(rel).match(/class="release"/g) ?? []).length, rel.length);
});
