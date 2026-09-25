// `<!-- sggs:<name> key="value" -->` -> `<sggs-<name> key="value"></sggs-<name>>` (src/widgets/).
// The comment form keeps the Markdown clean on GitHub; unknown widgets or attributes fail the build.
import { readFileSync } from 'node:fs';
import { visit } from 'unist-util-visit';

const SCHEMA = JSON.parse(readFileSync(new URL('./widgets.schema.json', import.meta.url), 'utf8')).widgets;
const MARKER = /^<!--\s*sggs:([a-z][a-z0-9-]*)((?:\s+[a-z][a-z0-9-]*="[^"<>]*")*)\s*-->$/;
const ATTR = /([a-z][a-z0-9-]*)="([^"<>]*)"/g;

export function parseWidget(html) {
  const m = MARKER.exec(html.trim());
  if (!m) return null;
  const attrs = {};
  for (const a of m[2].matchAll(ATTR)) attrs[a[1]] = a[2];
  return { name: m[1], attrs };
}

export function widgetHtml({ name, attrs }, where = 'page') {
  const spec = SCHEMA[name];
  if (!spec) throw new Error(`${where}: unknown widget "sggs:${name}" (see docs-site/plugins/widgets.schema.json)`);
  for (const k of Object.keys(attrs)) {
    if (!(k in spec.attrs)) throw new Error(`${where}: widget "sggs:${name}" has no attribute "${k}"`);
  }
  for (const [k, v] of Object.entries(spec.attrs)) {
    if (v.required && !(k in attrs)) throw new Error(`${where}: widget "sggs:${name}" needs attribute "${k}"`);
  }
  const esc = (s) => s.replace(/&/g, '&amp;').replace(/"/g, '&quot;');
  const a = Object.entries(attrs).map(([k, v]) => ` ${k}="${esc(v)}"`).join('');
  return `<sggs-${name}${a}></sggs-${name}>`;
}

export function remarkWidgets() {
  return (tree, file) => {
    visit(tree, 'html', (node) => {
      const w = parseWidget(node.value);
      if (!w) return;
      node.value = widgetHtml(w, file.path ?? 'page');
    });
  };
}
