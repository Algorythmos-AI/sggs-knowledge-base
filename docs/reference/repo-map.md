---
title: "Repository map"
description: "The three repositories — data, platform, app — and what every important path is for, one line each, as an expandable map with links into the code at the right ref."
sidebar:
  order: 3
---
# Repository map

Three repositories, one purpose each ([ADR-0007](../adr/0007-three-repositories.md)). Open a
folder to see what lives in it; every entry links to the file or directory on GitHub.

<!-- sggs:repo-map -->
On the rendered wiki this is an expandable map; on GitHub, the same map is
[`docs/reference/repo-map.json`](repo-map.json), one line per path, checked by
`tools/gen_repo_map.py --check` so that no listed path can go missing.

## How to read it

- **sggs-platform** is this repository: the API and the website, and the wiki you are reading.
- **sggs-data** owns the scripture: nothing here writes it; it arrives by pin.
- **gurbani-soul-ios** owns the app: it vendors this repository's contract at a release tag.

When a newcomer asks "what is this file?", the answer belongs in the map. Add the path with a
one-line purpose; the check refuses a path that does not exist.
