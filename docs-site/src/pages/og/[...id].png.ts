// og/[...id].png.ts — the Open Graph card for every wiki page, prerendered at build.
//
// 1200×630 PNG in the wiki's own style: warm-ink background, a gold ੴ (U+0A74), the page title in
// Source Serif 4, the section, and the wordmark. Rendered with satori (HTML/CSS → SVG) then resvg
// (SVG → PNG) from the STATIC font instances copied from frontend/src/og/fonts at build (satori
// cannot parse variable fonts, and has no Indic shaping — so the single ੴ glyph is the only
// Gurmukhi here; no other Gurmukhi words, and never a verse). Byte-deterministic across builds.
import type { APIRoute } from 'astro';
import satori from 'satori';
import { Resvg } from '@resvg/resvg-js';
import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { getCollection } from 'astro:content';

const font = (name: string) => readFileSync(resolve(process.cwd(), 'src/og/fonts', name));
const SERIF = font('SourceSerif4-og.ttf');
const SANT = font('SantLipi-og.ttf');
const INK = '#171412', GOLD = '#FFBC0D', PAPER = '#FBF7F0', KRAFT = '#B69A81';

const SECTION: Record<string, string> = {
  onboarding: 'Start here', scripture: 'Scripture 101', 'learning-paths': 'Learning paths', exercises: 'Exercises', contributing: 'Contributing to the wiki',
  architecture: 'Architecture', data: 'Data & pipeline', search: 'Search & verification', api: 'API', ios: 'iOS app', engineering: 'Engineering handbook',
  process: 'Process & runbooks', brand: 'Brand', adr: 'Decisions', reference: 'Reference', diagrams: 'Reference', website: 'Reference',
};

export async function getStaticPaths() {
  const docs = await getCollection('docs');
  return docs.map((d) => ({
    params: { id: d.id },
    props: { title: d.data.title, section: d.id === 'index' || d.id === '404' ? 'Engineering wiki' : (SECTION[d.id.split('/')[0]] ?? 'Reference') },
  }));
}

const el = (style: Record<string, unknown>, children?: unknown) => ({ type: 'div', props: { style: { display: 'flex', ...style }, children } });

export const GET: APIRoute = async ({ props }) => {
  const { title, section } = props as { title: string; section: string };
  const size = title.length > 70 ? 44 : title.length > 40 ? 52 : 60;
  const svg = await satori(
    el({ flexDirection: 'column', justifyContent: 'space-between', width: '100%', height: '100%', padding: '64px 84px', background: INK, color: PAPER, fontFamily: 'Source Serif 4' }, [
      el({ alignItems: 'center', gap: 28 }, [
        el({ fontFamily: 'Sant Lipi', fontSize: 84, color: GOLD, lineHeight: 1 }, 'ੴ'),
        el({ fontSize: 28, color: KRAFT, letterSpacing: 1 }, section),
      ]),
      el({ fontSize: size, fontWeight: 600, lineHeight: 1.15, maxWidth: 1000 }, title),
      el({ flexDirection: 'column', gap: 14 }, [
        el({ width: 160, height: 4, background: GOLD }),
        el({ fontSize: 30 }, 'Sri Guru Granth Sahib Ji — Knowledge Base'),
        el({ fontSize: 24, color: KRAFT }, 'docs.gurbanisoul.com · the engineering and domain wiki'),
      ]),
    ]) as any,
    { width: 1200, height: 630, fonts: [
      { name: 'Source Serif 4', data: SERIF, weight: 600, style: 'normal' },
      { name: 'Sant Lipi', data: SANT, weight: 400, style: 'normal' },
    ] },
  );
  const png = new Resvg(svg, { fitTo: { mode: 'width', value: 1200 } }).render().asPng();
  return new Response(new Uint8Array(png), { headers: { 'Content-Type': 'image/png', 'Cache-Control': 'public, max-age=31536000, immutable' } });
};
