// <sggs-progress path="…">: the learning-path checklist. It enhances the list that follows it:
// every item gets a checkbox, ticks are remembered in this browser only (localStorage, per path,
// wrapped in try/catch — a private window simply forgets), and a counter and a reset button sit
// above the list. Nothing leaves the browser. Without JavaScript the list is a plain list.
import { el } from './api';

export class SggsProgress extends HTMLElement {
  connectedCallback() {
    const path = this.getAttribute('path') ?? 'path';
    const key = `sggs-path-${path}`;
    let list = this.nextElementSibling;
    while (list && !/^(OL|UL)$/.test(list.tagName)) list = list.nextElementSibling;
    if (!list) return;
    const items = Array.from(list.querySelectorAll<HTMLLIElement>(':scope > li'));
    if (!items.length) return;
    const read = (): boolean[] => { try { const v = JSON.parse(localStorage.getItem(key) || '[]'); return Array.isArray(v) ? v : []; } catch { return []; } };
    const write = (v: boolean[]) => { try { localStorage.setItem(key, JSON.stringify(v)); } catch { /* storage unavailable: ticks live for this page view only */ } };
    let done = read();
    const status = el('span', { class: 'progress__status', role: 'status', 'aria-live': 'polite' });
    const reset = el('button', { type: 'button', class: 'wt__btn progress__reset' }, ['Start again']);
    const bar = el('div', { class: 'progress__bar' }, [status, reset]);
    const update = () => {
      const n = done.filter(Boolean).length;
      status.textContent = n === items.length ? `All ${items.length} steps done — well walked.` : `${n} of ${items.length} steps done · remembered in this browser only`;
      items.forEach((li, i) => li.classList.toggle('is-done', !!done[i]));
    };
    items.forEach((li, i) => {
      const id = `${key}-${i}`;
      const box = el('input', { type: 'checkbox', id, class: 'progress__box', 'aria-label': `Step ${i + 1} done` }) as HTMLInputElement;
      box.checked = !!done[i];
      box.addEventListener('change', () => { done[i] = box.checked; write(done); update(); });
      li.prepend(box, ' ');
      li.classList.add('progress__item');
    });
    reset.addEventListener('click', () => { done = []; write(done); items.forEach((li) => { (li.querySelector('input') as HTMLInputElement).checked = false; }); update(); });
    list.classList.add('progress__list');
    this.replaceChildren(bar);
    update();
  }
}
