// The poster kit: one declarative spec -> one large SVG poster + its steps sidecar.
// Every poster shares this visual language (brand palette, Source Serif titles, node kinds,
// legend, version stamp, source-of-truth footer) and the walkthrough convention
// (<g id="step-NN" data-step> groups). The output is committed under docs/diagrams/posters/
// and checked for drift by scripts/build-posters.mjs --check; the spec is the thing you edit.
//
// Colours are CSS custom properties with brand fallbacks, so the file renders correctly as a plain
// <img> on GitHub and takes the dark theme when the site inlines it.
import { BRAND } from '../plugins/brand.mjs';

export const W = 1600;
const FONT_SERIF = '"Source Serif 4", Georgia, "Times New Roman", serif';
const FONT_SANS = 'ui-sans-serif, system-ui, -apple-system, "Segoe UI", Roboto, Arial, sans-serif';
const FONT_MONO = 'ui-monospace, "SF Mono", Menlo, Consolas, monospace';

const esc = (s) => String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');

// Node kinds and how they draw. Text is always ink on a light fill or white on a saturated one.
export const KINDS = {
  box:   { fill: 'var(--poster-paper-warm, #FDF6E3)', stroke: 'var(--poster-accent, #A87900)', text: 'var(--poster-ink, #201A12)', rx: 10, sw: 2 },
  store: { fill: 'var(--poster-kraft, #B69A81)', stroke: 'var(--poster-kraft, #B69A81)', text: '#201A12', rx: 24, sw: 2 },
  actor: { fill: 'var(--poster-maroon, #8A1538)', stroke: 'var(--poster-maroon, #8A1538)', text: '#FFFFFF', rx: 40, sw: 2 },
  gate:  { fill: 'var(--poster-negative, #B33528)', stroke: 'var(--poster-negative, #B33528)', text: '#FFFFFF', rx: 8, sw: 2 },
  pin:   { fill: 'var(--poster-canvas, #F2F2F7)', stroke: 'var(--poster-kraft, #B69A81)', text: 'var(--poster-ink, #201A12)', rx: 8, sw: 2, dash: '8 6' },
  ext:   { fill: 'var(--poster-canvas, #F2F2F7)', stroke: 'var(--poster-info, #2A63C9)', text: 'var(--poster-ink, #201A12)', rx: 10, sw: 2 },
  good:  { fill: 'var(--poster-positive, #27703F)', stroke: 'var(--poster-positive, #27703F)', text: '#FFFFFF', rx: 10, sw: 2 },
  note:  { fill: 'var(--poster-paper, #FBF7F0)', stroke: 'var(--poster-kraft, #B69A81)', text: 'var(--poster-ink, #201A12)', rx: 6, sw: 1.5 },
};

const KIND_LEGEND = {
  box: 'component in this project', store: 'data at rest', actor: 'a person', gate: 'gate: fails build or deploy',
  pin: 'pin: a reviewed lock file', ext: 'external system', good: 'proven, verified state', note: 'explanation',
};

function center(n) { return [n.x + n.w / 2, n.y + n.h / 2]; }

// Where a line from (cx,cy) towards (tx,ty) leaves the node's rectangle (with a small margin).
function boundary(n, tx, ty) {
  const [cx, cy] = center(n);
  const dx = tx - cx, dy = ty - cy;
  const hw = n.w / 2 + 6, hh = n.h / 2 + 6;
  if (dx === 0 && dy === 0) return [cx, cy];
  const sx = Math.abs(dx) > 0 ? hw / Math.abs(dx) : Infinity;
  const sy = Math.abs(dy) > 0 ? hh / Math.abs(dy) : Infinity;
  const s = Math.min(sx, sy);
  return [cx + dx * s, cy + dy * s];
}

function textBlock(x, y, lines, { size = 18, fill, weight = 500, family = FONT_SANS, anchor = 'middle', lineHeight = 1.3, mono = false } = {}) {
  const lh = size * lineHeight;
  const total = lines.length * lh;
  const y0 = y - total / 2 + lh * 0.78;
  return lines.map((ln, i) => {
    const m = typeof ln === 'object' ? ln : { text: ln };
    const f = m.mono || mono ? FONT_MONO : family;
    const sz = m.size ?? size;
    return `<text x="${x}" y="${(y0 + i * lh).toFixed(1)}" text-anchor="${anchor}" font-family='${f}' font-size="${sz}" font-weight="${m.weight ?? weight}" fill="${fill}">${esc(m.text)}</text>`;
  }).join('');
}

// Rough width of a text run in the poster fonts (sans ≈ 0.54 em per char, mono ≈ 0.62 em).
export function textWidth(text, size, mono = false) { return text.length * size * (mono ? 0.62 : 0.54); }

