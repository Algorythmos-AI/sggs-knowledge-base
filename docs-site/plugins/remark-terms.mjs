// `[[Term]]` in a page becomes <sggs-term> with the glossary definition embedded, so a reader can
// hover or focus a term and read what it means without leaving the page. The definitions come from
// docs/glossary.md's table at build time; an unknown term fails the build (tools/docs_check.py
// applies the same rule in Python). On GitHub `[[Term]]` reads as plain text.
import { readFileSync } from 'node:fs';
import path from 'node:path';
import { visit } from 'unist-util-visit';
import { REPO_ROOT } from './paths.mjs';

const TERM = /\[\[([^\[\]\n]{1,60})\]\]/g;

/** GitHub-style anchor for a glossary row (the <tr> id remark-glossary-anchors gives each term). */
export function termSlug(term) {
  return 'term-' + term.toLowerCase().replace(/`/g, '').replace(/[^a-z0-9\u0a00-\u0a7f]+/g, '-').replace(/^-|-$/g, '');
}

/** { term -> { definition (plain text), aliases[] } } from the glossary table. */
export function loadGlossary(file = path.join(REPO_ROOT, 'docs', 'glossary.md')) {
  const out = {};
  for (const line of readFileSync(file, 'utf8').split('\n')) {
    const m = /^\|\s*\*\*(.+?)\*\*\s*\|\s*(.+?)\s*\|\s*$/.exec(line);
    if (!m) continue;
    const names = m[1].split(/\s*\/\s*/).map((s) => s.trim());
    const definition = m[2].replace(/\[([^\]]+)\]\([^)]*\)/g, '$1').replace(/[*_`]/g, '').trim();
    for (const n of names) out[n] = { term: names[0], definition, aliases: names };
    out[names[0]] = { term: names[0], definition, aliases: names };
  }
  return out;
}

const esc = (s) => String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/"/g, '&quot;');

export function termHtml(text, entry) {
  return `<sggs-term data-term="${esc(entry.term)}" data-definition="${esc(entry.definition)}" data-href="/glossary/#${termSlug(entry.term)}">${esc(text)}</sggs-term>`;
}

/** Split one text value into text and term nodes; throws on an unknown term. */
export function splitTerms(value, glossary, where = 'page') {
  const nodes = [];
  let last = 0;
  for (const m of value.matchAll(TERM)) {
    const raw = m[1];
    const [name, shown] = raw.includes('|') ? raw.split('|', 2).map((s) => s.trim()) : [raw.trim(), raw.trim()];
    const entry = glossary[name];
    if (!entry) throw new Error(`${where}: [[${name}]] is not a glossary term (docs/glossary.md)`);
    if (m.index > last) nodes.push({ type: 'text', value: value.slice(last, m.index) });
    nodes.push({ type: 'html', value: termHtml(shown, entry) });
    last = m.index + m[0].length;
  }
  if (!nodes.length) return null;
  if (last < value.length) nodes.push({ type: 'text', value: value.slice(last) });
  return nodes;
}

export function remarkTerms(options = {}) {
  let glossary = null;
  return (tree, file) => {
    glossary ??= options.glossary ?? loadGlossary();
    visit(tree, 'text', (node, index, parent) => {
      if (!node.value.includes('[[')) return;
      if (parent.type === 'link' || parent.type === 'inlineCode') return;
      const nodes = splitTerms(node.value, glossary, file.path ?? 'page');
      if (!nodes) return;
      parent.children.splice(index, 1, ...nodes);
      return index + nodes.length;
    });
  };
}
