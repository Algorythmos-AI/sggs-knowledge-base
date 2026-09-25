// <sggs-term>: a glossary term in running text. Hover or focus shows the definition in a small
// card (role="tooltip"); Enter or click opens the glossary entry. Keyboard: Tab to it, Escape hides.
import { el } from './api';

export class SggsTerm extends HTMLElement {
  private card: HTMLElement | null = null;

  connectedCallback() {
    if (this.dataset.ready) return;
    this.dataset.ready = '1';
    const id = `term-${Math.random().toString(36).slice(2, 8)}`;
    const label = this.textContent ?? '';
    const link = el('a', { href: this.dataset.href ?? '/glossary/', class: 'term__link', 'aria-describedby': id }, [label]);
    this.card = el('span', { id, role: 'tooltip', class: 'term__card' }, [el('strong', {}, [this.dataset.term ?? label]), ' ', this.dataset.definition ?? '']);
    this.replaceChildren(link, this.card);
    const show = () => this.classList.add('is-open');
    const hide = () => this.classList.remove('is-open');
    link.addEventListener('mouseenter', show); this.addEventListener('mouseleave', hide);
    link.addEventListener('focus', show); link.addEventListener('blur', hide);
    link.addEventListener('keydown', (e) => { if (e.key === 'Escape') { hide(); } });
  }
}
