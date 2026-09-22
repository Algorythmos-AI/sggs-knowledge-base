// content.config.ts — Astro content collections for the Learn section (PR3).
//
// One collection, `learn`, loaded from src/content/learn/*.mdx via the glob loader (Astro 7). The
// entry id is the filename without extension, which is the URL slug (/learn/<id>). The schema is
// the contract every article's frontmatter must satisfy — a build error here is preferable to a
// malformed article shipping. Scripture is NEVER in frontmatter: `quotes` is a list of line ids
// that scripts/gen_landing_verse.py resolves to verbatim Gurmukhi in generated/quotes.json.
import { defineCollection } from "astro:content";
import { z } from "astro:schema";
import { glob } from "astro/loaders";

const TAGS = [
  "hukamnama",
  "nitnem",
  "raag",
  "ang",
  "verification",
  "search",
  "privacy",
  "widgets",
] as const;

const learn = defineCollection({
  loader: glob({ pattern: "**/*.mdx", base: "./src/content/learn" }),
  schema: z.object({
    title: z.string().min(8).max(70),
    description: z.string().min(40).max(160),
    pubDate: z.coerce.date(),
    updatedDate: z.coerce.date().optional(),
    tags: z.array(z.enum(TAGS)).min(1),
    quotes: z.array(z.number().int().positive()).default([]),
    draft: z.boolean().default(false),
  }),
});

export const collections = { learn };
