---
created: 2026-07-04T00:00:00.000Z
status: pending
title: probes.ts still duplicates PROBE_IDS instead of importing eval-probe-ids.mjs (D-12 single-source fold, deferred)
area: testing
resolves_phase: 217
files:
  - test/example/priv/playwright/lib/eval/probes.ts
  - scripts/ci/lib/eval-probe-ids.mjs
source: Phase 216-08 Task 2 (D-12 fold) deferred + confirmed by 216 re-verification (D12-PROBE-IDS-DUP)
---

## What

`test/example/priv/playwright/lib/eval/probes.ts` still hard-codes its own
`PROBE_IDS` array instead of importing the single source of truth,
`scripts/ci/lib/eval-probe-ids.mjs`. 216-08 Task 2 intentionally deferred the fold
(a `// FOLLOW-UP(216)` marker was left in probes.ts) because the CJS/ESM interop with
the Playwright transform was judged risky to entangle with the board-scoping fix.

The IDs are **identical** at the current commit, so there is no live drift today —
this is a maintainability / single-source-of-truth cleanup, not a correctness bug.

## Why it matters

Two hand-maintained copies of the probe-id list can silently drift. The canonical
list already exists in `eval-probe-ids.mjs` (imported by the guards); probes.ts
should import it too so the emitter and the guards can never disagree.

## Suggested fix

- Import `PROBE_IDS` from `scripts/ci/lib/eval-probe-ids.mjs` in probes.ts, verifying
  the Playwright CJS/ESM transform resolves the module cleanly (the reason it was
  deferred). If it resolves, delete the local array and the FOLLOW-UP marker.
- If interop still fails, add a cheap self-test that asserts the two arrays are
  deep-equal so drift is caught at test time even while the duplication stands.
