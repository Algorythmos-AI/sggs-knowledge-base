// <sggs-verify>: paste a quotation (Gurmukhi or Roman), optionally the Ang you believe it is on,
// and watch /api/verify decide. The verdict names the rung of the ladder that fired and lights it
// on poster 07; the matched line is shown verbatim with its Ang, and distance_details explain
// the score. Thresholds are the API's (webapp/verify.py); nothing is judged in the browser.
import { api, el } from './api';
import { lineCard, lightStep, chip } from './shared';

type Verdict = {
  verdict: string; confidence: number; matched_line_id: number | null; ang: number | null; gurmukhi: string | null;
  raag: string | null; author: string | null; comp_id: number | null; section: string | null;
  distance_details: Record<string, number | string>;
};
const POSTER = '07-verification-engine';
const RUNGS: Record<string, [string, string, string]> = {
  VERIFIED_EXACT: ['step-03', 'ok', 'An exact match: after NFC normalisation and punctuation stripping, the bytes equal a canonical line.'],
  VERIFIED_PARTIAL: ['step-04', 'ok', 'A fragment: the claim (3+ words or 12+ characters) is contained whole inside a canonical line.'],
  VERIFIED: ['step-05', 'ok', 'The best candidate scores ≥ 0.95 by difflib ratio against the claim.'],
  PROBABLE: ['step-06', 'warn', 'The best candidate scores ≥ 0.85 and is clearly ahead of the runner-up (gap ≥ 0.05).'],
  AMBIGUOUS: ['step-06', 'warn', 'Two candidates score ≥ 0.80 within 0.05 of each other: the engine will not choose for you.'],
  NOT_FOUND: ['step-07', 'bad', 'No candidate reached 0.85 (or the index returned none): the quotation is not asserted to exist.'],
};
const EXAMPLES: [string, string][] = [
  ['sochai soch na hovai je sochi lakh vaar', ''], ['sochai soch na hovai', ''], ['sochai soch na hovai je sochi lakh vaar', '5'], ['this line does not exist anywhere', ''],
];

export class SggsVerify extends HTMLElement {
  private claim!: HTMLTextAreaElement;
  private ang!: HTMLInputElement;
  private status!: HTMLElement;
  private out!: HTMLElement;
  private seq = 0;

  connectedCallback() {
    const form = el('form', { class: 'vf__form', 'aria-label': 'Verification playground' });
    const id = `vf-${Math.random().toString(36).slice(2, 8)}`;
    this.claim = el('textarea', { id: `${id}-q`, class: 'vf__claim', rows: '2', maxlength: '1000', placeholder: 'A quotation in Gurmukhi or romanised Gurmukhi — paste a line from the Ang explorer, or type one from memory' }) as HTMLTextAreaElement;
    this.ang = el('input', { id: `${id}-ang`, type: 'number', min: '1', max: '1430', class: 'ax__input vf__ang' }) as HTMLInputElement;
    const go = el('button', { type: 'submit', class: 'wt__btn vf__go' }, ['Verify']);
    form.append(el('label', { for: `${id}-q`, class: 'vf__label' }, ['Quotation']), this.claim, el('div', { class: 'vf__row' }, [el('label', { for: `${id}-ang`, class: 'vf__label' }, ['Claimed Ang (optional)']), this.ang, go]));
    form.addEventListener('submit', (e) => { e.preventDefault(); this.run(); });
    const ex = el('div', { class: 'vf__examples', role: 'group', 'aria-label': 'Examples' });
    for (const [q, a] of EXAMPLES) {
      const b = el('button', { type: 'button', class: 'wt__item vf__example', 'data-q': q, 'data-ang': a }, [a ? `${q} · claimed Ang ${a}` : q]);
      b.addEventListener('click', () => { this.claim.value = q; this.ang.value = a; this.run(); });
      ex.append(b);
    }
    this.status = el('p', { class: 'vf__status', role: 'status', 'aria-live': 'polite' }, ['The examples are transliterations, not scripture; the engine answers with the canonical line.']);
    this.out = el('div', { class: 'vf__out' });
    this.replaceChildren(form, ex, this.status, this.out);
  }

  private async run() {
    const q = this.claim.value.trim();
    if (!q) return;
    const ang = this.ang.value.trim();
    const my = ++this.seq;
    this.status.textContent = 'Running /api/verify…';
    this.out.replaceChildren();
    lightStep(POSTER, 'step-01');
    const d = await api<Verdict>(`/api/verify?q=${encodeURIComponent(q)}${ang ? `&ang=${encodeURIComponent(ang)}` : ''}`);
    if (my !== this.seq) return;
    if (!d || !d.verdict) {
      this.status.textContent = 'The live API is not reachable right now, so nothing can be verified here. The ladder is explained on this page.';
      lightStep(POSTER, null);
      return;
    }
    const base = d.verdict.split('+')[0];
    const tag = d.verdict.includes('+') ? d.verdict.slice(d.verdict.indexOf('+')) : '';
    const [step, cls, why] = RUNGS[base] ?? ['step-07', 'bad', ''];
    lightStep(POSTER, step);
    this.status.textContent = `Verdict: ${d.verdict}`;
    const head = el('div', { class: 'vf__verdict' });
    head.append(chip(base, `chip--${cls}`), el('span', { class: 'vf__conf' }, [`confidence ${d.confidence.toFixed(2)}`]));
    if (tag) head.append(chip(tag, tag.startsWith('+ANG_MATCH') ? 'chip--ok' : 'chip--warn'));
    this.out.append(head, el('p', { class: 'vf__why' }, [why, tag.startsWith('+ANG_MISMATCH') ? ' The line exists, but not on the Ang you claimed — the actual Ang is in the tag.' : '']));
    if (d.gurmukhi && d.ang) {
      const list = el('ol', { class: 'lines' });
      list.append(lineCard({ id: d.matched_line_id ?? 0, ang: d.ang, gurmukhi: d.gurmukhi, author: d.author, raag: d.raag }, d.section ? [` · ${d.section}`] : []));
      this.out.append(el('p', { class: 'vf__matched' }, ['The canonical line the verdict refers to:']), list);
    }
    const dl = el('dl', { class: 'vf__details' });
    for (const [k, v] of Object.entries(d.distance_details ?? {})) dl.append(el('dt', {}, [el('code', {}, [k])]), el('dd', {}, [String(v)]));
    this.out.append(el('details', { class: 'vf__dd' }, [el('summary', {}, ['distance_details']), dl]));
  }
}