export const PROBLEMS = [];
function drawNode(n) {
  const k = KINDS[n.kind ?? 'box'];
  for (const ln of n.lines ?? [n.label]) {
    const m = typeof ln === 'object' ? ln : { text: ln };
    const size = m.size ?? n.size ?? 18;
    if (size < 16) PROBLEMS.push(`${n.id}: text size ${size} is under the 16px minimum ("${m.text}")`);
    const over = textWidth(m.text, size, m.mono || n.mono) - (n.w - 20);
    if (over > 0) PROBLEMS.push(`${n.id}: "${m.text}" is ~${Math.round(over)}px too wide for a ${n.w}px box at ${size}px — split the line or widen the box`);
  }
  const dash = k.dash ? ` stroke-dasharray="${k.dash}"` : '';
  const title = n.title ? `<title>${esc(n.title)}</title>` : '';
  const [cx, cy] = center(n);
  const lines = n.lines ?? [n.label];
  let shape = `<rect x="${n.x}" y="${n.y}" width="${n.w}" height="${n.h}" rx="${k.rx}" fill="${k.fill}" stroke="${k.stroke}" stroke-width="${k.sw}"${dash}/>`;
  if (n.kind === 'store') {
    shape += `<ellipse cx="${cx}" cy="${n.y + 10}" rx="${n.w / 2}" ry="10" fill="${k.fill}" stroke="${k.stroke}" stroke-width="${k.sw}"/>`;
  }
  const body = textBlock(cx, cy + (n.kind === 'store' ? 6 : 0), lines, { size: n.size ?? 18, fill: k.text, weight: n.weight ?? 500, mono: n.mono });
  // no links inside the SVG: it is role="img" and must not contain interactive content (axe: nested-interactive)
  if (n.href) PROBLEMS.push(`${n.id}: nodes cannot carry links (the poster is role="img"); put the link in the step's caption`);
  return title + shape + body;
}

function drawGroup(g) {
  return `<g class="pk-group"><rect x="${g.x}" y="${g.y}" width="${g.w}" height="${g.h}" rx="16" fill="var(--poster-paper, #FBF7F0)" stroke="var(--poster-kraft, #B69A81)" stroke-width="1.5" stroke-dasharray="10 8"/>` +
    `<text x="${g.x + 18}" y="${g.y + 30}" font-family='${FONT_SERIF}' font-size="22" font-weight="600" fill="var(--poster-ink, #201A12)">${esc(g.label)}</text></g>`;
}

function drawEdge(e, byId) {
  const a = byId[e.from], b = byId[e.to];
  if (!a || !b) throw new Error(`edge ${e.from}->${e.to}: unknown node`);
  const pts = [];
  const via = e.via ?? [];
  const firstTarget = via[0] ?? center(b);
  const lastSource = via[via.length - 1] ?? center(a);
  pts.push(boundary(a, ...firstTarget));
  pts.push(...via);
  pts.push(boundary(b, ...lastSource));
  const d = pts.map((p, i) => `${i ? 'L' : 'M'}${p[0].toFixed(1)} ${p[1].toFixed(1)}`).join(' ');
  const stroke = e.color ?? 'var(--poster-accent-text, #8A6100)';
  const dash = e.dashed ? ' stroke-dasharray="8 7"' : '';
  const marker = e.arrow === false ? '' : ' marker-end="url(#pk-arrow)"';
  let out = `<path d="${d}" fill="none" stroke="${stroke}" stroke-width="${e.width ?? 2.5}"${dash}${marker}/>`;
  if (e.label) {
    const mid = pts[Math.floor((pts.length - 1) / 2)], nxt = pts[Math.floor((pts.length - 1) / 2) + 1];
    const mx = (mid[0] + nxt[0]) / 2 + (e.dx ?? 0), my = (mid[1] + nxt[1]) / 2 + (e.dy ?? 0);
    const lines = Array.isArray(e.label) ? e.label : [e.label];
    const wpx = Math.max(...lines.map((l) => l.length)) * 8.6 + 20, hpx = lines.length * 20 + 8;
    out += `<rect x="${(mx - wpx / 2).toFixed(1)}" y="${(my - hpx / 2).toFixed(1)}" width="${wpx.toFixed(1)}" height="${hpx}" rx="6" fill="var(--poster-paper, #FBF7F0)" stroke="none"/>` +
      textBlock(mx, my, lines, { size: 16, fill: 'var(--poster-ink, #201A12)', weight: 500 });
  }
  return out;
}

