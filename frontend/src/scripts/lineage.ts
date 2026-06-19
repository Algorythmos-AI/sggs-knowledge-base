// lineage.ts — The Contributors (/lineage).
// An immersive, groupable, comparable view of the voices gathered in the Granth.
// Merges a hand-authored public-domain chronology (public/contributors.json) with the
// live corpus: Ang spans & line counts via /api/meta, and composition stats, a theme
// fingerprint, and distinctive terms via /api/analytics/author.
// READ-ONLY: this view never touches the corpus or scripture text — it only describes it.
import { $, esc, api, goSearchTheme } from './core';

type C = {
  name: string; roman: string; kind: string; seq: number | null;
  born: number; died: number | null; circa: boolean;
  era: string; region: string; tradition: string; blurb: string;
  first_ang?: number; last_ang?: number; n_lines?: number;
};

const KIND_LABEL: Record<string, string> = { guru: 'Guru', bhagat: 'Bhagat', bhatt: 'Bhatt', gursikh: 'Gursikh' };
const KIND_PLURAL: Record<string, string> = { guru: 'Gurus', bhagat: 'Bhagats', bhatt: 'Bhatts', gursikh: 'Gursikhs' };
const KIND_DESC: Record<string, string> = {
  guru: 'The Sikh Gurus', bhagat: 'Bhakti & Sufi saints', bhatt: 'Court bards (Bhatts)', gursikh: 'Gursikh companions',
};
const KIND_ORDER = ['guru', 'bhagat', 'bhatt', 'gursikh'];

let LIST: C[] = [];
const byName = new Map<string, C>();
let groupMode: 'time' | 'kind' | 'volume' = 'time';
let kindFilter = 'all';
let maxLines = 1;

let compareMode = false;
const compareSel: C[] = [];

// ---------- small helpers ----------
const ord = (n: number) => { const s = ['th', 'st', 'nd', 'rd'], v = n % 100; return n + (s[(v - 20) % 10] || s[v] || s[0]); };
const centuryOf = (y: number) => Math.floor((y - 1) / 100) + 1;
const titleCase = (s: string) => (s || '').replace(/\w\S*/g, (t) => t.charAt(0).toUpperCase() + t.slice(1));
const bar = (n: number) => Math.max(4, Math.round(100 * Math.sqrt((n || 0) / maxLines)));   // sqrt so small voices stay visible

// kind-coloured medallion text: M# for Gurus, otherwise the leading initials of the name
const HONORIFIC = new Set(['baba', 'bhai', 'bhagat', 'bhatt', 'guru', 'sant', 'the', 'ji']);
function initials(c: C): string {
  if (c.kind === 'guru' && c.seq) return 'M' + c.seq;
  const words = c.roman.replace(/\(.*?\)/g, '').replace(/&/g, ' ').split(/\s+/)
    .filter((w) => w && !HONORIFIC.has(w.toLowerCase()));
  const pick = (words.length ? words : c.roman.split(/\s+/)).slice(0, 2);
  const letters = pick.map((w) => (w.replace(/[^A-Za-z]/g, '')[0] || '')).join('');
  return (letters || c.roman[0] || '•').toUpperCase();
}

// ---------- load ----------
async function load() {
  const host = $('#timeline'); if (!host) return;
  let data: any, meta: any;
  try {
    [data, meta] = await Promise.all([fetch('/contributors.json').then((r) => r.json()), api('meta')]);
  } catch { host.innerHTML = '<div class="hint">Could not load the contributor data.</div>'; return; }

  const live: Record<string, any> = {};
  (meta.authors || []).forEach((a: any) => { live[a.name] = a; });
  LIST = (data.contributors || []).map((c: C) => ({
    ...c,
    first_ang: live[c.name]?.first_ang, last_ang: live[c.name]?.last_ang, n_lines: live[c.name]?.n_lines,
  }));
  LIST.forEach((c) => byName.set(c.name, c));
  maxLines = Math.max(1, ...LIST.map((c) => c.n_lines || 0));

  renderHero();
  renderLegend();
  wireControls();
  render();
}

