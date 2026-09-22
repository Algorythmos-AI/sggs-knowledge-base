// theme.ts — light / dark / system theme toggle, resolved to data-theme on <html>.
// Moved verbatim out of core.ts so it can be reused by the marketing shell without pulling in
// the Knowledge Base's DOM/API helpers. Self-contained: its own try/catch localStorage of key
// 'theme' (must NOT import core.ts). Behaviour is identical to the original core.ts block:
// #themeBtn, glyphs ☀/☾/◐, cycle order system→light→dark, aria-label/title.
type Theme = 'light' | 'dark' | 'system';

const readTheme = (): Theme => {
  try { return (localStorage.getItem('theme') as Theme) ?? 'system'; } catch { return 'system'; }
};
const writeTheme = (t: Theme) => { try { localStorage.setItem('theme', t); } catch {} };

const ICON: Record<Theme, string> = { light: '☀', dark: '☾', system: '◐' };
const resolve = (t: Theme): 'light' | 'dark' =>
  t === 'system' ? (matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light') : t;
export function applyTheme(t: Theme) {
  document.documentElement.setAttribute('data-theme', resolve(t));
  const b = document.getElementById('themeBtn');
  if (b) { b.textContent = ICON[t]; b.setAttribute('aria-label', `Theme: ${t} — click to change`); b.title = `Theme: ${t}`; }
}
export function initTheme() {
  applyTheme(readTheme());
  matchMedia('(prefers-color-scheme: dark)').addEventListener('change', () => {
    if (readTheme() === 'system') applyTheme('system');
  });
  const b = document.getElementById('themeBtn');
  if (b) b.onclick = () => {
    const order: Theme[] = ['system', 'light', 'dark'];
    const next = order[(order.indexOf(readTheme()) + 1) % order.length];
    writeTheme(next); applyTheme(next);
  };
}
