// <sggs-ang-explorer ang="1">: every line record of one Ang, exactly as /api/ang/{n} returns it —
// verbatim Gurmukhi with its Ang, the placement and heading columns beside it, and a one-line
// definition of each column (hover the header, or open "What the columns mean"). Quick picks jump
// to Angs that show a particular shape; filters narrow to headings or rahao lines. All text is
// set through DOM APIs (no innerHTML of API data). Without JavaScript the page keeps its prose.
import { api, el } from './api';

type Line = {
  id: number; ang: number; raag: string | null; section: string | null; author: string | null;
  comp_type: string | null; comp_id: number; line_no: number; is_rahao: number; is_header: number;
  gurmukhi: string; translit: string; stanza_index?: number; pada_total?: number; source_category?: string; en?: string | null;
};
type Ang = { ang: number; lines: Line[]; continued_from: number | null; raag: string | null; section: string | null; authors: string[] };

const COLUMNS: [keyof Line, string][] = [
  ['id', 'The row id: the line’s stable identity across the whole corpus (1–60,658). Never reused.'],
  ['line_no', 'Position inside its composition, 1..N, always contiguous.'],
  ['comp_id', 'Groups every line of one composition, heading run included; vacated ids stay as permanent gaps.'],
  ['is_header', '1 on a heading line — a title, the ੴ invocation, a ਮਃ label. The metadata columns come from here.'],
  ['is_rahao', '1 on the refrain (rahao) line of a shabad, detected from its ਰਹਾਉ marker.'],
  ['author', 'From the ਮਹਲਾ / Bhagat header; null where the print has none (all of Japji).'],
  ['gurmukhi', 'The line as printed, verbatim, dandas and markers included. Never edited anywhere in the system.'],
  ['translit', 'Roman transliteration built by the pipeline — a reading aid, not scripture.'],
  ['en', 'English (Dr. Sant Singh Khalsa via ShabadOS): a separate, labelled layer, never blended into the Gurmukhi.'],
];
const PICKS: [number, string][] = [
  [1, 'Ang 1 · the opening: a heading, then Japji with author null'],
  [151, 'Ang 151 · a raag title and its invocation form one heading run'],
  [462, 'Ang 462 · Asa Ki Vaar begins: saloks and pauris interleave'],
  [712, 'Ang 712 · the first composition continues from Ang 711'],
  [1256, 'Ang 1256 · a refrain printed twice — a legitimate repeat, never de-duplicated'],
];
type Filter = 'all' | 'headers' | 'rahao';

export class SggsAngExplorer extends HTMLElement {
  private ang = 1;
  private filter: Filter = 'all';
  private showEn = false;
  private data: Ang | null = null;
  private status!: HTMLElement;
  private table!: HTMLElement;
  private input!: HTMLInputElement;
  private seq = 0;

  connectedCallback() {
    const a = parseInt(this.getAttribute('ang') ?? '1', 10);
    this.ang = Number.isFinite(a) ? Math.min(1430, Math.max(1, a)) : 1;
    this.build();
    this.load();
  }

  private build() {
    const form = el('form', { class: 'ax__bar', role: 'search', 'aria-label': 'Choose an Ang' });
    this.input = el('input', { type: 'number', min: '1', max: '1430', value: String(this.ang), class: 'ax__input', 'aria-label': 'Ang number (1 to 1430)' }) as HTMLInputElement;
    const go = el('button', { type: 'submit', class: 'wt__btn ax__go' }, ['Open Ang']);
    const prev = el('button', { type: 'button', class: 'wt__btn ax__prev', 'aria-label': 'Previous Ang' }, ['◀']);
    const next = el('button', { type: 'button', class: 'wt__btn ax__next', 'aria-label': 'Next Ang' }, ['▶']);
    prev.addEventListener('click', () => this.go(this.ang - 1));
    next.addEventListener('click', () => this.go(this.ang + 1));
    form.addEventListener('submit', (e) => { e.preventDefault(); this.go(parseInt(this.input.value, 10)); });
    form.append(el('label', { class: 'ax__label', for: this.uid('ang') }, ['Ang']), this.input, go, prev, next);
    this.input.id = this.uid('ang');

    const picks = el('div', { class: 'ax__picks', role: 'group', 'aria-label': 'Quick picks' });
    for (const [n, label] of PICKS) {
      const b = el('button', { type: 'button', class: 'wt__item ax__pick', 'data-ang': String(n) }, [label]);
      b.addEventListener('click', () => this.go(n));
      picks.append(b);
    }
    const filters = el('div', { class: 'ax__filters', role: 'group', 'aria-label': 'Show' });
    const mk = (f: Filter, label: string) => {
      const b = el('button', { type: 'button', class: 'wt__item ax__filter', 'data-filter': f, 'aria-pressed': String(f === this.filter) }, [label]);
      b.addEventListener('click', () => { this.filter = f; this.render(); });
      return b;
    };
    const en = el('label', { class: 'ax__en' }) as HTMLLabelElement;
    const enBox = el('input', { type: 'checkbox', class: 'ax__en-box' }) as HTMLInputElement;
    enBox.addEventListener('change', () => { this.showEn = enBox.checked; this.render(); });
    en.append(enBox, ' show the English layer');
    filters.append(mk('all', 'All lines'), mk('headers', 'Headings only'), mk('rahao', 'Rahao lines only'), en);

    this.status = el('p', { class: 'ax__status', role: 'status', 'aria-live': 'polite' });
    this.table = el('div', { class: 'ax__table', tabindex: '0' });
    const defs = el('details', { class: 'ax__defs' });
    defs.append(el('summary', {}, ['What the columns mean']));
    const dl = el('dl');
    for (const [k, d] of COLUMNS) dl.append(el('dt', {}, [el('code', {}, [String(k)])]), el('dd', {}, [d]));
    defs.append(dl);
    this.replaceChildren(form, picks, filters, this.status, this.table, defs);
  }

