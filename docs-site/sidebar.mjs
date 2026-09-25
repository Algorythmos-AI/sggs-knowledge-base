// The sidebar: one group per directory of docs/, pages ordered by their frontmatter `sidebar.order`.
// A directory listed here must exist and hold at least one published page (Starlight refuses an
// empty group). Starlight ≥ 0.39 shape: a group's `items` holds the autogenerate entry.
const dir = (label, directory, extra = {}) => ({ label, items: [{ autogenerate: { directory } }], ...extra });

export const SIDEBAR = [
  dir('Start here', 'onboarding'),
  dir('Scripture 101', 'scripture'),
  {
    label: 'Learn & contribute',
    items: [dir('Learning paths', 'learning-paths'), dir('Exercises', 'exercises'), dir('Contributing to the wiki', 'contributing')],
  },
  dir('Architecture', 'architecture'),
  {
    label: 'Data & pipeline',
    items: [
      { label: 'Overview', slug: 'data' },
      { label: 'Anatomy of a line record', slug: 'data/line-record' },
      { label: 'Corpus pipeline and gates', slug: 'data/pipeline' },
      { label: 'The dataset pin', slug: 'data/dataset-pin' },
      { label: 'The editorial ledger', slug: 'data/editorial-ledger' },
      {
        // pinned from Algorythmos-AI/sggs-data (docs-site/sources.lock.json); canonical there
        label: 'From sggs-data (pinned)', collapsed: true,
        items: [
          dir('Architecture', 'data/architecture'),
          dir('Decisions', 'data/adr'),
          dir('Runbooks', 'data/process/runbooks'),
          { label: 'Answer protocol', slug: 'data/answer-protocol' },
        ],
      },
    ],
  },
  dir('Search & verification', 'search'),
  {
    label: 'API',
    items: [
      { label: 'The JSON API', slug: 'api' },
      { label: 'API routes', slug: 'api/routes' },
      { label: 'Contract and OpenAPI', slug: 'api/contract-and-openapi' },
      { label: 'Versioning and caching', slug: 'api/versioning-and-caching' },
    ],
  },
  {
    label: 'iOS app',
    items: [
      { label: 'The iOS app', slug: 'ios' },
      { label: 'How the app takes a release', slug: 'ios/how-the-app-takes-a-release' },
      { label: 'Contract and parity', slug: 'ios/contract-and-parity' },
      { label: 'Database pair and launch integrity', slug: 'ios/db-pair-and-launch-integrity' },
      { label: 'Nitnem for engineers', slug: 'ios/nitnem-for-engineers' },
      {
        // pinned from Algorythmos-AI/gurbani-soul-ios (docs-site/sources.lock.json); canonical there
        label: 'From gurbani-soul-ios (pinned)', collapsed: true,
        items: [
          dir('iOS', 'ios/ios'),
          dir('Decisions', 'ios/adr'),
          dir('Runbooks', 'ios/process/runbooks'),
          { label: 'Nitnem spec', slug: 'ios/nitnem/spec' },
          { label: 'Contributing', slug: 'ios/contributing' },
        ],
      },
    ],
  },
  dir('Engineering handbook', 'engineering'),
  dir('Process & runbooks', 'process'),
  dir('Brand', 'brand'),
  dir('Decisions (ADRs)', 'adr', { collapsed: true }),
  {
    label: 'Reference',
    items: [
      { label: 'Glossary', slug: 'glossary' },
      { label: 'Diagrams and posters', slug: 'diagrams' },
      { label: 'Repository map', slug: 'reference/repo-map' },
      { label: 'The contributors to the Granth', slug: 'reference/contributors' },
      { label: 'Releases', slug: 'reference/releases' },
      { label: 'The website', slug: 'website' },
      { label: 'Reports & audit history', slug: 'reports' },
      { label: 'Risk register', slug: 'risk-register' },
      { label: 'The archive', slug: 'archive' },
    ],
  },
];
