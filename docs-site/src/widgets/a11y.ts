// Keyboard access for scrollable content (WCAG 2.1.1): a code block or a table that overflows
// sideways must be reachable with Tab so it can be scrolled without a mouse. Starlight and
// Expressive Code do not mark these, so the wiki does — and keeps doing so, because a table
// becomes scrollable late: when the web fonts arrive, when a widget fills it, when the viewport
// changes. So this runs once at load and again after every layout change.
export function makeScrollRegionsFocusable(root: ParentNode = document) {
  const candidates = root.querySelectorAll<HTMLElement>('.sl-markdown-content pre, .sl-markdown-content table, .diagram__scroll');
  for (const el of candidates) {
    // A content table or a wide diagram is made focusable whether or not it overflows *right now*:
    // Starlight lets tables scroll sideways, and whether one does depends on the fonts that arrive
    // later and on the viewport. Measuring would leave a window in which a scrollable table has no
    // keyboard access; one extra Tab stop per table is the safer trade.
    const always = el.tagName === 'TABLE' || el.classList.contains('diagram__scroll');
    const overflows = always || el.scrollWidth > el.clientWidth + 1;
    if (overflows && !el.hasAttribute('tabindex')) {
      el.setAttribute('tabindex', '0');
      if (!el.hasAttribute('role')) el.setAttribute('role', 'region');
      if (!el.hasAttribute('aria-label')) el.setAttribute('aria-label', el.tagName === 'TABLE' ? 'Scrollable table' : 'Scrollable code');
    }
  }
}

/** Run the check now, after the fonts have loaded, and whenever the page's layout changes. */
export function watchScrollRegions() {
  let pending: number | null = null;
  const run = () => { if (pending !== null) return; pending = window.setTimeout(() => { pending = null; makeScrollRegionsFocusable(); }, 40); };
  makeScrollRegionsFocusable();
  window.addEventListener('load', run);
  window.addEventListener('resize', run, { passive: true });
  try { document.fonts?.ready.then(run); } catch { /* no Font Loading API */ }
  if ('ResizeObserver' in window) new ResizeObserver(run).observe(document.body);
  if ('MutationObserver' in window) new MutationObserver(run).observe(document.body, { childList: true, subtree: true });
}
