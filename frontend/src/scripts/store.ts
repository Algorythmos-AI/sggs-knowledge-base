// store.ts — the Study Trail "active store": pinned verses in localStorage + lightweight
// client-side ML aggregation over their corpus theme tags. Pure state/compute, no DOM.
// (Distinct from core.ts's tiny `store` localStorage primitive — this manages the pin set.)

export type Pin = { line_id: number; gm: string; ang: number; comp_id: number; themes?: string[]; ts: number };

// shared pin affordance — emitted by search/reader/panel renderers; activated by the
// capture-phase delegate in studytrail.ts (so it never triggers the card's own click).
export function pinButtonHTML(id: number, ang: number, cid: number): string {
  return `<button class="pin-btn" data-id="${id}" data-ang="${ang}" data-cid="${cid}" type="button" aria-label="Pin to study trail" title="Pin to study trail">📌</button>`;
}
const KEY = 'sggs_pins';
export const MAX_PINS = 500;                    // hard cap so the pin set can't outgrow the localStorage quota
export type ToggleResult = 'pinned' | 'unpinned' | 'cap' | 'quota';
type Cb = () => void;
const subs = new Set<Cb>();

function read(): Pin[] { try { return JSON.parse(localStorage.getItem(KEY) || '[]'); } catch { return []; } }
// Returns false if the write was rejected (e.g. QuotaExceededError) so callers can surface the
// failure instead of falsely reporting a pin as saved. Always emits so the UI reflects the TRUE
// persisted state, never an optimistic one.
function write(p: Pin[]): boolean {
  let ok = true;
  try { localStorage.setItem(KEY, JSON.stringify(p)); } catch { ok = false; }
  emit(); return ok;
}
function emit() { subs.forEach((cb) => { try { cb(); } catch {} }); }

export function getPins(): Pin[] { return read().sort((a, b) => b.ts - a.ts); }
export function count(): number { return read().length; }
export function isPinned(id: number): boolean { return read().some((p) => p.line_id === id); }
export function subscribe(cb: Cb): () => void { subs.add(cb); return () => subs.delete(cb); }

// Each mutation re-reads localStorage fresh (it is shared + synchronous across tabs), so two
// tabs pinning different verses no longer clobber each other's writes.
export function addPin(p: Omit<Pin, 'ts'>): boolean {
  const a = read();
  if (a.some((x) => x.line_id === p.line_id)) return true;   // already pinned → success
  if (a.length >= MAX_PINS) return false;                    // cap reached → not added
  a.push({ ...p, ts: Date.now() });
  return write(a);                                           // false on quota failure
}
export function removePin(id: number) { write(read().filter((p) => p.line_id !== id)); }
export function togglePin(p: Omit<Pin, 'ts'>): ToggleResult {
  if (isPinned(p.line_id)) { removePin(p.line_id); return 'unpinned'; }
  const a = read();
  if (a.length >= MAX_PINS) return 'cap';
  a.push({ ...p, ts: Date.now() });
  return write(a) ? 'pinned' : 'quota';
}
export function clearPins() { write([]); }
export function mostRecent(): Pin | null {
  const a = read(); return a.length ? a.reduce((m, x) => (x.ts > m.ts ? x : m)) : null;
}

// keep every open tab/page in sync
window.addEventListener('storage', (e) => { if (e.key === KEY) emit(); });

/* ---------- ML: enrich pins with corpus-verified theme tags (one lazy batch) ---------- */
export async function enrichThemes(): Promise<Pin[]> {
  const a = read();
  const missing = a.filter((p) => !p.themes).map((p) => p.line_id);
  if (missing.length) {
    try {
      const map: Record<string, string[]> = {};
      for (let i = 0; i < missing.length; i += 250) {        // chunk under the server's 300-id cap
        const slice = missing.slice(i, i + 250);
        const d = await fetch('/api/line_concepts?ids=' + slice.join(',')).then((r) => r.json());
        Object.assign(map, d.concepts || {});
      }
      // Re-read AFTER the await: another tab — or a pin added during the fetch window — may
      // have changed the set. Merge themes into the FRESH list so we never clobber new pins
      // with the stale snapshot taken before the network round-trip.
      const fresh = read(); let changed = false;
      fresh.forEach((p) => { if (!p.themes) { p.themes = map[String(p.line_id)] || []; changed = true; } });
      if (changed) write(fresh);                 // persist enrichment so we only fetch once
    } catch { /* offline / endpoint missing → leave themes undefined, UI degrades gracefully */ }
  }
  return read();
}

