// Keyboard access for scrollable content (WCAG 2.1.1): a code block or a table that overflows
// sideways must be reachable with Tab so it can be scrolled without a mouse. Starlight and
// Expressive Code do not mark these, so the wiki does, once the page has laid out.
export function makeScrollRegionsFocusable(root: ParentNode = document) {
  const candidates = root.querySelectorAll<HTMLElement>('.sl-markdown-content pre, .sl-markdown-content table, .diagram__scroll');
  for (const el of candidates) {
    const overflows = el.scrollWidth > el.clientWidth + 1;
    if (overflows && !el.hasAttribute('tabindex')) {
      el.setAttribute('tabindex', '0');
      if (!el.hasAttribute('role')) el.setAttribute('role', 'region');
      if (!el.hasAttribute('aria-label')) el.setAttribute('aria-label', el.tagName === 'TABLE' ? 'Scrollable table' : 'Scrollable code');
    }
  }
}