// ---------- hero ----------
function renderHero() {
  let verses = 0, bMin = Infinity, bMax = -Infinity;
  LIST.forEach((c) => {
    verses += c.n_lines || 0;
    bMin = Math.min(bMin, c.born);
    bMax = Math.max(bMax, c.died || c.born);
  });
  const span = `${ord(centuryOf(bMin))}–${ord(centuryOf(bMax))} c.`;
  const h = $('#linHeadline');
  if (h) h.textContent = `${LIST.length} voices · ${ord(centuryOf(bMin))}–${ord(centuryOf(bMax))} century`;
  const s = $('#linStats');
  const tile = (v: string | number, l: string) =>
    `<div class="lin-stat"><span class="lin-stat-v">${esc(String(v))}</span><span class="lin-stat-l">${esc(l)}</span></div>`;
  if (s) s.innerHTML = [
    tile(LIST.length, 'contributors'),
    tile(verses.toLocaleString(), 'verses preserved here'),
    tile(span, 'span of voices'),
  ].join('');
}

// ---------- legend / kind filter ----------
function renderLegend() {
  const el = $('#tlFilter'); if (!el) return;
  const counts: Record<string, number> = {};
  LIST.forEach((c) => { counts[c.kind] = (counts[c.kind] || 0) + 1; });
  const chip = (k: string, label: string, n: number) =>
    `<button class="lin-chip${kindFilter === k ? ' on' : ''}${k !== 'all' ? ' kind-' + k : ''}" data-k="${k}" type="button" aria-pressed="${kindFilter === k}">` +
    `${k !== 'all' ? '<span class="lin-dot" aria-hidden="true"></span>' : ''}${esc(label)}<span class="lin-chip-n">${n}</span></button>`;
  el.innerHTML = chip('all', 'All', LIST.length) + KIND_ORDER.map((k) => chip(k, KIND_PLURAL[k], counts[k] || 0)).join('');
  el.querySelectorAll('.lin-chip').forEach((b: any) => {
    b.addEventListener('click', () => { kindFilter = b.dataset.k || 'all'; renderLegend(); render(); });
  });
}

// ---------- controls (group-by + compare toggle) ----------
function wireControls() {
  const g = $('#linGroup');
  g?.querySelectorAll('[data-g]').forEach((b: any) => {
    b.addEventListener('click', () => {
      groupMode = (b.dataset.g || 'time') as typeof groupMode;
      g.querySelectorAll('[data-g]').forEach((x: any) => {
        const on = x === b; x.classList.toggle('on', on); x.setAttribute('aria-pressed', String(on));
      });
      render();
    });
  });
  $('#cmpToggle')?.addEventListener('click', () => setCompare(!compareMode));
}

// ---------- main render of the timeline ----------
function render() {
  const host = $('#timeline'); if (!host) return;
  const rows = kindFilter === 'all' ? LIST.slice() : LIST.filter((c) => c.kind === kindFilter);

  let html = '';
  if (groupMode === 'volume') {
    rows.sort((a, b) => (b.n_lines || 0) - (a.n_lines || 0));
    html = band('Ordered by how much Bani is preserved here', rows.length) + rows.map(nodeHTML).join('');
  } else if (groupMode === 'kind') {
    const order = kindFilter === 'all' ? KIND_ORDER : [kindFilter];
    html = order.map((k) => {
      const g = rows.filter((c) => c.kind === k).sort((a, b) => a.born - b.born);
      if (!g.length) return '';
      return band(KIND_DESC[k], g.length) + g.map(nodeHTML).join('');
    }).join('');
  } else {
    rows.sort((a, b) => a.born - b.born);
    let cur = -1;
    html = rows.map((c) => {
      const cen = centuryOf(c.born);
      let pre = '';
      if (cen !== cur) { cur = cen; const n = rows.filter((x) => centuryOf(x.born) === cen).length; pre = band(`${ord(cen)} century`, n); }
      return pre + nodeHTML(c);
    }).join('');
  }

  host.innerHTML = html || '<div class="hint">No voices in this filter.</div>';
  host.querySelectorAll('.tl-node').forEach((n: any) => {
    n.onclick = () => {
      const c = byName.get(n.dataset.name); if (!c) return;
      if (compareMode) toggleCompareSelect(c); else openDetail(c);
    };
  });
  markSelected();
}

