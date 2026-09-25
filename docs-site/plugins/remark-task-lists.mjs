// GitHub task lists (`- [ ]` / `- [x]`) render as disabled, unlabelled checkboxes — an axe "label"
// violation on every checklist page. The wiki's checklists are read, not ticked (the learning-path
// widget owns interactive progress), so each box becomes a labelled glyph instead: the item keeps
// its `task-list-item` class for styling and the checkbox state is announced as "done"/"not done".
export function remarkTaskLists() {
  const walk = (node) => {
    if (node.type === 'listItem' && typeof node.checked === 'boolean') {
      const done = node.checked;
      node.checked = null;
      node.data = { ...(node.data ?? {}), hProperties: { ...(node.data?.hProperties ?? {}), className: ['task-list-item'] } };
      const glyph = { type: 'html', value: `<span class="task-box" role="img" aria-label="${done ? 'done' : 'not done'}" data-done="${done ? '1' : '0'}">${done ? '☑' : '☐'}</span> ` };
      const first = node.children?.[0];
      if (first && first.type === 'paragraph') first.children.unshift(glyph);
      else node.children = [{ type: 'paragraph', children: [glyph] }, ...(node.children ?? [])];
    }
    for (const c of node.children ?? []) walk(c);
  };
  return (tree) => walk(tree);
}