export function buildPoster(spec) {
  const H = spec.height;
  const byId = Object.fromEntries((spec.nodes ?? []).map((n) => [n.id, n]));
  const steps = spec.steps ?? [];
  const stepIds = new Set(steps.map((s) => s.id));
  for (const n of spec.nodes ?? []) if (n.step && !stepIds.has(n.step)) throw new Error(`${spec.slug}: node ${n.id} names unknown ${n.step}`);
  for (const e of spec.edges ?? []) if (e.step && !stepIds.has(e.step)) throw new Error(`${spec.slug}: edge ${e.from}->${e.to} names unknown ${e.step}`);

  // frame (always visible): groups, then per-step groups in order, then unstepped elements
  const frame = (spec.groups ?? []).map(drawGroup).join('');
  const unstepped = [
    ...(spec.edges ?? []).filter((e) => !e.step).map((e) => drawEdge(e, byId)),
    ...(spec.nodes ?? []).filter((n) => !n.step).map(drawNode),
  ].join('');
  const stepGroups = steps.map((s) => {
    const inner = [
      ...(spec.edges ?? []).filter((e) => e.step === s.id).map((e) => drawEdge(e, byId)),
      ...(spec.nodes ?? []).filter((n) => n.step === s.id).map(drawNode),
    ].join('');
    return `<g id="${s.id}" data-step="${s.id}" class="pk-step">${inner}</g>`;
  }).join('');

  const legendKinds = spec.legend ?? [...new Set((spec.nodes ?? []).map((n) => n.kind ?? 'box'))];
  const legend = legendKinds.map((kind, i) => {
    const k = KINDS[kind];
    const gap = Math.min(255, Math.floor((W - 80) / legendKinds.length));   // seven kinds still fit the width
    const x = 40 + i * gap, y = H - 110;
    return `<rect x="${x}" y="${y}" width="26" height="18" rx="5" fill="${k.fill}" stroke="${k.stroke}" stroke-width="2"${k.dash ? ` stroke-dasharray="${k.dash}"` : ''}/>` +
      `<text x="${x + 34}" y="${y + 14}" font-family='${FONT_SANS}' font-size="16" fill="var(--poster-ink, #201A12)">${esc(KIND_LEGEND[kind])}</text>`;
  }).join('');

  const stamp = `v${spec.verified.version} · verified ${spec.verified.date} · ${spec.verified.commit.slice(0, 7)}`;
  // the footer wraps onto a second line when the sources are long (16px mono ≈ 150 chars per line)
  const footerLines = [];
  let cur = 'Source of truth:';
  for (const src of spec.sources) {
    const next = `${cur} ${src} ·`;
    if (next.length > 150) { footerLines.push(cur.replace(/ ·$/, '')); cur = `  ${src} ·`; } else cur = next;
  }
  footerLines.push(cur.replace(/ ·$/, ''));
  if (footerLines.length > 2) throw new Error(`${spec.slug}: too many source files for the footer`);
  const footer = footerLines.map((l, i) => `<text x="40" y="${H - 58 + i * 24}" font-family='${FONT_MONO}' font-size="16" fill="var(--poster-ink, #201A12)">${esc(l)}</text>`).join('');
  const desc = spec.description;
  if (!desc || desc.length < 40) throw new Error(`${spec.slug}: description must be at least 40 characters`);

  const svg = `<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" viewBox="0 0 ${W} ${H}" width="100%" role="img" aria-labelledby="pk-title-${spec.slug} pk-desc-${spec.slug}" class="poster-svg" data-poster="${spec.slug}">
<title id="pk-title-${spec.slug}">${esc(spec.title)}</title>
<desc id="pk-desc-${spec.slug}">${esc(desc)}</desc>
<defs>
  <marker id="pk-arrow" viewBox="0 0 12 12" refX="10" refY="6" markerWidth="9" markerHeight="9" orient="auto-start-reverse"><path d="M1 1 L11 6 L1 11 z" fill="var(--poster-accent-text, #8A6100)"/></marker>
</defs>
<style>
  .poster-svg { font-family: ${FONT_SANS}; }
  .pk-step.is-dim { opacity: 0.22; transition: opacity 240ms ease; }
  .pk-step.is-active rect, .pk-step.is-active ellipse { filter: drop-shadow(0 0 6px var(--poster-accent-fill, #FFBC0D)); }
  @media (prefers-reduced-motion: reduce) { .pk-step.is-dim { transition: none; } }
</style>
<rect x="0" y="0" width="${W}" height="${H}" rx="24" fill="var(--poster-paper, #FBF7F0)"/>
<text x="40" y="66" font-family='${FONT_SERIF}' font-size="40" font-weight="600" fill="var(--poster-ink, #201A12)">${esc(spec.number)} · ${esc(spec.title)}</text>
<text x="40" y="100" font-family='${FONT_SANS}' font-size="20" fill="var(--poster-ink, #201A12)">${esc(spec.subtitle)}</text>
<text x="${W - 40}" y="52" text-anchor="end" font-family='${FONT_MONO}' font-size="16" fill="var(--poster-accent-text, #8A6100)">${esc(stamp)}</text>
<text x="${W - 40}" y="78" text-anchor="end" font-family='${FONT_SANS}' font-size="16" fill="var(--poster-ink, #201A12)">Sri Guru Granth Sahib Ji — Knowledge Base · engineering wiki</text>
<line x1="40" y1="120" x2="${W - 40}" y2="120" stroke="var(--poster-kraft, #B69A81)" stroke-width="1"/>
${frame}
${unstepped}
${stepGroups}
<line x1="40" y1="${H - 130}" x2="${W - 40}" y2="${H - 130}" stroke="var(--poster-kraft, #B69A81)" stroke-width="1"/>
${legend}
${footer}
</svg>
`;
  const sidecar = steps.map(({ id, title, caption, link }) => ({ id, title, caption, ...(link ? { link } : {}) }));
  if (PROBLEMS.length) { const msg = `${spec.slug}:\n  ` + PROBLEMS.splice(0).join('\n  '); throw new Error(msg); }
  return { svg, steps: sidecar };
}
