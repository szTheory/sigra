---
created: 2026-09-15
source: v1.47 CI-EFFICIENCY milestone audit (re-audit at close)
severity: medium
requirements: [GATE-03, GATE-05]
audit_acknowledged: v1.47
resolves_phase: 241
---

# The skip manifest cites a three-way parity guard that does not exist

`.github/ci-skip-manifest.tsv:8,16` state that
`scripts/ci/prohibitions/honest-skip-parity.test.mjs` asserts
`manifest <-> ci.yml <-> MAINTAINING.md` parity and name it a CONSUMER of the file.

**That file does not exist.** `scripts/ci/prohibitions/` holds p01-p16 only (16 test files,
all 66 tests passing). The real enforcer is `p10-no-undocumented-demotion.test.mjs`, which
checks manifest <-> `ci.yml` **only** — the `MAINTAINING.md` leg is unenforced.
`231-RESEARCH.md:275` found this ("C-1 -- does not exist"); it was never fixed.

## The unenforced leg has already rotted, exactly as predicted
- `MAINTAINING.md:172-178` locates step `design_gallery_snapshots` "inside
  `example_playwright_smoke`" under the name "Run design gallery board snapshots (non-PR)".
  At HEAD it lives in `example_playwright_shard` as "Run design gallery behavior and
  snapshots" (`ci.yml:1297-1298`).
- `MAINTAINING.md:177,231` cite a step `Aggregate Playwright step outcomes` and its
  `for o in ...` outcome loop as the mechanism keeping a snapshot regression red.
  **That step does not exist in `ci.yml` at HEAD** (0 grep hits) — Phase 232 deleted it.

The *behaviour* is still correct (a failing shard step reds the shard, which reds the
aggregator), but the maintainer-facing explanation describes a deleted workflow.

## Fix
Either write `honest-skip-parity.test.mjs` (and let it fail until MAINTAINING.md is
updated), or delete the two claims from the manifest and fix `MAINTAINING.md:172-178,231`
to describe the shard topology. Do not leave the manifest asserting a fictional guard.
