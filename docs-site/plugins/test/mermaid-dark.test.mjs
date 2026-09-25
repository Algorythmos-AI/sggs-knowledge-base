// The dark drawing of a Mermaid diagram: palette colours in style lines swap to their dark twins,
// labels never change, and a text colour that would lose contrast on its fill takes the better ink.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { darkStyles } from '../remark-mermaid.mjs';
import { contrast } from '../brand.mjs';

test('light tokens in style lines become their dark twins', () => {
  const src = 'flowchart LR\n  A[#FDF6E3 is a label] --> B\n  classDef soft fill:#FDF6E3,stroke:#A87900,color:#201A12\n  style B fill:#FFFFFF\n  linkStyle 0 stroke:#A87900';
  const out = darkStyles(src).split('\n');
  assert.equal(out[1], '  A[#FDF6E3 is a label] --> B');                // a label is never touched
  assert.equal(out[2], '  classDef soft fill:#171412,stroke:#FFBC0D,color:#F3ECDD');
  assert.equal(out[3], '  style B fill:#1E1A17');
  assert.equal(out[4], '  linkStyle 0 stroke:#FFBC0D');
});

test('text on a fill that is the same in both legs keeps a readable ink', () => {
  const out = darkStyles('  classDef k fill:#B69A81,color:#201A12');   // kraft is kraft in the dark too
  const color = /color:(#[0-9A-F]{6})/.exec(out)[1];
  assert.ok(contrast(color, '#B69A81') >= 4.5, `${color} on kraft`);
});

test('short hex and colours outside the palette pass through safely', () => {
  assert.equal(darkStyles('  style A fill:#FFF'), '  style A fill:#1E1A17');
  assert.equal(darkStyles('  style A fill:#7A1F1F'), '  style A fill:#7A1F1F');
});

test('geometry is rounded to two decimals; text and colours are not touched', async () => {
  const { roundGeometry } = await import('../remark-mermaid.mjs');
  const svg = '<svg viewBox="0 0 812.123456 90.5"><path d="M12.3456789,90.1234567L3.14159,2"/><text x="1.23456">v1.2345678 build</text><rect style="fill:#FDF6E3;width:10.98765px"/></svg>';
  const out = roundGeometry(svg);
  assert.match(out, /viewBox="0 0 812\.12 90\.5"/);
  assert.match(out, /d="M12\.35,90\.12L3\.14,2"/);
  assert.match(out, /x="1\.23"/);
  assert.match(out, />v1\.2345678 build</);          // a label keeps every digit
  assert.match(out, /fill:#FDF6E3;width:10\.99px/);
});