function band(label: string, n: number): string {
  return `<div class="tl-band"><span class="tl-band-l">${esc(label)}</span><span class="tl-band-n">${n} ${n === 1 ? 'voice' : 'voices'}</span></div>`;
}

function nodeHTML(c: C): string {
  const yr = (c.circa ? 'c.' : '') + c.born;
  const lines = c.n_lines ? `${c.n_lines.toLocaleString()} lines · Angs ${c.first_ang}–${c.last_ang}` : 'in the corpus';
  return `<button class="tl-node kind-${esc(c.kind)}" data-name="${esc(c.name)}" type="button" aria-label="${esc(c.roman)} — open profile">
      <span class="tl-year">${esc(yr)}</span>
      <span class="tl-dot" aria-hidden="true"></span>
      <span class="tl-card">
        <span class="tl-med" aria-hidden="true">${esc(initials(c))}</span>
        <span class="tl-main">
          <span class="tl-row"><span class="tl-name">${esc(c.roman)}</span><span class="tl-kind">${KIND_LABEL[c.kind] || c.kind}${c.seq ? ' · M' + c.seq : ''}</span></span>
          <span class="tl-era">${esc(c.era)} · ${esc(c.region)}</span>
          <span class="tl-bar" aria-hidden="true"><i style="width:${bar(c.n_lines || 0)}%"></i></span>
          <span class="tl-lines">${esc(lines)}</span>
        </span>
        <span class="tl-pick" aria-hidden="true">✓</span>
      </span>
    </button>`;
}

// ---------- shared modal helpers ----------
const setTitle = (t: string) => { const pt = $('#ptitle'); if (pt) pt.textContent = t; };
const setBody = (h: string) => { const pb = $('#pbody'); if (pb) pb.innerHTML = h; };
const openPanel = () => (window as any).openPanel?.();
const closePanel = () => (window as any).closePanel?.();

