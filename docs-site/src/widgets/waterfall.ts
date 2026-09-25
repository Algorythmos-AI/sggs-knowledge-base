// <sggs-waterfall q="sat nam">: run a query through the real /api/search and watch the waterfall
// decide — the `mode` the API reports names the tier that answered, and the matching step of
// poster 05 lights up. Results are shown verbatim with their Ang. The tier map below mirrors
// webapp/sggs/search.py:do_search (tools/docs_check.py checks that every mode literal in the code
// is named on the search-waterfall page and in the poster's steps).
import { api, el } from './api';
import { lineCard, lightStep, chip, type ApiLine } from './shared';

type Result = { mode: string; results: ApiLine[]; related_themes?: { concept: string; description?: string }[]; concept?: { name: string; description?: string; total?: number } | null };

const POSTER = '05-search-waterfall';
// mode prefix -> [step, plain-words explanation]
const TIERS: [string, string, string][] = [
  ['mixed-script', 'step-02', 'Gurmukhi and Latin in one query: the mixed-script blender, or the Latin part alone.'],
  ['gurmukhi-skeleton', 'step-04', 'Gurmukhi with no exact hit: the vowel signs were stripped and the skeleton column matched.'],
  ['gurmukhi', 'step-04', 'Gurmukhi matched the verbatim text column (FTS).'],
  ['first-letters', 'step-04', 'Short tokens read as first letters of each word (fl_g / fl_r).'],
  ['roman-spelling-tolerant', 'step-11', 'The phonetic fold: the query and the index both folded by roman_norm (translit_norm).'],
  ['roman', 'step-05', 'Roman letters matched the transliteration column (FTS).'],
  ['seeker-lexicon', 'step-06', 'A curated seeker word (a name, a common spelling) mapped to its transliteration or theme.'],
  ['variant-match', 'step-07', 'The precomputed romanisation-variant index resolved each token.'],
  ['english-translation', 'step-08', 'No Gurmukhi hit: the English translation layer (fts_en) answered.'],
  ['english', 'step-03', 'Explicit English mode: the translation layer.'],
  ['passage-match', 'step-10', 'Three or more tokens matched across line boundaries at composition level (fts_shabad).'],
  ['skeleton-blob', 'step-12', 'Spaceless or keyboard-smash input collapsed to a fold-skeleton blob and fuzzy-ranked.'],
  ['theme', 'step-05', 'A concept name: the theme index (concept_lines), with the concept described.'],
];
const EXAMPLES: [string, string][] = [
  ['sat nam', 'auto'], ['waheguru', 'auto'], ['mercy', 'auto'], ['s n k p', 'auto'],
  ['jeevat jo marai haan dutar so tarai haan', 'auto'], ['haumai', 'theme'], ['ਸਤਿ ਨਾਮੁ', 'auto'], ['waheguru ji', 'auto'],
];
const MODES = ['auto', 'gurmukhi', 'roman', 'english', 'first', 'theme'];

export class SggsWaterfall extends HTMLElement {
  private input!: HTMLInputElement;
  private mode!: HTMLSelectElement;
  private out!: HTMLElement;
  private status!: HTMLElement;
  private seq = 0;

  connectedCallback() {
    const form = el('form', { class: 'wf__bar', role: 'search', 'aria-label': 'Search simulator' });
    this.input = el('input', { type: 'search', class: 'wf__input', value: this.getAttribute('q') ?? '', 'aria-label': 'Query', maxlength: '300', placeholder: 'Gurmukhi, romanised Gurmukhi or English' }) as HTMLInputElement;
    this.mode = el('select', { class: 'wf__mode', 'aria-label': 'Mode' }) as HTMLSelectElement;
    for (const m of MODES) this.mode.append(el('option', { value: m }, [m]));
    const go = el('button', { type: 'submit', class: 'wt__btn wf__go' }, ['Run the waterfall']);
    form.append(this.input, this.mode, go);
    form.addEventListener('submit', (e) => { e.preventDefault(); this.run(); });
    const ex = el('div', { class: 'wf__examples', role: 'group', 'aria-label': 'Examples' });
    for (const [q, m] of EXAMPLES) {
      const b = el('button', { type: 'button', class: 'wt__item wf__example', 'data-q': q, 'data-mode': m }, [q === 's n k p' ? 's n k p (first letters)' : m === 'theme' ? `${q} (theme)` : q]);
      b.addEventListener('click', () => { this.input.value = q; this.mode.value = m; this.run(); });
      ex.append(b);
    }
    this.status = el('p', { class: 'wf__status', role: 'status', 'aria-live': 'polite' }, ['Type a query, or pick an example. Nothing is stored; the request goes to the read-only API.']);
    this.out = el('div', { class: 'wf__out' });
    this.replaceChildren(form, ex, this.status, this.out);
    if (this.input.value) this.run();
  }

  private async run() {
    const q = this.input.value.trim();
    if (!q) return;
    const mode = this.mode.value;
    const my = ++this.seq;
    this.status.textContent = `Running /api/search?q=${q}&mode=${mode}…`;
    this.out.replaceChildren();
    lightStep(POSTER, 'step-01');
    const d = await api<Result>(`/api/search?q=${encodeURIComponent(q)}&mode=${encodeURIComponent(mode)}&limit=8`);
    if (my !== this.seq) return;
    if (!d || !Array.isArray(d.results)) {
      this.status.textContent = 'The live API is not reachable right now, so the waterfall cannot run. The page explains every tier in order.';
      lightStep(POSTER, null);
      return;
    }
    const tier = mode !== 'auto' && !d.mode.startsWith('mixed') ? ['step-03', `Explicit mode "${mode}": the tier was chosen up front.`] : this.tierFor(d.mode);
    const honor = /honorific/.test(d.mode);
    if (honor) tier[0] = 'step-09';
    lightStep(POSTER, tier[0]);
    const head = el('div', { class: 'wf__tier' });
    head.append(chip(`mode: ${d.mode}`, 'chip--ok'), el('span', { class: 'wf__why' }, [honor ? 'Honorifics (ji, sahib, guru…) were dropped and the query retried. ' : '', tier[1]]));
    this.out.append(head);
    if (d.concept) this.out.append(el('p', { class: 'wf__concept' }, [el('strong', {}, [`Concept ${d.concept.name}`]), d.concept.description ? ` — ${d.concept.description}` : '', d.concept.total ? ` (${d.concept.total} lines)` : '']));
    if (!d.results.length) {
      this.status.textContent = `No result for “${q}” — the waterfall fell through every tier.`;
      this.out.append(el('p', { class: 'wf__empty' }, ['Every tier was tried and none matched; the last tier reached is lit on the poster.']));
      return;
    }
    this.status.textContent = `${d.results.length} result${d.results.length === 1 ? '' : 's'} shown (of the first page) — verbatim, with the Ang.`;
    const list = el('ol', { class: 'lines' });
    for (const r of d.results) list.append(lineCard(r));
    this.out.append(list);
    if (d.related_themes?.length) {
      const rel = el('p', { class: 'wf__related' }, ['Related themes: ']);
      for (const t of d.related_themes) rel.append(chip(t.concept), ' ');
      this.out.append(rel);
    }
  }

  private tierFor(mode: string): [string, string] {
    for (const [prefix, step, why] of TIERS) if (mode.startsWith(prefix)) return [step, why];
    return ['step-12', 'A tier at the end of the waterfall answered.'];
  }
}
