// Single source of truth for site-wide constants used across layouts and the landing page.
// Keep SITE_URL in step with astro.config.mjs `site` and the App Store Connect URLs.
export const SITE_URL = "https://gurbanisoul.com";
export const SUPPORT_EMAIL = "support@gurbanisoul.com";

// Empty until Apple assigns the App Store URL. When set, the landing swaps the
// "Coming soon" note for the official App Store badge (see docs/website/README.md).
export const APP_STORE_URL = "";

// Apple's numeric App Store id (the digits after `/id` in APP_STORE_URL). Empty until Apple
// assigns it. When set, <Seo> emits the Smart App Banner (`apple-itunes-app`). Keep in step with
// APP_STORE_URL — the SmartBannerConsistency gate requires APP_STORE_URL to end with `/id`+this.
export const APP_STORE_ID = "";

// Imagery shipped under src/assets/landing/, one entry per file (the imagery-credit gate in
// webapp/tests/test_repo_gates.py parses `who`, `url` and `file` from this literal — keep each
// field a plain double-quoted string). MarketingFooter renders the credits on every marketing page:
//   * entries WITHOUT a url are original artwork made for Gurbani Soul ("Artwork: …");
//   * entries WITH a url are Unsplash photographs, credited "{who} / Unsplash" linking to the
//     photographer's profile — `url` must be https://unsplash.com/@<handle> (bare host, never
//     images.unsplash.com: every photo is self-hosted through astro:assets). Each `who` must also
//     be listed in NOTICE.md → "Website imagery".
// The artwork entry stays first. The hero is an original artistic rendering commissioned for
// Gurbani Soul, so its maker is Algorythmos.
export type ImageCredit = {
  who: string;
  what: string;
  url?: string;
  file: string;
  source?: "Unsplash";
};
export const IMAGE_CREDITS: ImageCredit[] = [
  { who: "Algorythmos", what: "an artistic rendering of Sri Harmandir Sahib at sunset", file: "harmandir-sahib-sunset.jpg" },
  { who: "Salil", what: "Sri Harmandir Sahib at night", url: "https://unsplash.com/@salilkoli", file: "unsplash-salilkoli-harmandir-sahib-night.jpg", source: "Unsplash" },
  { who: "UnKknown Traveller", what: "Sri Harmandir Sahib by day", url: "https://unsplash.com/@kushlav", file: "unsplash-kushlav-harmandir-sahib-day.jpg", source: "Unsplash" },
  { who: "Aryan Nikhil", what: "Sri Harmandir Sahib reflected in the sarovar", url: "https://unsplash.com/@aryannikhil", file: "unsplash-aryannikhil-harmandir-sahib-reflection.jpg", source: "Unsplash" },
  { who: "Ravindra Sharma", what: "Sri Harmandir Sahib, golden at night", url: "https://unsplash.com/@ravindrasharma", file: "unsplash-ravindrasharma-harmandir-sahib-golden-night.jpg", source: "Unsplash" },
  { who: "Reubx", what: "Sri Harmandir Sahib across the sarovar", url: "https://unsplash.com/@reubx", file: "unsplash-reubx-harmandir-sahib-wide.jpg", source: "Unsplash" },
];
