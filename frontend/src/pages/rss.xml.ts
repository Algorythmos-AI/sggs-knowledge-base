// rss.xml.ts — static endpoint emitting /rss.xml for the "Gurbani Soul — Learn" feed.
//
// One <item> per non-draft Learn article, ordered newest-first (ties broken by the LEARN_SLUGS
// order so the feed is byte-deterministic across builds). Scripture never appears in the feed —
// only the article title, description and link.
import type { APIRoute } from "astro";
import rss from "@astrojs/rss";
import { getCollection } from "astro:content";
import { SITE_URL } from "../site";
import { LEARN_SLUGS } from "../routes";

export const GET: APIRoute = async (context) => {
  const order = new Map(LEARN_SLUGS.map((s, i) => [s, i]));
  const articles = (await getCollection("learn"))
    .filter((a) => !a.data.draft)
    .sort((a, b) => {
      const t = b.data.pubDate.getTime() - a.data.pubDate.getTime();
      return t !== 0 ? t : (order.get(a.id) ?? 0) - (order.get(b.id) ?? 0);
    });

  return rss({
    title: "Gurbani Soul — Learn",
    description:
      "Plain, sourced explanations of Sri Guru Granth Sahib Ji from Gurbani Soul — verbatim scripture, cited by Ang.",
    site: context.site ?? SITE_URL,
    items: articles.map((a) => ({
      title: a.data.title,
      description: a.data.description,
      pubDate: a.data.pubDate,
      link: `${SITE_URL}/learn/${a.id}`,
    })),
  });
};
