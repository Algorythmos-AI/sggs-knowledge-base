// <sggs-walkthrough>: a poster becomes a step-through. Steps are the <g data-step> groups the
// poster kit emits; the sidecar (embedded JSON) gives each a title, caption and link. Controls:
// Prev / Next / Play / Pause, arrow keys, a step list; plus a full-size lightbox (native <dialog>)
// with zoom and drag-pan. Without JavaScript the poster is simply a picture.
import { el } from './api';

type Step = { id: string; title: string; caption: string; link?: string };

export class SggsWalkthrough extends HTMLElement {
  private steps: Step[] = [];
  private current = -1;             // -1 = whole picture
  private timer: number | null = null;
  private svg!: SVGSVGElement;
  private caption!: HTMLElement;
  private counter!: HTMLElement;
  private playBtn!: HTMLButtonElement;
  private reduced = matchMedia('(prefers-reduced-motion: reduce)').matches;

  connectedCallback() {
    const json = this.querySelector<HTMLScriptElement>('script.poster__steps');
    const svg = this.querySelector<SVGSVGElement>('svg');
    if (!json || !svg) return;
    try { this.steps = JSON.parse(json.textContent || '[]'); } catch { this.steps = []; }
    this.svg = svg;
    this.buildControls();
    this.show(-1);
  }

  private groups(): SVGGElement[] {
    return Array.from(this.svg.querySelectorAll<SVGGElement>('g[data-step]'));
  }

  private buildControls() {
    const bar = el('div', { class: 'wt__bar', role: 'toolbar', 'aria-label': 'Walkthrough controls' });
    const btn = (label: string, cls: string, onClick: () => void, extra: Record<string, string> = {}) => {
      const b = el('button', { type: 'button', class: `wt__btn ${cls}`, ...extra }, [label]) as HTMLButtonElement;
      b.addEventListener('click', onClick);
      return b;
    };
    this.counter = el('span', { class: 'wt__counter', 'aria-live': 'polite' });
    this.playBtn = btn('▶ Play', 'wt__play', () => this.toggle());
    bar.append(
      btn('⟲ All', 'wt__all', () => this.show(-1)),
      btn('◀ Prev', 'wt__prev', () => this.step(-1)),
      btn('Next ▶', 'wt__next', () => this.step(1)),
      this.playBtn,
      this.counter,
      btn('⤢ Full size', 'wt__zoom', () => this.openLightbox()),
    );
    this.caption = el('div', { class: 'wt__caption', role: 'status', 'aria-live': 'polite' });
    const list = el('ol', { class: 'wt__list' });
    this.steps.forEach((s, i) => {
      const li = el('li');
      const a = el('button', { type: 'button', class: 'wt__item' }, [s.title]);
      a.addEventListener('click', () => this.show(i));
      li.append(a); list.append(li);
    });
    this.append(bar, this.caption, list);
    this.tabIndex = 0;
    this.addEventListener('keydown', (e) => {
      if (e.key === 'ArrowRight') { e.preventDefault(); this.step(1); }
      if (e.key === 'ArrowLeft') { e.preventDefault(); this.step(-1); }
      if (e.key === 'Home') { e.preventDefault(); this.show(-1); }
    });
    this.svg.querySelectorAll<SVGGElement>('g[data-step]').forEach((g, i) => {
      g.addEventListener('click', () => this.show(i));
      g.style.cursor = 'pointer';
    });
  }

  private step(delta: number) {
    const n = this.steps.length;
    if (!n) return;
    const next = this.current + delta;
    this.show(next < 0 ? n - 1 : next >= n ? -1 : next);
  }

