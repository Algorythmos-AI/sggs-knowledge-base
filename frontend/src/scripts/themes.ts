// themes.ts — the Themes page (/themes) : the 53 corpus concepts grouped theologically.
// Ported 1:1; a tile deep-links into Search as a theme query via goSearchTheme.
import { $, esc, guard, meta, goSearchTheme } from './core';

const titleCase = (k: string) => k.split('_').map((w) => w.charAt(0).toUpperCase() + w.slice(1)).join(' ');

let META: any = null;

// theological grouping of the 53 corpus concepts (every key assigned; leftover -> "More")
const THEME_CATS: [string, string, string[]][] = [
  ['The Divine Reality', 'God, the Names, and the cosmic Word',
    ['ik_onkar', 'vahiguru', 'karta', 'akal_kaal', 'hukam', 'naam', 'shabad', 'bani', 'jot', 'anhad', 'patit_pavan']],
  ['The Human Condition & Illusions', 'Ego, mind, attachment, and the wheel of birth–death',
    ['haumai', 'maya', 'man', 'sansar', 'janam_maran', 'avagavan', 'manmukh', 'bharam', 'dukh_sukh', 'garab', 'trishna', 'bhavjal', 'jam']],
  ['The Five Vices', 'The panj chor that rob the soul',
    ['kaam', 'krodh', 'lobh', 'moh', 'ahankar']],
  ['The Path & Praxis', 'The Guru, the Sangat, and the daily practice',
    ['satguru', 'gurmukh', 'simran', 'bhagti', 'seva', 'sangat', 'sant_sadh', 'sifat_salah', 'darshan', 'charan', 'marag_panth']],
  ['Virtues & Divine Attributes', 'The qualities the gurmukh cultivates and the Lord embodies',
    ['prem_pyar', 'daya', 'nimrata', 'santokh', 'bhau', 'bhana', 'karam_nadar']],
  ['Spiritual States', 'The fruits of the path — poise, bliss, liberation',
    ['anand', 'sahaj', 'sach', 'mukti', 'amrit', 'maran_jeevan']],
];
const themes = guard(async () => {
  const m = await meta(); META = m;
  const idx: Record<string, number> = {}; m.concepts.forEach((c: any, i: number) => idx[c.concept] = i);
  const placed = new Set<string>();
  const card = (i: number) => {
    const c = m.concepts[i]; placed.add(c.concept);
    const n = (c.n_lines || 0).toLocaleString();
    return `<div class="tile theme-tile" data-concept="${i}" role="button" tabindex="0"
      aria-label="${esc(titleCase(c.concept))} — explore ${n} lines">
      <div class="n">${esc(titleCase(c.concept))}</div>
      <div class="s">${esc(c.description)}</div>
      <div class="explore">Explore ${n} lines →</div></div>`;
  };
  let html = '';
  for (const [cat, sub, keys] of THEME_CATS) {
    const cards = keys.filter((k) => k in idx).map((k) => card(idx[k])).join('');
    if (cards) html += `<div class="gridtitle" role="heading" aria-level="3">${esc(cat)} <span class="ct">· ${esc(sub)}</span></div><div class="grid">${cards}</div>`;
  }
  const leftover = m.concepts.filter((c: any) => !placed.has(c.concept));   // safety: never drop a theme
  if (leftover.length) html += `<div class="gridtitle">More Themes</div><div class="grid">` +
    leftover.map((c: any) => card(idx[c.concept])).join('') + `</div>`;
  ($('#themesOut') as HTMLElement).innerHTML = html;
});

// ---- delegated tile activation → Search (theme mode) ----
function tileActivate(t: any) {
  if (t.dataset.concept !== undefined) goSearchTheme(META.concepts[+t.dataset.concept].concept);
}
document.addEventListener('click', (e: any) => {
  const t = e.target.closest('.tile[data-concept]');
  if (t) tileActivate(t);
});
document.addEventListener('keydown', (e: any) => {
  if ((e.key === 'Enter' || e.key === ' ') && e.target.classList?.contains('tile')) {
    e.preventDefault(); tileActivate(e.target);
  }
});

// ---- bootstrap ----
themes();
