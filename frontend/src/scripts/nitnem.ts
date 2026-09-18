// nitnem.ts — the Nitnem / Gutka page (/nitnem): the bani registry from /api/banis and a
// paper reader over /api/bani/{key}. Every Sri Guru Granth Sahib Ji line is served verbatim
// from the corpus and cited by Ang (tapping it opens the Reader at that line); lines from
// the separate non-SGGS layer (Sri Dasam Granth / Ardaas) carry their source label and are
// never cited as an Ang. Reading position per bani lives in localStorage (this browser only).
// All scripture/API text goes through esc() before innerHTML; the `.gm` class lets saroop.ts
// paint the traditional rendering (display only).
import { $, esc, guard, api, store, goReader, applyPrefs, toast } from './core';

const CATEGORY_TITLE: Record<string, string> = {
  nitnem_morning: 'Morning', nitnem_evening: 'Evening', nitnem_night: 'Night',
  popular: 'Popular', ceremony: 'Ceremony',
};
const EXTRA_NOTE = 'Sri Dasam Granth / Ardaas text via ShabadOS — a separate layer, not part of Sri Guru Granth Sahib Ji.';

let BANIS: any[] = [];
let current: { key: string; variant: string } | null = null;
let saveTimer: number | undefined;

const prefs = {
  get rehras(): string { return store.get('sggs_rehras_variant') || 'sgpc'; },
  set rehras(v: string) { store.set('sggs_rehras_variant', v); },
  pos(id: string): number { return parseInt(store.get('sggs_bani_pos_' + id) || '0', 10) || 0; },
  setPos(id: string, seq: number) { store.set('sggs_bani_pos_' + id, String(seq)); },
};

function baniId(b: any) { return b.variant ? `${b.key}/${b.variant}` : b.key; }
function visible(banis: any[]) {
  return banis.filter((b) => (b.key === 'rehras' ? b.variant === prefs.rehras : b.is_default));
}

// ---- list ---------------------------------------------------------------------------
const renderList = () => {
  const rows = visible(BANIS);
  const cats = ['nitnem_morning', 'nitnem_evening', 'nitnem_night', 'popular', 'ceremony'];
  let h = `<div class="raagbanner"><div class="rn">Nitnem · Gutka Sahib</div>
    <div class="rr">Daily banis, read from the verbatim corpus and cited by Ang. Non-SGGS text is a separate, labelled layer.</div></div>`;
  for (const c of cats) {
    const list = rows.filter((b) => b.category === c);
    if (!list.length) continue;
    h += `<h2 class="sect">${esc(CATEGORY_TITLE[c] || c)}</h2><div class="tiles">`;
    h += list.map((b) => {
      const id = baniId(b);
      const pos = prefs.pos(id);
      const pct = pos > 1 ? Math.min(100, Math.round((pos / b.n_lines) * 100)) : 0;
      const meta = [b.estimated_minutes ? `about ${b.estimated_minutes} min` : '',
                    b.has_extra ? 'includes Sri Dasam Granth text' : ''].filter(Boolean).join(' · ');
      return `<div class="tile bani-tile" data-key="${esc(b.key)}" role="button" tabindex="0"
          aria-label="${esc(b.title_en)}${pct ? `, ${pct} percent read` : ''}">
        <div class="n gm" lang="pa">${esc(b.title_gm)}</div>
        <div class="r">${esc(b.title_en)}</div>
        <div class="s">${esc(meta)}${pct ? ` · ${pct}% read` : ''}</div></div>`;
    }).join('');
    h += '</div>';
  }
  h += `<p class="hint">Rehras Sahib version:
    <select id="rehrasSel" aria-label="Rehras Sahib version">
      <option value="sgpc" ${prefs.rehras === 'sgpc' ? 'selected' : ''}>SGPC (standard)</option>
      <option value="taksal" ${prefs.rehras === 'taksal' ? 'selected' : ''}>Damdami Taksal</option>
    </select></p>`;
  ($('#nitnemList') as HTMLElement).innerHTML = h;
  ($('#rehrasSel') as HTMLSelectElement | null)?.addEventListener('change', (e) => {
    prefs.rehras = (e.target as HTMLSelectElement).value; renderList();
  });
  document.querySelectorAll('.bani-tile').forEach((t) => {
    const open = () => openBani((t as HTMLElement).dataset.key || '');
    t.addEventListener('click', open);
    t.addEventListener('keydown', (e: any) => { if (e.key === 'Enter' || e.key === ' ') { e.preventDefault(); open(); } });
  });
};

