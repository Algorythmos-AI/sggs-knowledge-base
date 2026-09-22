// routes.ts — the manifest of public marketing + Knowledge Base routes.
//
// Single source of truth for the sitemap (src/pages/sitemap.xml.ts) and for <Seo>'s default OG
// image (og slug → /og/<slug>.png). It must list EXACTLY the pages that build to HTML under
// webapp/static (the SitemapInvariants gate compares the sitemap's <loc> set to the built HTML
// route set), so keep it in step when a page is added or removed under src/pages/*.astro.
//
// `lastmod` is a FIXED ISO date (never Date.now()) so the built sitemap is byte-deterministic
// across builds — bump it deliberately when a route's content meaningfully changes.
export type ChangeFreq =
  | "always" | "hourly" | "daily" | "weekly" | "monthly" | "yearly" | "never";

export interface Route {
  path: string;        // root-relative, no trailing slash (except "/")
  lastmod: string;     // YYYY-MM-DD
  changefreq: ChangeFreq;
  priority: number;    // 0.0–1.0
  og: string;          // OG card slug → /og/<og>.png
}

const LASTMOD = "2026-09-22";

// Learn article slugs (src/content/learn/<slug>.mdx), newest-first for the index + teaser order.
// Kept here so the sitemap, the OG cards and the /learn index share one ordered list. Must list
// exactly the non-draft articles — the SitemapInvariants gate compares this to the built HTML.
export const LEARN_SLUGS: string[] = [
  "what-is-a-hukamnama",
  "how-to-read-nitnem",
  "the-31-raags-and-the-watches-of-the-day",
  "what-is-an-ang",
  "how-gurbani-soul-verifies-scripture",
  "search-by-first-letters",
  "offline-and-private-by-design",
  "widgets-and-live-activity",
];

const learnRoutes: Route[] = [
  { path: "/learn", lastmod: LASTMOD, changefreq: "weekly", priority: 0.7, og: "learn" },
  ...LEARN_SLUGS.map((slug): Route => ({
    path: `/learn/${slug}`,
    lastmod: LASTMOD,
    changefreq: "monthly",
    priority: 0.5,
    og: `learn-${slug}`,
  })),
];

export const routes: Route[] = [
  { path: "/",             lastmod: LASTMOD, changefreq: "weekly",  priority: 1.0, og: "home" },
  { path: "/search",       lastmod: LASTMOD, changefreq: "weekly",  priority: 0.9, og: "knowledge-base" },
  { path: "/reader",       lastmod: LASTMOD, changefreq: "weekly",  priority: 0.8, og: "knowledge-base" },
  { path: "/nitnem",       lastmod: LASTMOD, changefreq: "weekly",  priority: 0.7, og: "knowledge-base" },
  { path: "/browse",       lastmod: LASTMOD, changefreq: "monthly", priority: 0.6, og: "knowledge-base" },
  { path: "/themes",       lastmod: LASTMOD, changefreq: "monthly", priority: 0.6, og: "knowledge-base" },
  { path: "/lineage",      lastmod: LASTMOD, changefreq: "monthly", priority: 0.6, og: "knowledge-base" },
  { path: "/trail",        lastmod: LASTMOD, changefreq: "monthly", priority: 0.5, og: "knowledge-base" },
  { path: "/analytics",    lastmod: LASTMOD, changefreq: "monthly", priority: 0.6, og: "knowledge-base" },
  { path: "/constellation",lastmod: LASTMOD, changefreq: "monthly", priority: 0.5, og: "knowledge-base" },
  { path: "/raag-clock",   lastmod: LASTMOD, changefreq: "monthly", priority: 0.6, og: "knowledge-base" },
  { path: "/divergence",   lastmod: LASTMOD, changefreq: "monthly", priority: 0.4, og: "knowledge-base" },
  { path: "/privacy",      lastmod: LASTMOD, changefreq: "yearly",  priority: 0.4, og: "knowledge-base" },
  { path: "/support",      lastmod: LASTMOD, changefreq: "yearly",  priority: 0.4, og: "knowledge-base" },
  ...learnRoutes,
];

// The set of distinct OG card slugs the site needs (drives og/[slug].png getStaticPaths).
export const ogSlugs = (): string[] => [...new Set(routes.map((r) => r.og))];

// Normalise a URL pathname to a manifest path ("" or "/x/" → "/" or "/x").
export const normPath = (p: string): string => {
  const s = (p || "/").replace(/\/+$/, "");
  return s === "" ? "/" : s;
};

// OG slug for a given path (default "knowledge-base" when the path is not in the manifest).
export const ogForPath = (p: string): string => {
  const n = normPath(p);
  return routes.find((r) => r.path === n)?.og ?? "knowledge-base";
};
