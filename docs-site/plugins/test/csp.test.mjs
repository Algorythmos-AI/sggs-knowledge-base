// scripts/csp.mjs: the Content-Security-Policy allows exactly the build's inline scripts, by hash.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { inlineScripts, hashOf, unsafeMarkup, withHashes } from '../../scripts/csp.mjs';

test('inline scripts: executable ones only, never external or data blocks', () => {
  const html = `<script>a()</script><script type="module">b()</script><script src="/x.js"></script>
    <script type="application/ld+json">{"@type":"X"}</script><script type="application/json">{}</script>`;
  assert.deepEqual(inlineScripts(html), ['a()', 'b()']);
});

test('the hash is the browser\'s: sha256 of the exact text, base64, quoted', () => {
  const want = createHash('sha256').update(' x=1; ').digest('base64');
  assert.equal(hashOf(' x=1; '), `'sha256-${want}'`);
  assert.notEqual(hashOf(' x=1; '), hashOf('x=1;'));            // one changed byte changes the hash
});

test('inline handlers and javascript: URLs are reported; code shown as text is not', () => {
  assert.equal(unsafeMarkup('<button onclick="go()">x</button>').length, 1);
  assert.equal(unsafeMarkup('<a href="javascript:void 0">x</a>').length, 1);
  assert.equal(unsafeMarkup('<code>&lt;button onclick="go()"&gt;</code>').length, 0);
  assert.equal(unsafeMarkup('<p class="honor">online</p>').length, 0);
});

test('writing the policy drops unsafe-inline and stale hashes, keeps every other directive', () => {
  const before = "default-src 'self'; script-src 'self' 'unsafe-inline' 'wasm-unsafe-eval' 'sha256-OLD='; style-src 'self' 'unsafe-inline'";
  const after = withHashes(before, ["'sha256-B='", "'sha256-A='"]);
  assert.equal(after, "default-src 'self'; script-src 'self' 'wasm-unsafe-eval' 'sha256-A=' 'sha256-B='; style-src 'self' 'unsafe-inline'");
});
