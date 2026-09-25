---
title: "Risk Register"
description: "The top project risks, their owners and mitigations, as tracked on the delivery board."
sidebar:
  order: 3
---
# Risk Register

Maintained on the delivery board (`type/risk`); top items:

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| A rebuild changes something scriptural | low | critical | reconcile + golden + `verify_regroup` + `guard_scripture` + CODEOWNERS; rollback = restore backups |
| iOS bookmarks break on a data change | low | high | keep-last `comp_id` rule (no body comp changes); `SavedStoreLadderTests` |
| Org transfer breaks Vercel/Render/LFS | medium | high | [org-transfer runbook](process/runbooks/org-transfer.md); verify LFS + deploy-verify before deleting the old remote |
| macOS CI minutes exhausted | medium | medium | path-filter the iOS job; concurrency-cancel; nightly-only heavy jobs |
| Render free-tier cold starts on staging | high | low | uptime ping keeps it warm; deploy-verify retries |
| Apple Developer Program still pending | high | medium | TestFlight workflow dormant; simulator evidence as interim gate |
| Toolchain drift (python 3.12 vs 3.9 trap) | medium | medium | `make doctor`, `.python-version`, CI pins |
