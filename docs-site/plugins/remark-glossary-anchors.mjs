// The glossary table's rows get stable ids (term-<slug>) so hover-cards and other pages can link
// straight to a term. Applied to docs/glossary.md only; the Markdown stays a plain table on GitHub.
import { visit } from 'unist-util-visit';
import { toString } from 'mdast-util-to-string';
import { termSlug } from './remark-terms.mjs';

export function remarkGlossaryAnchors() {
  return (tree, file) => {
    if (!file.path || !/[\\/]docs[\\/]glossary\.md$/.test(file.path)) return;
    visit(tree, 'tableRow', (row) => {
      const first = row.children[0];
      if (!first) return;
      const name = toString(first).split(/\s*\/\s*/)[0].trim();
      if (!name) return;
      row.data ??= {}; row.data.hProperties ??= {};
      row.data.hProperties.id = termSlug(name);
    });
  };
}
