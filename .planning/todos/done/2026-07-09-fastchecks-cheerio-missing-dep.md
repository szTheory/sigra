---
created: 2026-07-09T00:00:00.000Z
status: done
title: fast_checks red on branch — evidence-anchor-check / panel scripts need cheerio (not installed)
area: ci
files:
  - .github/workflows/ci.yml
  - scripts/ci/evidence-anchor-check.mjs
  - scripts/ci/lib/anchor.mjs
  - scripts/panel/excerpt.mjs
source: 2026-07-09 Phase 219 recapture run 29051223765 — fast_checks failed with "Error: Cannot find module 'cheerio'"
---

## What

The `Fast checks` CI job fails on the Phase 219 branch (and any branch carrying the
217/218 eval-infra wave) with:

```
Error: Cannot find module 'cheerio'
##[error]Process completed with exit code 1.
```

It fires from the `evidence-anchor-check.mjs` / panel-eval step inside fast_checks.
`fast_checks` is **green on origin/main** (which lacks the 218 eval wave), so this is a
**218-era regression**: the panel/evidence scripts (`scripts/panel/*.mjs`,
`scripts/ci/evidence-anchor-check.mjs`, `scripts/ci/lib/anchor.mjs`) import `cheerio`,
but the fast_checks job never installs it.

## Why it matters

`fast_checks` is a required `ci-gate` need. Until this is fixed, the Phase 219 branch
(and the eventual 219→main ship PR) will red `ci-gate` for a reason unrelated to
baseline recapture. It is **out of scope for Phase 219** (example-only recapture; touches
no eval infra), which is why it was deferred here.

## Fix options

1. Add a `cheerio` install to the fast_checks job (npm/npx) before the evidence-anchor /
   panel step runs — smallest surface.
2. Gate the evidence-anchor / panel step behind the same JUDGE-CI-01 "advisory/off-CI"
   posture the panel is supposed to have (CONTEXT: "LLM panel stays advisory/off-CI"), so
   it does not hard-fail fast_checks.
3. Vendor/pin cheerio into the repo's node toolchain if the check is meant to be a hard
   gate.

Decide 1 vs 2 based on whether evidence-anchor-check is intended as a hard merge gate or
advisory. Resolve before the 219→main ship.

## Resolution (Phase 220, D-10)

Fixed via option (4), not previously listed: relocate the existing runtime
`_require('cheerio')` call in `scripts/ci/evidence-anchor-check.mjs` to *after* the
no-bundles early-exit guard, instead of resolving it at module top. On a bundle-free
`fast_checks` checkout the script now exits 0 before ever touching cheerio; wherever
bundles exist, cheerio still resolves from the existing
`test/example/priv/playwright/node_modules` install and the deterministic
evidence-anchor gate stays fully armed and merge-blocking (D-09 preserved).

The npm-ci-reorder (option 1) and vendoring/root-package.json (option 3) alternatives
were rejected as fragile/positional and unnecessary supply-chain surface respectively
(D-10). No new dependency was added — see `220-01-SUMMARY.md`.
