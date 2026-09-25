// Single source of truth for site-wide constants used across layouts and the landing page.
// Keep SITE_URL in step with astro.config.mjs `site` and the App Store Connect URLs.
export const SITE_URL = "https://gurbanisoul.com";
export const SUPPORT_EMAIL = "support@gurbanisoul.com";

// The App Store product page and Apple's numeric app id (the digits after `/id`). Both are real
// (App Store Connect assigned them to Gurbani Soul) and stay committed; the SmartBannerConsistency
// gate requires APP_STORE_URL to end with `/id` + APP_STORE_ID.
export const APP_STORE_URL = "https://apps.apple.com/app/id6812982384";
export const APP_STORE_ID = "6812982384";

// Whether the app is live on the App Store. A build-time switch, never hardcoded: it is true only
// when the build env sets PUBLIC_APP_STORE_LIVE=1 (Vercel project env, Production — set on launch
// day after Apple's page answers 200; docs/process/runbooks/deploy.md → "Launch-day App Store
// switch"). While false, every page shows "Coming soon" and emits no store link, no Smart App
// Banner and no JSON-LD installUrl. Every App Store render site keys on this constant (the
// AppStoreSwitch gate in webapp/tests/test_repo_gates.py enforces both rules).
export const APP_STORE_LIVE = import.meta.env.PUBLIC_APP_STORE_LIVE === "1";

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
