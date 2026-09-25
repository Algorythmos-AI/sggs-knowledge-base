// Mermaid fences become inline SVG at build time (mermaid-isomorphic drives a headless Chromium):
// accessible <text>, indexed by search, no runtime JavaScript. Each diagram is drawn twice, from the
// light and the dark legs of docs/brand/tokens.json, and CSS shows the one that matches the reader's
// scheme (the other is display:none, so it is neither read aloud nor focusable; search indexes the
// light one only). GitHub keeps rendering the same fence with its own theme.
// A diagram that fails to render fails the build — never a silent code block.
//
// Runs at the remark stage, before Expressive Code sees any code block.
import { createMermaidRenderer } from 'mermaid-isomorphic';
import { chromium } from 'playwright';
import { visit } from 'unist-util-visit';
import { BRAND, BRAND_DARK, contrast } from './brand.mjs';

/** The Mermaid theme for one leg of the palette (P = BRAND or BRAND_DARK). */
export function mermaidConfig(P, { onColour = '#FFFFFF' } = {}) {
  const BRAND = P;
  return {
  startOnLoad: false,
  theme: 'base',
  fontFamily: 'ui-sans-serif, system-ui, -apple-system, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif',
  fontSize: 16,
  flowchart: { htmlLabels: false, useMaxWidth: false, padding: 12, nodeSpacing: 40, rankSpacing: 48, curve: 'basis' },
  sequence: { useMaxWidth: false, actorFontSize: 16, messageFontSize: 15, noteFontSize: 15 },
  gitGraph: { useMaxWidth: false },
  themeVariables: {
    background: 'transparent',
    primaryColor: BRAND.paperWarm,
    primaryTextColor: BRAND.ink,
    primaryBorderColor: BRAND.accent,
    secondaryColor: BRAND.canvas,
    secondaryTextColor: BRAND.ink,
    secondaryBorderColor: BRAND.kraft,
    tertiaryColor: BRAND.card,
    tertiaryTextColor: BRAND.ink,
    tertiaryBorderColor: BRAND.kraft,
    lineColor: BRAND.accentText,
    textColor: BRAND.ink,
    mainBkg: BRAND.paperWarm,
    nodeBorder: BRAND.accent,
    clusterBkg: BRAND.paper,
    clusterBorder: BRAND.kraft,
    titleColor: BRAND.ink,
    edgeLabelBackground: BRAND.card,
    noteBkgColor: BRAND.paper,
    noteTextColor: BRAND.ink,
    noteBorderColor: BRAND.kraft,
    actorBkg: BRAND.paperWarm,
    actorBorder: BRAND.accent,
    actorTextColor: BRAND.ink,
    signalColor: BRAND.accentText,
    signalTextColor: BRAND.ink,
    labelBoxBkgColor: BRAND.paper,
    labelBoxBorderColor: BRAND.kraft,
    activationBkgColor: BRAND.canvas,
    activationBorderColor: BRAND.accent,
    git0: BRAND.accent, git1: BRAND.info, git2: BRAND.positive, git3: BRAND.special, git4: BRAND.maroon,
    gitBranchLabel0: BRAND.onAccent, gitBranchLabel1: onColour, gitBranchLabel2: onColour, gitBranchLabel3: onColour, gitBranchLabel4: onColour,
    commitLabelColor: BRAND.ink, commitLabelBackground: BRAND.paper, tagLabelColor: BRAND.ink, tagLabelBackground: BRAND.paperWarm, tagLabelBorder: BRAND.accent,
  },
  };
}

export const MERMAID_CONFIG = mermaidConfig(BRAND);
// the dark legs are light colours on warm ink, so labels on them take the dark ink
export const MERMAID_CONFIG_DARK = mermaidConfig(BRAND_DARK, { onColour: BRAND.ink });

// Authors may colour a node with a palette hex in a classDef / style / linkStyle line (light legs,
// gated by tools/docs_check.py). The dark drawing swaps each light token for its dark twin — in those
// lines only, never in a label — and where a text colour would then lose contrast on its fill (ink on
// kraft, which is the same in both legs) it takes whichever ink reads better.
const LIGHT_TO_DARK = new Map(Object.keys(BRAND).map((k) => [BRAND[k].toUpperCase(), BRAND_DARK[k].toUpperCase()]));
const INKS = [BRAND.ink, BRAND_DARK.ink];
const full = (h) => (h.length === 4 ? '#' + [...h.slice(1)].map((c) => c + c).join('') : h).toUpperCase();

