// covers.ts — cover photographs for Learn article cards (Home "Learn" section, /learn index).
// Every file here lives in src/assets/landing/ and is credited in site.ts IMAGE_CREDITS + NOTICE.md
// (the imagery-credit gate enforces one credit per file). Kept out of site.ts on purpose: site.ts is
// imported by every layout and parsed by the credit gate.
import type { ImageMetadata } from 'astro';
import day from './assets/landing/unsplash-kushlav-harmandir-sahib-day.jpg';
import reflection from './assets/landing/unsplash-aryannikhil-harmandir-sahib-reflection.jpg';
import goldenNight from './assets/landing/unsplash-ravindrasharma-harmandir-sahib-golden-night.jpg';

export const LEARN_COVERS: Record<string, { src: ImageMetadata; alt: string }> = {
  'what-is-a-hukamnama': { src: day, alt: 'Sri Harmandir Sahib by day, across the sarovar' },
  'how-to-read-nitnem': { src: reflection, alt: 'Sri Harmandir Sahib reflected in the sarovar under a morning sky' },
  'the-31-raags-and-the-watches-of-the-day': { src: goldenNight, alt: 'Sri Harmandir Sahib glowing gold at night, reflected in the water' },
};
