// rss.xml.ts — static endpoint emitting /rss.xml for the "Gurbani Soul — Learn" feed.
//
// Items are intentionally EMPTY for now (PR3 fills them with the Learn articles). Kept so the
// channel, its <link> and the autodiscovery target exist from PR1 on.
import type { APIRoute } from "astro";
import rss from "@astrojs/rss";
import { SITE_URL } from "../site";

export const GET: APIRoute = (context) =>
  rss({
    title: "Gurbani Soul — Learn",
    description:
      "Plain, sourced explanations of Sri Guru Granth Sahib Ji from Gurbani Soul — verbatim scripture, cited by Ang.",
    site: context.site ?? SITE_URL,
    items: [],
  });