/* ---------- ML: thematic centre of gravity ---------- */
const FRIENDLY: Record<string, string> = {
  naam: 'Naam · the Name', hukam: 'Hukam · Divine Order', haumai: 'Haumai · Ego', maya: 'Maya · Illusion',
  man: 'Man · the Mind', sach: 'Sach · Truth', mukti: 'Mukti · Liberation', anand: 'Anand · Bliss',
  sahaj: 'Sahaj · Equipoise', prem_pyar: 'Prem · Loving Devotion', seva: 'Seva · Selfless Service',
  simran: 'Simran · Remembrance', bhagti: 'Bhagti · Devotion', satguru: 'Satguru · the True Guru',
  gurmukh: 'Gurmukh · the God-facing', janam_maran: 'Janam-Maran · Birth & Death', moh: 'Moh · Attachment',
  kaam: 'Kaam · Desire', krodh: 'Krodh · Anger', lobh: 'Lobh · Greed', ahankar: 'Ahankar · Pride',
  dukh_sukh: 'Dukh-Sukh · Sorrow & Joy', sangat: 'Sangat · Holy Congregation', shabad: 'Shabad · the Word',
  sifat_salah: 'Sifat-Salah · Praise', karam_nadar: 'Karam · Grace', bairag: 'Bairag · Detachment',
};
const titleCase = (k: string) => k.split('_').map((w) => w.charAt(0).toUpperCase() + w.slice(1)).join(' ');
export const label = (c: string) => FRIENDLY[c] || titleCase(c);

export type Gravity = { total: number; nThemed: number; top: { concept: string; label: string; pct: number; n: number }[]; headline: string };
export function centerOfGravity(pins: Pin[]): Gravity {
  const counts: Record<string, number> = {}; let total = 0, nThemed = 0;
  pins.forEach((p) => { if (p.themes && p.themes.length) nThemed++; (p.themes || []).forEach((c) => { counts[c] = (counts[c] || 0) + 1; total++; }); });
  const top = Object.entries(counts).sort((a, b) => b[1] - a[1])
    .map(([c, n]) => ({ concept: c, label: label(c), pct: total ? Math.round(100 * n / total) : 0, n }));
  let headline: string;
  if (!pins.length) headline = 'Pin verses to reveal the leaning of your study trail.';
  else if (!total) headline = 'These verses carry no tagged themes yet — pin a few more.';
  else headline = `Your trail leans ${top[0].pct}% toward ${top[0].label.split(' · ')[0]}`;
  return { total, nThemed, top, headline };
}

/* ---------- export the study profile (offline Blob download) ---------- */
export function toJSON(pins: Pin[], g: Gravity): string {
  return JSON.stringify({
    generated: new Date().toISOString(), source: 'SGGS Knowledge Base — Study Trail',
    verse_count: pins.length,
    thematic_center_of_gravity: g.top.map((t) => ({ theme: t.concept, label: t.label, share_pct: t.pct, occurrences: t.n })),
    verses: pins.map((p) => ({ line_id: p.line_id, ang: p.ang, comp_id: p.comp_id, gurmukhi: p.gm, themes: p.themes || [] })),
  }, null, 2);
}
export function toText(pins: Pin[], g: Gravity): string {
  const L: string[] = [];
  L.push('ੴ  Sri Guru Granth Sahib — Study Trail');
  L.push('Generated: ' + new Date().toLocaleString());
  L.push('Verses pinned: ' + pins.length);
  L.push('');
  L.push('— Thematic Center of Gravity —');
  L.push(g.headline);
  g.top.slice(0, 6).forEach((t) => L.push(`  ${String(t.pct).padStart(3)}%  ${t.label}  (${t.n})`));
  L.push('');
  L.push('— Pinned Verses —');
  pins.forEach((p, i) => {
    L.push(`${i + 1}. [Ang ${p.ang}]  ${p.gm}`);
    if (p.themes && p.themes.length) L.push('     themes: ' + p.themes.map(label).join(', '));
  });
  L.push('');
  L.push('Scripture shown verbatim with its Ang. Transliteration/analytics are study aids, not the scripture.');
  return L.join('\n');
}