// ---- reader -------------------------------------------------------------------------
const openBani = guard(async (key: string, variant?: string) => {
  const v = variant ?? (key === 'rehras' ? prefs.rehras : '');
  const d = await api('bani/' + encodeURIComponent(key) + (v ? '?variant=' + encodeURIComponent(v) : ''));
  if (!d || !d.available) { toast('This bani is not available'); return; }
  current = { key, variant: d.bani.variant || '' };
  const id = baniId(d.bani);
  const range = d.ang_first != null
    ? (d.ang_first === d.ang_last ? `Sri Guru Granth Sahib Ji · Ang ${d.ang_first}` : `Sri Guru Granth Sahib Ji · Ang ${d.ang_first}–${d.ang_last}`)
    : (d.bani.has_extra ? 'Sri Dasam Granth · separate layer' : '');
  ($('#baniHead') as HTMLElement).innerHTML = `<div class="rn gm" lang="pa">${esc(d.bani.title_gm)}</div>
    <div class="rr">${esc(d.bani.title_en)}${range ? ' · ' + esc(range) : ''}${d.bani.estimated_minutes ? ` · about ${d.bani.estimated_minutes} min` : ''}</div>
    ${d.bani.has_extra ? `<div class="rr">${esc(EXTRA_NOTE)}</div>` : ''}`;
  const vs = (d.variants || []).filter((x: string) => x);
  ($('#nitnemVariants') as HTMLElement).innerHTML = vs.length > 1
    ? vs.map((x: string) => `<button type="button" class="vbtn" data-v="${esc(x)}" ${x === current!.variant ? 'disabled' : ''}>${esc(x === 'sgpc' ? 'SGPC' : x === 'taksal' ? 'Taksal' : x)}</button>`).join(' ')
    : '';
  document.querySelectorAll('#nitnemVariants .vbtn').forEach((b) =>
    b.addEventListener('click', () => { const nv = (b as HTMLElement).dataset.v || ''; if (key === 'rehras') prefs.rehras = nv; openBani(key, nv); }));

  let h = '';
  let group = 0;
  for (const l of d.lines) {
    if (l.line_group !== group) {
      if (group) h += '</div>';
      group = l.line_group;
      h += `<div class="shabad" data-group="${group}">`;
    }
    const isHeader = !!l.is_header && (l.gurmukhi.split(' ').length <= 6 || !l.gurmukhi.endsWith('॥'));
    if (isHeader) {
      h += `<div class="hdr gm" lang="pa"><div class="${l.gurmukhi.startsWith('ੴ') ? 'invoc' : ''}">${esc(l.gurmukhi)}</div>
        <div class="t">${esc(l.translit)}</div></div>`;
      continue;
    }
    if (l.source === 'sggs') {
      h += `<div class="sline tap ${l.is_rahao ? 'rahao' : ''}" data-seq="${l.seq}" data-ang="${l.ang}" data-line-id="${l.id}" data-comp="${l.comp_id}"
          title="Open Ang ${l.ang} in the Reader">
        <div class="g gm" lang="pa">${esc(l.gurmukhi)}</div><div class="t">${esc(l.translit)}</div>
        ${l.en ? `<div class="en" lang="en">${esc(l.en)}</div>` : ''}
        <div class="cite">Sri Guru Granth Sahib Ji · Ang ${l.ang}</div></div>`;
    } else {
      const src = l.source === 'dasam' ? (l.panna != null ? `Sri Dasam Granth · Panna ${l.panna}` : 'Sri Dasam Granth') : 'Ardaas';
      h += `<div class="sline extra" data-seq="${l.seq}">
        <div class="g gm" lang="pa">${esc(l.gurmukhi)}</div><div class="t">${esc(l.translit)}</div>
        <div class="cite">${esc(src)} · separate layer</div></div>`;
    }
  }
  if (group) h += '</div>';
  h += `<div class="endnav"><button type="button" id="baniTop">Top</button><button type="button" id="baniDone">Mark as read · start again</button></div>`;
  ($('#baniOut') as HTMLElement).innerHTML = h;
  ($('#nitnemList') as HTMLElement).hidden = true;
  ($('#nitnemReader') as HTMLElement).hidden = false;
  applyPrefs();
  document.querySelectorAll('#baniOut .sline.tap').forEach((el) => {
    el.addEventListener('click', () => {
      const e = el as HTMLElement;
      goReader(parseInt(e.dataset.ang || '1', 10), undefined, { line: parseInt(e.dataset.lineId || '0', 10), comp: parseInt(e.dataset.comp || '0', 10) });
    });
  });
  ($('#baniTop') as HTMLElement).addEventListener('click', () => window.scrollTo({ top: 0 }));
  ($('#baniDone') as HTMLElement).addEventListener('click', () => { prefs.setPos(id, 0); toast('Marked as read'); window.scrollTo({ top: 0 }); });
  // resume: the saved line scrolls into view
  const saved = prefs.pos(id);
  const target = saved > 1 ? document.querySelector(`#baniOut [data-seq="${saved}"]`) : null;
  if (target) target.scrollIntoView({ block: 'center' }); else window.scrollTo({ top: 0 });
  try { history.replaceState(null, '', `/nitnem?bani=${encodeURIComponent(key)}${current.variant ? '&variant=' + encodeURIComponent(current.variant) : ''}`); } catch { /* ignore */ }
});