// ---------- a single contributor profile (full panel, or compact compare column) ----------
function profileHTML(c: C, d: any, compact: boolean): string {
  const st = (d && d.stylometry) || {};
  const reliable = st.is_reliable !== 0;
  const lifespan = c.died ? `${c.circa ? 'c.' : ''}${c.born}–${c.died}` : `${c.circa ? 'c.' : ''}${c.born}`;

  // stat tiles — prefer the corpus line count (matches the card) for consistency
  const lineN = c.n_lines ?? st.n_lines;
  const tile = (v: any, l: string, note?: string) =>
    (v == null || v === '' || (typeof v === 'number' && isNaN(v))) ? '' :
      `<div class="ld-stat"><span class="ld-stat-v">${esc(String(v))}</span><span class="ld-stat-l">${esc(l)}${note ? ` <span class="ld-q" tabindex="0" role="img" aria-label="${esc(note)}" title="${esc(note)}">?</span>` : ''}</span></div>`;
  const tiles = [
    tile(typeof lineN === 'number' ? lineN.toLocaleString() : lineN, 'Lines'),
    tile(st.n_shabads, 'Compositions'),
    tile(st.n_raags, 'Raags'),
    tile(st.avg_words_line != null ? (+st.avg_words_line).toFixed(1) : null, 'Avg words / line'),
    tile(st.mattr_100 != null ? (+st.mattr_100).toFixed(2) : null, 'Lexical variety', 'Share of unique words across the text (0–1). Higher means a more varied vocabulary. Measured on the English translation.'),
    tile(c.first_ang ? `${c.first_ang}–${c.last_ang}` : null, 'Ang range'),
  ].filter(Boolean).join('');
  const statsHTML = tiles ? `<div class="ld-statgrid">${tiles}</div>`
    : (compact ? '' : '<div class="ld-note ld-sec">Composition statistics aren’t available for this voice in this build.</div>');

  // signature themes (lift vs. corpus baseline)
  let themesHTML = '';
  const fp = ((d && d.theme_fingerprint) || []).filter((t: any) => t && t.lift != null);
  if (reliable && fp.length) {
    const top = fp.slice(0, compact ? 5 : 6);
    const maxL = Math.max(...top.map((t: any) => +t.lift)) || 1;
    themesHTML = `<div class="ld-sec"><div class="ld-h">Signature themes <span class="ld-note">— ideas this voice returns to more than the Granth overall</span></div>` +
      top.map((t: any) => {
        const w = Math.max(8, Math.round((+t.lift) / maxL * 100));
        return `<div class="ld-trow"><button class="ld-tlabel" data-theme="${esc(t.concept)}" type="button" title="Search this theme across the Granth">${esc(titleCase(String(t.concept).replace(/_/g, ' ')))}</button>` +
          `<span class="ld-ttrack" aria-hidden="true"><i style="width:${w}%"></i></span><span class="ld-tpct">×${(+t.lift).toFixed(1)}</span></div>`;
      }).join('') + `</div>`;
  }

  // distinctive words (full profile only)
  let termsHTML = '';
  if (!compact) {
    const terms = ((d && d.distinctive_terms) || []).slice(0, 10);
    if (reliable && terms.length) {
      termsHTML = `<div class="ld-sec"><div class="ld-h">Distinctive words <span class="ld-note">(keyness vs. corpus · English translation)</span></div>` +
        `<div class="ld-termwrap">${terms.map((t: any) => `<span class="ld-term">${esc(t.term)}</span>`).join('')}</div></div>`;
    } else if (!reliable) {
      termsHTML = `<div class="ld-note ld-sec">Stylometry is withheld here — this voice’s sample is too small to compare reliably.</div>`;
    }
  }

  // actions
  const actions = compact
    ? (c.first_ang ? `<div class="ld-cactions"><button onclick="goReader(${c.first_ang})" type="button">Read · Ang ${c.first_ang} →</button></div>` : '')
    : `<div class="endnav ld-actions">
        <button class="ld-cmp" data-name="${esc(c.name)}" type="button">⇄ Compare with another voice</button>
        ${c.first_ang ? `<button onclick="goReader(${c.first_ang})" type="button">Read their first composition · Ang ${c.first_ang} →</button>` : '<span></span>'}
      </div>`;

  return `<div class="ld kind-${esc(c.kind)}">
    <div class="ld-hero">
      <span class="ld-med" aria-hidden="true">${esc(initials(c))}</span>
      <div class="ld-id">
        <div class="ld-name">${esc(c.roman)}</div>
        <div class="ld-chips">
          <span class="ld-chip kind-${esc(c.kind)}">${KIND_LABEL[c.kind] || c.kind}${c.seq ? ' · M' + c.seq : ''}</span>
          <span class="ld-chip">${esc(lifespan)}</span>
          <span class="ld-chip">${esc(c.region)}</span>
          <span class="ld-chip">${esc(c.tradition)}</span>
        </div>
      </div>
    </div>
    <p class="ld-blurb${compact ? ' ld-blurb-c' : ''}">${esc(c.blurb)}</p>
    ${statsHTML}${themesHTML}${termsHTML}${actions}
  </div>`;
}

