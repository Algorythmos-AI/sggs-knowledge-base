// <sggs-releases>: the release timeline (rendered at build from CHANGELOG.md by remark-releases)
// gains a filter box: type a version, a date or a word from a title and the list narrows.
import { el } from './api';

export class SggsReleases extends HTMLElement {
  connectedCallback() {
    const items = Array.from(this.querySelectorAll<HTMLElement>('.release'));
    if (!items.length || this.hasAttribute('limit')) return;   // a short, limited list needs no filter
    const input = el('input', { type: 'search', class: 'wf__input releases__filter', placeholder: 'Filter by version, date or words in the title', 'aria-label': 'Filter releases' }) as HTMLInputElement;
    const count = el('span', { class: 'releases__count', role: 'status', 'aria-live': 'polite' }, [`${items.length} releases`]);
    input.addEventListener('input', () => {
      const q = input.value.trim().toLowerCase();
      let n = 0;
      for (const it of items) { const hit = !q || (it.dataset.text ?? '').includes(q); it.hidden = !hit; if (hit) n++; }
      count.textContent = q ? `${n} of ${items.length} releases match` : `${items.length} releases`;
    });
    this.prepend(el('div', { class: 'releases__bar' }, [input, count]));
  }
}
