// Mermaid fences become inline SVG at build time (mermaid-isomorphic drives a headless Chromium):
// accessible <text>, indexed by search, no runtime JavaScript, one brand theme that reads on the
// warm-paper card in both colour schemes. GitHub keeps rendering the same fence with its own theme.
// A diagram that fails to render fails the build — never a silent code block.
//
// Runs at the remark stage, before Expressive Code sees any code block.
import { createMermaidRenderer } from 'mermaid-isomorphic';
import { chromium } from 'playwright';
import { visit } from 'unist-util-visit';
import { BRAND } from './brand.mjs';

export const MERMAID_CONFIG = {
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
    gitBranchLabel0: BRAND.ink, gitBranchLabel1: '#FFFFFF', gitBranchLabel2: '#FFFFFF', gitBranchLabel3: '#FFFFFF', gitBranchLabel4: '#FFFFFF',
    commitLabelColor: BRAND.ink, commitLabelBackground: BRAND.paper, tagLabelColor: BRAND.ink, tagLabelBackground: BRAND.paperWarm, tagLabelBorder: BRAND.accent,
  },
};

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
    const results = await renderer(found.map(({ node }) => node.value), { mermaidConfig: MERMAID_CONFIG, prefix: 'mmd' });
    results.forEach((r, i) => {
      const { node, parent, index } = found[i];
      if (r.status === 'rejected') {
        throw new Error(`${file.path}: Mermaid diagram ${i + 1} failed to render: ${r.reason?.message ?? r.reason}\n${node.value}`);
      }
      const { title, description, width, height } = r.value;
      // Mermaid emits width="100%" plus a max-width style, which shrinks a wide diagram to a
      // thumbnail. Give the SVG its drawn size instead: the figure scrolls sideways when needed.
      const svg = r.value.svg
        .replace(/<svg([^>]*)\swidth="100%"/, `<svg$1 width="${Math.round(width)}" height="${Math.round(height)}"`)
        .replace(/<svg([^>]*)\sstyle="max-width:[^"]*"/, '<svg$1');
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