// theme links + compare buttons inside freshly-rendered modal content
function wireProfile() {
  const root = $('#pbody'); if (!root) return;
  root.querySelectorAll('.ld-tlabel').forEach((b: any) => b.addEventListener('click', () => goSearchTheme(b.dataset.theme || '')));
  root.querySelectorAll('.ld-cmp').forEach((b: any) => b.addEventListener('click', () => { const nm = b.dataset.name || ''; closePanel(); startCompareWith(nm); }));
}

const fetchAnalytics = (c: C) => api('analytics/author?author=' + encodeURIComponent(c.name)).catch(() => ({}));

async function openDetail(c: C) {
  openPanel();
  setTitle('Voice in the Granth');
  setBody('<div class="hint">Loading profile…</div>');
  const d = await fetchAnalytics(c);
  if (!$('#panel')?.classList.contains('on')) return;   // user closed it while loading
  setBody(profileHTML(c, d, false));
  wireProfile();
}

// ---------- compare mode ----------
function setCompare(on: boolean) {
  compareMode = on;
  document.body.classList.toggle('cmp-mode', on);
  const t = $('#cmpToggle');
  if (t) { t.classList.toggle('on', on); t.setAttribute('aria-pressed', String(on)); }
  if (!on) compareSel.length = 0;
  markSelected();
  renderTray();
}
function startCompareWith(name: string) {
  setCompare(true);
  const c = byName.get(name);
  if (c) toggleCompareSelect(c);
}
function toggleCompareSelect(c: C) {
  const i = compareSel.findIndex((x) => x.name === c.name);
  if (i >= 0) compareSel.splice(i, 1);
  else { if (compareSel.length >= 2) compareSel.shift(); compareSel.push(c); }
  markSelected();
  renderTray();
  if (compareSel.length === 2) openCompare(compareSel[0], compareSel[1]);
}
function markSelected() {
  $('#timeline')?.querySelectorAll('.tl-node').forEach((n: any) => {
    n.classList.toggle('cmp-on', compareMode && compareSel.some((c) => c.name === n.dataset.name));
  });
}
function renderTray() {
  const t = $('#cmpTray'); if (!t) return;
  if (!compareMode) { (t as HTMLElement).hidden = true; t.innerHTML = ''; return; }
  (t as HTMLElement).hidden = false;
  const need = 2 - compareSel.length;
  const chips = compareSel.map((c) =>
    `<span class="cmp-chip kind-${esc(c.kind)}"><span class="lin-dot" aria-hidden="true"></span>${esc(c.roman)}<button class="cmp-x" data-name="${esc(c.name)}" type="button" aria-label="Remove ${esc(c.roman)}">×</button></span>`).join('');
  t.innerHTML = `<span class="cmp-tray-l">⇄ Compare</span>${chips}` +
    `<span class="cmp-hint">${need > 0 ? `Pick ${need} more voice${need > 1 ? 's' : ''} on the timeline` : 'Showing comparison'}</span>` +
    `<button class="cmp-clear" type="button">Done</button>`;
  t.querySelectorAll('.cmp-x').forEach((b: any) => b.addEventListener('click', (e: any) => {
    e.stopPropagation();
    const i = compareSel.findIndex((x) => x.name === b.dataset.name);
    if (i >= 0) { compareSel.splice(i, 1); markSelected(); renderTray(); }
  }));
  t.querySelector('.cmp-clear')?.addEventListener('click', () => setCompare(false));
}
async function openCompare(a: C, b: C) {
  openPanel();
  setTitle('Compare voices');
  setBody('<div class="hint">Loading comparison…</div>');
  const [da, db] = await Promise.all([fetchAnalytics(a), fetchAnalytics(b)]);
  if (!$('#panel')?.classList.contains('on')) return;
  setBody(`<div class="cmp-grid"><div class="cmp-col">${profileHTML(a, da, true)}</div><div class="cmp-col">${profileHTML(b, db, true)}</div></div>`);
  wireProfile();
}

load();