export function darkStyles(source) {
  return source.split('\n').map((line) => {
    if (!/^\s*(classDef|style|linkStyle)\b/.test(line)) return line;
    let out = line.replace(/#[0-9A-Fa-f]{6}\b|#[0-9A-Fa-f]{3}\b/g, (h) => LIGHT_TO_DARK.get(full(h)) ?? h);
    const fill = /fill:\s*(#[0-9A-Fa-f]{6})\b/i.exec(out)?.[1];
    const color = /(?<![-\w])color:\s*(#[0-9A-Fa-f]{6})\b/i.exec(out)?.[1];
    if (fill && color && contrast(color, fill) < 4.5) {
      const best = INKS.reduce((a, b) => (contrast(a, fill) >= contrast(b, fill) ? a : b));
      out = out.replace(/((?<![-\w])color:\s*)#[0-9A-Fa-f]{6}\b/i, `$1${best}`);
    }
    return out;
  }).join('\n');
}

// Mermaid writes geometry with up to 15 decimals; two are below a pixel at any zoom. Rounding the
// geometry attributes (never text) takes about a third off each drawing, and every diagram is drawn
// twice, so this keeps the heaviest page inside the HTML budget (scripts/check-budget.mjs).
const GEOMETRY = /(\s(?:d|points|transform|x|y|x1|x2|y1|y2|cx|cy|r|rx|ry|width|height|viewBox|style)=")([^"]*)(")/g;
export const roundGeometry = (svg) => svg.replace(GEOMETRY, (_, a, v, z) =>
  a + v.replace(/-?\d+\.\d{3,}/g, (n) => String(Math.round(parseFloat(n) * 100) / 100)) + z);

let renderer;

export function remarkMermaid() {
  return async (tree, file) => {
    const found = [];
    visit(tree, 'code', (node, index, parent) => {
      if (node.lang === 'mermaid') found.push({ node, index, parent });
    });
    if (!found.length) return;
    if (found.some(({ node }) => /%%\{\s*init/i.test(node.value))) {
      throw new Error(`${file.path}: Mermaid init directives are not allowed — the site theme is central`);
    }
    renderer ??= createMermaidRenderer({ browserType: chromium });
    const sources = found.map(({ node }) => node.value);
    // distinct id prefixes: both drawings live in the same page, and Mermaid scopes styles by id
    const [light, dark] = await Promise.all([
      renderer(sources, { mermaidConfig: MERMAID_CONFIG, prefix: 'mmd' }),
      renderer(sources.map(darkStyles), { mermaidConfig: MERMAID_CONFIG_DARK, prefix: 'mmdd' }),
    ]);
    // Mermaid emits width="100%" plus a max-width style, which shrinks a wide diagram to a
    // thumbnail. Give the SVG its drawn size instead: the figure scrolls sideways when needed.
    const sized = (v) => roundGeometry(v.svg)
      .replace(/<svg([^>]*)\swidth="100%"/, `<svg$1 width="${Math.round(v.width)}" height="${Math.round(v.height)}"`)
      .replace(/<svg([^>]*)\sstyle="max-width:[^"]*"/, '<svg$1');
    light.forEach((r, i) => {
      const { node, parent, index } = found[i];
      for (const res of [r, dark[i]]) {
        if (res.status === 'rejected') {
          throw new Error(`${file.path}: Mermaid diagram ${i + 1} failed to render: ${res.reason?.message ?? res.reason}\n${node.value}`);
        }
      }
      const { title, description, width } = r.value;
      const svg = `<div class="mmd mmd--light">${sized(r.value)}</div><div class="mmd mmd--dark" data-pagefind-ignore>${sized(dark[i].value)}</div>`;
      const caption = title ? `<figcaption>${escapeHtml(title)}</figcaption>` : '';
      // A diagram wider than a reading column keeps its drawn size and scrolls sideways (with a
      // hint); the rest scale to fit. Both stay legible; the lightbox (P2) shows any at full size.
      const wide = width > 1400;
      parent.children[index] = {
        type: 'html',
        value: `<figure class="diagram diagram--mermaid${wide ? ' diagram--wide' : ''}" data-diagram="mermaid"${description ? ` aria-description="${escapeHtml(description)}"` : ''}><div class="diagram__scroll" tabindex="0" role="region" aria-label="${escapeHtml(title ? `Diagram: ${title}` : 'Diagram')}">${svg}</div>${caption}${wide ? '<p class="diagram__hint">Wide diagram — scroll sideways to see all of it.</p>' : ''}</figure>`,
      };
    });
  };
}

const escapeHtml = (s) => String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
