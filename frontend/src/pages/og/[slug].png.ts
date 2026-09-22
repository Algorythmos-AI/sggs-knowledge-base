// og/[slug].png.ts — static endpoint rendering the Open Graph / Twitter card for each OG slug.
//
// 1200×630 PNG: warm-ink background, a gold ੴ (U+0A74) top-left, the page title in Source Serif 4,
// the "Gurbani Soul" wordmark, and a thin gold rule. Rendered with satori (HTML/CSS → SVG) then
// resvg (SVG → PNG) using the STATIC font instances in src/og/fonts (satori cannot parse variable
// fonts). Only the single ੴ glyph is Gurmukhi — satori has no Indic shaping, so no other Gurmukhi
// words appear here. Output is byte-deterministic across builds. Each PNG is well under 150 KB.
import type { APIRoute } from "astro";
import satori from "satori";
import { Resvg } from "@resvg/resvg-js";
import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import { ogSlugs } from "../../routes";
import theme from "../../theme";

// Read from the source tree relative to the build's working directory (the frontend/ dir): the
// endpoint is bundled into dist/.prerender/, so import.meta.url would not point at src/og/fonts.
const font = (name: string) => readFileSync(resolve(process.cwd(), "src/og/fonts", name));
const SERIF = font("SourceSerif4-og.ttf");
const SANT = font("SantLipi-og.ttf");

const INK = theme.dark.paper;        // #171412 warm ink
const GOLD = theme.light.accentFill; // #FFBC0D
const PAPER = theme.light.paper;     // #FBF7F0 (title ink on the dark card)

const TITLES: Record<string, string> = {
  "home": "A quiet, exact companion to Sri Guru Granth Sahib Ji",
  "knowledge-base": "Sri Guru Granth Sahib Ji — Knowledge Base",
};
const titleFor = (slug: string) => TITLES[slug] ?? TITLES["knowledge-base"];

export function getStaticPaths() {
  return ogSlugs().map((slug) => ({ params: { slug } }));
}

export const GET: APIRoute = async ({ params }) => {
  const slug = String(params.slug);
  const title = titleFor(slug);

  const svg = await satori(
    {
      type: "div",
      props: {
        style: {
          display: "flex", flexDirection: "column", justifyContent: "space-between",
          width: "100%", height: "100%", padding: "72px 84px",
          background: INK, color: PAPER, fontFamily: "Source Serif 4",
        },
        children: [
          {
            type: "div",
            props: {
              style: { display: "flex", fontFamily: "Sant Lipi", fontSize: 96, color: GOLD, lineHeight: 1 },
              children: "ੴ",
            },
          },
          {
            type: "div",
            props: {
              style: { display: "flex", fontSize: 58, fontWeight: 600, lineHeight: 1.15, maxWidth: 940 },
              children: title,
            },
          },
          {
            type: "div",
            props: {
              style: { display: "flex", flexDirection: "column" },
              children: [
                { type: "div", props: { style: { display: "flex", height: 3, width: 120, background: GOLD, marginBottom: 22 } } },
                { type: "div", props: { style: { display: "flex", fontSize: 30, color: GOLD, fontWeight: 600 }, children: "Gurbani Soul" } },
              ],
            },
          },
        ],
      },
    },
    {
      width: 1200, height: 630,
      fonts: [
        { name: "Source Serif 4", data: SERIF, weight: 600, style: "normal" },
        { name: "Sant Lipi", data: SANT, weight: 600, style: "normal" },
      ],
    },
  );

  const png = new Resvg(svg, { fitTo: { mode: "width", value: 1200 }, background: INK })
    .render()
    .asPng();
  // asPng() returns a Node Buffer; copy into a plain ArrayBuffer-backed Uint8Array (a BodyInit).
  const body = Uint8Array.from(png);

  return new Response(body, {
    headers: { "Content-Type": "image/png", "Cache-Control": "public, max-age=31536000, immutable" },
  });
};