  show(i: number) {
    this.current = i;
    const groups = this.groups();
    groups.forEach((g, gi) => {
      g.classList.toggle('is-dim', i >= 0 && gi > i);
      g.classList.toggle('is-active', i >= 0 && gi === i);
    });
    this.querySelectorAll('.wt__item').forEach((b, bi) => b.setAttribute('aria-current', bi === i ? 'step' : 'false'));
    if (i < 0) {
      this.caption.replaceChildren(el('strong', {}, ['The whole picture. ']), 'Press Next or click a step to build it up.');
      this.counter.textContent = `${this.steps.length} steps`;
      return;
    }
    const s = this.steps[i];
    const parts: (Node | string)[] = [el('strong', {}, [`${i + 1}. ${s.title}. `]), s.caption];
    if (s.link) parts.push(' ', el('a', { href: s.link, class: 'wt__link' }, ['Read more →']));
    this.caption.replaceChildren(...parts);
    this.counter.textContent = `Step ${i + 1} of ${this.steps.length}`;
  }

  private toggle() {
    if (this.timer !== null) { this.stop(); return; }
    this.playBtn.textContent = '❚❚ Pause';
    this.playBtn.setAttribute('aria-pressed', 'true');
    if (this.current < 0) this.show(0);
    this.timer = window.setInterval(() => {
      if (this.current >= this.steps.length - 1) { this.stop(); return; }
      this.step(1);
    }, this.reduced ? 9000 : 6000);
  }

  private stop() {
    if (this.timer !== null) window.clearInterval(this.timer);
    this.timer = null;
    this.playBtn.textContent = '▶ Play';
    this.playBtn.setAttribute('aria-pressed', 'false');
  }

  private openLightbox() {
    this.stop();
    const dlg = el('dialog', { class: 'lightbox', 'aria-label': 'Poster, full size' }) as HTMLDialogElement;
    const pan = el('div', { class: 'lightbox__pan' });
    const clone = this.svg.cloneNode(true) as SVGSVGElement;
    clone.removeAttribute('width');
    clone.querySelectorAll('g[data-step]').forEach((g) => g.classList.remove('is-dim', 'is-active'));
    pan.append(clone);
    let scale = 1, tx = 0, ty = 0, drag: { x: number; y: number } | null = null;
    const apply = () => { clone.style.transform = `translate(${tx}px, ${ty}px) scale(${scale})`; };
    const zoom = (f: number) => { scale = Math.min(6, Math.max(0.25, scale * f)); apply(); };
    const reset = () => { scale = 1; tx = 0; ty = 0; apply(); };
    const tools = el('div', { class: 'lightbox__tools', role: 'toolbar', 'aria-label': 'Zoom' });
    const mk = (label: string, fn: () => void, extra: Record<string, string> = {}) => { const b = el('button', { type: 'button', class: 'wt__btn', ...extra }, [label]); b.addEventListener('click', fn); return b; };
    const close = mk('✕ Close', () => dlg.close(), { autofocus: 'true' });
    tools.append(mk('−', () => zoom(1 / 1.25), { 'aria-label': 'Zoom out' }), mk('0', reset, { 'aria-label': 'Reset zoom' }), mk('+', () => zoom(1.25), { 'aria-label': 'Zoom in' }), close);
    dlg.append(tools, pan);
    dlg.addEventListener('keydown', (e) => {
      if (e.key === '+' || e.key === '=') zoom(1.25);
      if (e.key === '-') zoom(1 / 1.25);
      if (e.key === '0') reset();
    });
    pan.addEventListener('pointerdown', (e) => { drag = { x: e.clientX - tx, y: e.clientY - ty }; pan.setPointerCapture(e.pointerId); });
    pan.addEventListener('pointermove', (e) => { if (drag) { tx = e.clientX - drag.x; ty = e.clientY - drag.y; apply(); } });
    pan.addEventListener('pointerup', () => { drag = null; });
    pan.addEventListener('wheel', (e) => { if (e.ctrlKey || e.metaKey) { e.preventDefault(); zoom(e.deltaY < 0 ? 1.1 : 1 / 1.1); } }, { passive: false });
    dlg.addEventListener('close', () => { dlg.remove(); (this.querySelector('.wt__zoom') as HTMLElement | null)?.focus(); });
    document.body.append(dlg);
    dlg.showModal();
  }
}
