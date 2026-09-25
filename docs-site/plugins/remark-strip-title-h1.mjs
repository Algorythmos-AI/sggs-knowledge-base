// GitHub shows a page's `# Title`; Starlight renders the frontmatter `title` itself. When the two
// are the same text (tools/docs_check.py requires it), drop the body H1 so the page has one heading.
import { toString } from 'mdast-util-to-string';

export function remarkStripTitleH1() {
  return (tree, file) => {
    const title = file.data?.astro?.frontmatter?.title;
    if (!title) return;
    const i = tree.children.findIndex((n) => n.type === 'heading' && n.depth === 1);
    if (i === -1) return;
    if (toString(tree.children[i]).trim() === String(title).trim()) tree.children.splice(i, 1);
  };
}