  private uid(s: string) { return `ax-${s}-${Math.random().toString(36).slice(2, 8)}`; }

  private go(n: number) {
    if (!Number.isFinite(n)) return;
    this.ang = Math.min(1430, Math.max(1, n));
    this.input.value = String(this.ang);
    this.load();
  }

  private async load() {
    const my = ++this.seq;
    this.data = null;
    this.status.textContent = `Loading Ang ${this.ang} from /api/ang/${this.ang}…`;
    this.table.replaceChildren();
    const d = await api<Ang>(`/api/ang/${this.ang}`);
    if (my !== this.seq) return;
    if (!d || !Array.isArray(d.lines)) {
      this.status.textContent = `The live API is not reachable right now, so Ang ${this.ang} cannot be shown. The prose on this page describes the same record shape.`;
      this.status.classList.add('ax__status--bad');
      return;
    }
    this.status.classList.remove('ax__status--bad');
    this.data = d;
    this.render();
  }

  private render() {
    const d = this.data;
    if (!d) return;
    for (const b of this.querySelectorAll<HTMLButtonElement>('.ax__filter')) b.setAttribute('aria-pressed', String(b.dataset.filter === this.filter));
    for (const b of this.querySelectorAll<HTMLButtonElement>('.ax__pick')) b.setAttribute('aria-current', b.dataset.ang === String(d.ang) ? 'true' : 'false');
    const rows = d.lines.filter((l) => this.filter === 'all' || (this.filter === 'headers' ? l.is_header === 1 : l.is_rahao === 1));
    const headers = d.lines.filter((l) => l.is_header === 1).length;
    const rahao = d.lines.filter((l) => l.is_rahao === 1).length;
    const comps = new Set(d.lines.map((l) => l.comp_id)).size;
    const bits = [`Sri Guru Granth Sahib Ji · Ang ${d.ang}`, `${d.lines.length} lines`, `${comps} composition${comps === 1 ? '' : 's'}`, `${headers} heading${headers === 1 ? '' : 's'}`, `${rahao} rahao`];
    if (d.raag) bits.push(`raag ${d.raag}`);
    if (d.section) bits.push(`section ${d.section}`);
    if (d.authors?.length) bits.push(`authors: ${d.authors.join(', ')}`);
    if (d.continued_from) bits.push(`the first composition continues from Ang ${d.continued_from}`);
    this.status.textContent = bits.join(' · ') + (this.filter === 'all' ? '' : ` · showing ${rows.length}`);

    const cols = COLUMNS.filter(([k]) => k !== 'en' || this.showEn);
    const table = el('table', { class: 'ax__grid' });
    const cap = el('caption', {}, [`Line records of Ang ${d.ang}, verbatim from the API`]);
    const thead = el('thead'), tr = el('tr');
    for (const [k, def] of cols) tr.append(el('th', { scope: 'col' }, [el('abbr', { title: def }, [String(k)])]));
    thead.append(tr);
    const tbody = el('tbody');
    for (const l of rows) {
      const r = el('tr', { class: `${l.is_header ? 'is-header' : ''} ${l.is_rahao ? 'is-rahao' : ''}`.trim() });
      for (const [k] of cols) {
        const v = l[k];
        const td = el('td', { 'data-col': String(k) });
        if (k === 'gurmukhi') td.append(el('span', { lang: 'pa', class: 'gm' }, [String(v ?? '')]));
        else if (k === 'en') td.append(el('span', { class: 'ax__en-text' }, [v == null ? '—' : String(v)]));
        else if (k === 'is_header' || k === 'is_rahao') td.textContent = v ? '1' : '0';
        else td.textContent = v == null ? 'null' : String(v);
        r.append(td);
      }
      tbody.append(r);
    }
    table.append(cap, thead, tbody);
    this.table.replaceChildren(table);
    if (!rows.length) this.table.append(el('p', { class: 'ax__empty' }, ['No line on this Ang matches that filter.']));
  }
}
