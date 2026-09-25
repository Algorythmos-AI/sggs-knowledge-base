// One collection, read in place: the Markdown under ../docs (this repository's wiki, PR-reviewed,
// GitHub-renderable) plus the sibling repositories' docs installed at their pinned commits under
// .sources/ (tools/fetch_sibling_docs.py). plugins/paths.mjs holds the id mapping.
import { defineCollection, z } from 'astro:content';
import { glob } from 'astro/loaders';
import { docsSchema } from '@astrojs/starlight/schema';
import { idForRepoPath, loadSources } from '../plugins/paths.mjs';

const sources = loadSources();
const siblingPatterns = Object.entries(sources).flatMap(([name, s]: [string, any]) =>
  (s.include as string[]).map((p) => `docs-site/.sources/${name}/${p}`),
);

export const collections = {
  docs: defineCollection({
    loader: glob({
      base: '..',
      pattern: ['docs/**/*.md', '!docs/reports/archive/**', '!docs/design/**', ...siblingPatterns],
      generateId: ({ entry }) => idForRepoPath(entry, sources) ?? `__unpublished__/${entry}`,
    }),
    schema: docsSchema({
      extend: z.object({
        // "Last verified against <commit> on <date>" — required on process/engineering pages by tools/docs_check.py.
        verified: z.object({ commit: z.string().regex(/^[0-9a-f]{7,40}$/), date: z.string().regex(/^\d{4}-\d{2}-\d{2}$/) }).optional(),
      }),
    }),
  }),
};
