// <!-- sggs:cards --> turns the Markdown list that follows it into a grid of cards, at build: each
// item's first link becomes the card's title and the whole card its target; the text after the link
// (" — a sentence") becomes the card's description. No JavaScript, no new markup to author: on
// GitHub the same lines stay a plain list, which is the fallback.
import { visit } from 'unist-util-visit';

const MARKER = /^<sggs-cards\b[^>]*>\s*<\/sggs-cards>$/;
const LEAD = /^\s*[—–-]\s*/;   // the " — " between the link and its description

export function remarkCards() {
  return (tree, file) => {
    visit(tree, 'html', (node, index, parent) => {
      if (!parent || index === undefined || !MARKER.test(node.value.trim())) return;
      const list = parent.children[index + 1];
      if (!list || list.type !== 'list') {
        throw new Error(`${file.path ?? 'page'}: sggs:cards must be followed directly by a list (one item per card)`);
      }
      for (const item of list.children) {
        const para = item.children?.[0];
        const link = para?.type === 'paragraph' ? para.children.find((c) => c.type === 'link') : null;
        if (!link) throw new Error(`${file.path ?? 'page'}: every sggs:cards item starts with a link (the card's title and target)`);
        link.data = { ...(link.data ?? {}), hProperties: { ...(link.data?.hProperties ?? {}), className: ['sggs-card__title'] } };
        const after = para.children[para.children.indexOf(link) + 1];
        if (after?.type === 'text') after.value = after.value.replace(LEAD, '');
        item.data = { ...(item.data ?? {}), hProperties: { className: ['sggs-card'] } };
      }
      list.data = { ...(list.data ?? {}), hProperties: { className: ['sggs-cards'] } };
      parent.children.splice(index, 1);   // the marker is spent; the list carries the class
      return index;
    });
  };
}
