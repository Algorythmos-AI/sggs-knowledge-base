// The sidebar: one group per directory of docs/, pages ordered by their frontmatter `sidebar.order`.
// A directory listed here must exist and hold at least one published page (Starlight refuses an
// empty group). Starlight ≥ 0.39 shape: a group's `items` holds the autogenerate entry.
const dir = (label, directory, extra = {}) => ({ label, items: [{ autogenerate: { directory } }], ...extra });

export const SIDEBAR = [
  dir('Start here', 'onboarding'),
  dir('Architecture', 'architecture'),
  dir('Engineering handbook', 'engineering'),
  dir('Process & runbooks', 'process'),
  dir('Brand', 'brand'),
  dir('Decisions (ADRs)', 'adr', { collapsed: true }),
  {
    label: 'Reference',
    items: [
      { label: 'Glossary', slug: 'glossary' },
      { label: 'The website', slug: 'website' },
      { label: 'Reports & audit history', slug: 'reports' },
      { label: 'Risk register', slug: 'risk-register' },
    ],
  },
];