// position tracking: the first line whose top is below the header becomes the saved position
function trackPosition() {
  if (!current) return;
  window.clearTimeout(saveTimer);
  saveTimer = window.setTimeout(() => {
    const lines = Array.from(document.querySelectorAll('#baniOut [data-seq]')) as HTMLElement[];
    const top = 120;
    const first = lines.find((el) => el.getBoundingClientRect().bottom > top);
    const b = BANIS.find((x) => x.key === current!.key && (x.variant || '') === current!.variant);
    if (first && b) prefs.setPos(baniId(b), parseInt(first.dataset.seq || '0', 10));
  }, 500);
}

function backToList() {
  current = null;
  ($('#nitnemReader') as HTMLElement).hidden = true;
  ($('#nitnemList') as HTMLElement).hidden = false;
  renderList();
  try { history.replaceState(null, '', '/nitnem'); } catch { /* ignore */ }
  window.scrollTo({ top: 0 });
}

// ---- boot ---------------------------------------------------------------------------
const boot = guard(async () => {
  const d = await api('banis');
  if (!d || !d.available) {
    ($('#nitnemList') as HTMLElement).innerHTML = '<div class="hint">The Nitnem registry is not in this database build.</div>';
    return;
  }
  BANIS = d.banis;
  renderList();
  const q = new URLSearchParams(location.search);
  const key = q.get('bani');
  if (key && /^[a-z0-9_]{1,32}$/.test(key)) openBani(key, q.get('variant') || undefined);
});
boot();
($('#nitnemBack') as HTMLElement).addEventListener('click', backToList);
window.addEventListener('scroll', trackPosition, { passive: true });
const tglT = $('#tglT') as HTMLElement;
function syncTranslit() {
  const on = store.get('show_t', '1') !== '0';
  document.body.classList.toggle('hide-t', !on);
  tglT.setAttribute('aria-checked', on ? 'true' : 'false');
}
tglT.addEventListener('click', () => { store.set('show_t', store.get('show_t', '1') === '0' ? '1' : '0'); syncTranslit(); });
tglT.addEventListener('keydown', (e) => { if (e.key === 'Enter' || e.key === ' ') { e.preventDefault(); tglT.click(); } });
syncTranslit();
($('#fontMinus') as HTMLElement).addEventListener('click', () => bumpFont(-1));
($('#fontPlus') as HTMLElement).addEventListener('click', () => bumpFont(1));
function bumpFont(d: number) {
  const cur = parseInt(store.get('gsize', '22'), 10) || 22;
  store.set('gsize', String(Math.max(16, Math.min(40, cur + d * 2))));
  applyPrefs();
}
