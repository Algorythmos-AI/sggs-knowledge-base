// @ts-check
// docs.gurbanisoul.com — the SGGS engineering + domain wiki. Starlight renders the Markdown that
// lives in ../docs (ADR-0003: the wiki is PR-reviewed Markdown in the repository; ADR-0012: this
// site renders it). Nothing is copied: the collection reads ../docs in place.
import { execSync } from 'node:child_process';
import { defineConfig } from 'astro/config';
import { unified } from '@astrojs/markdown-remark';
import starlight from '@astrojs/starlight';
import starlightOpenAPI, { openAPISidebarGroups } from 'starlight-openapi';
import { remarkStripTitleH1 } from './plugins/remark-strip-title-h1.mjs';
import { remarkRepoLinks } from './plugins/remark-repo-links.mjs';
import { remarkWidgets } from './plugins/remark-widgets.mjs';
import { remarkCodeExcerpt } from './plugins/remark-code-excerpt.mjs';
import { remarkMermaid } from './plugins/remark-mermaid.mjs';
import { remarkPosters } from './plugins/remark-posters.mjs';
import { SIDEBAR } from './sidebar.mjs';

// The commit this build documents: CI passes PUBLIC_DOCS_COMMIT; locally, git. Emitted as
// <meta name="sggs-docs-commit"> and checked by scripts/ci/docs_smoke.py after every deploy.
if (!process.env.PUBLIC_DOCS_COMMIT) {
  try { process.env.PUBLIC_DOCS_COMMIT = execSync('git rev-parse HEAD', { stdio: ['ignore', 'pipe', 'ignore'] }).toString().trim(); }
  catch { process.env.PUBLIC_DOCS_COMMIT = 'unknown'; }
}

export default defineConfig({
  site: 'https://docs.gurbanisoul.com',
  trailingSlash: 'always',
  build: { format: 'directory', assets: '_astro' },
  markdown: {
    // The unified (remark/rehype) processor: Astro 7's default is Sätteri, but Starlight supports
    // both, and these plugins (including the async Mermaid renderer) are unified plugins.
    // Order matters: links and widgets are rewritten before Starlight's own plugins see the tree;
    // Mermaid renders at the remark stage, before Expressive Code sees code blocks. Links in the
    // built HTML are validated afterwards by scripts/check-links.mjs.
    processor: unified({ remarkPlugins: [remarkStripTitleH1, remarkRepoLinks, remarkWidgets, remarkCodeExcerpt, remarkMermaid, remarkPosters] }),
  },
  integrations: [
    starlight({
      title: 'Sri Guru Granth Sahib Ji — Knowledge Base',
      description: 'The engineering and domain wiki of the SGGS Knowledge Base and the Gurbani Soul app: how the verbatim scripture corpus is built, proven, searched, verified, served and shipped.',
      favicon: '/favicon.svg',
      defaultLocale: 'root',
      locales: { root: { label: 'English', lang: 'en' } },
      social: [{ icon: 'github', label: 'GitHub', href: 'https://github.com/Algorythmos-AI/sggs-platform' }],
      lastUpdated: true,
      pagination: true,
      customCss: ['./src/styles/theme.css', './src/styles/widgets.css'],
      components: {
        Head: './src/components/Head.astro',
        EditLink: './src/components/EditLink.astro',
        Footer: './src/components/Footer.astro',
      },
      head: [
        { tag: 'meta', attrs: { name: 'sggs-docs-commit', content: process.env.PUBLIC_DOCS_COMMIT } },
      ],
      sidebar: [...SIDEBAR, ...openAPISidebarGroups],
      plugins: [
        starlightOpenAPI([
          {
            base: 'api/reference',
            label: 'API reference',
            schema: '../contract/openapi.json',
          },
        ]),
      ],
    }),
  ],
  vite: {
    server: {
      fs: { allow: ['..'] },
      // `astro dev` against a local API: cd webapp && python3 serve.py (port 7777)
      proxy: { '/api': { target: 'http://127.0.0.1:7777', changeOrigin: true } },
    },
  },
});
