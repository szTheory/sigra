---
phase: 241-retire-v1-47-s-dishonest-debt-adopter-leakage-guard
plan: "05"
subsystem: ci-prohibitions
tags: [node-test, fail-closed, allowlist, templates, supply-chain]
requires:
  - phase: 239-priv-templates-sweep-one-batched-re-bless
    provides: V3 vocabulary and pair-keyed SVG allowlist specification
provides:
  - Shared p18 V3 scanner with fail-closed controls
  - Literal planning-path and template-bookkeeping leakage guards
  - Committed fixtures and reachability evidence
affects: [241-06, fast_checks, Hex-tarball-surface]
tech-stack:
  added: []
  patterns: [node:test prohibition guards, pair-keyed allowlists, distinct instrument diagnostics]
key-files:
  created:
    - scripts/ci/prohibitions/_p18-lib.mjs
    - scripts/ci/prohibitions/p18-planning-paths.test.mjs
    - scripts/ci/prohibitions/p18-templates-bookkeeping.test.mjs
    - scripts/ci/prohibitions/p18-allowlist.tsv
  modified: []
key-decisions:
  - "D-23: planning paths use a literal .planning/ detector, not V3."
  - "D-26: the SVG coordinate false positive is allowlisted by (path, literal)."
  - "D-29 remains declined; V3 is ported verbatim without vocabulary widening."
requirements-completed: []
plan_head_before: 864f1f4aa4dd215c56c396b9f7df65a26223e6dd
commits: 3
actuals:
  tokens: 4704
  tasks: 3
  commits: 3
duration: 8m
completed: 2026-09-19
status: complete
coverage:
  - id: D1
    description: Literal planning-directory paths cannot enter tracked lib/ or priv/templates/ files.
    verification:
      - kind: unit
        ref: scripts/ci/prohibitions/p18-planning-paths.test.mjs
        status: pass
    human_judgment: false
  - id: D2
    description: V3 bookkeeping tokens in installer templates fail unless individually allowlisted.
    verification:
      - kind: unit
        ref: scripts/ci/prohibitions/p18-templates-bookkeeping.test.mjs
        status: pass
    human_judgment: false
  - id: D3
    description: Fixture reachability and instrument-failure diagnostics are reproducibly recorded.
    verification:
      - kind: integration
        ref: .planning/phases/241-retire-v1-47-s-dishonest-debt-adopter-leakage-guard/241-05-EVIDENCE.md
        status: pass
    human_judgment: false
---

# Phase 241 Plan 05: p18 First-Two Leakage Classes Summary

**Two offline, fail-closed p18 guards now prevent literal planning paths and V3 bookkeeping from leaking through the tracked source and template surfaces.**

## Performance

- **Duration:** 8m
- **Started:** 2026-09-19T15:24:00Z
- **Completed:** 2026-09-19T15:32:19Z
- **Tasks:** 3/3
- **Files modified:** 7

## Accomplishments

- Ported the committed Phase 239 V3 scanner and its fail-closed controls into a reusable Node helper.
- Added a literal `.planning/` guard over tracked `lib/` and `priv/templates/`, with a committed one-violation fixture.
- Added a wide-V3 templates guard, preserving the committed third-party SVG coordinate allowlist rather than narrowing the vocabulary.
- Recorded the full fixture-by-guard matrix, including the expected V3-superset cell and the load-bearing independent green cell.

## Task Commits

1. **Task 1: Port shared helper and planning-path hard-fail** — `bfde841a` (`feat`)
2. **Task 2: Add the templates bookkeeping hard-fail** — `8498df3a` (`feat`)
3. **Task 3: Record reachability and instrument controls** — `0c529dfc` (`test`)

## Files Created

- `scripts/ci/prohibitions/_p18-lib.mjs` — V3 scanning, real tier lists, pair-keyed allowlist validation, and named failure kinds.
- `scripts/ci/prohibitions/p18-planning-paths.test.mjs` — literal planning-directory property.
- `scripts/ci/prohibitions/p18-templates-bookkeeping.test.mjs` — V3 template property.
- `scripts/ci/prohibitions/p18-allowlist.tsv` — the committed third-party SVG coordinate disposition.
- `test/fixtures/prohibitions/p18-planning-path-leak.ex` — planning-path known-bad input.
- `test/fixtures/prohibitions/p18-template-bookkeeping.ex` — V3-token known-bad input.
- `241-05-EVIDENCE.md` — deterministic RED/GREEN, cross-product, and instrument-failure evidence.

## Decisions Made

- Kept D-23's planning-path detector literal; raw V3 matches in historical documentation are not this surface.
- Preserved D-26's allowlist key as `(path, literal)`, with non-vacuity and real-union checks so it cannot silently widen.
- Kept D-29's two proposed vocabulary widenings declined and out of scope; the helper copies V3 verbatim.
- Did not complete SURF-04. Plan 241-06 alone adds the third hard-fail class and all three ratchets, then closes the shared requirement.

## Verification

- `bash -c 'node --test --test-reporter=tap scripts/ci/prohibitions/*.test.mjs'` — passed, 99 tests.
- `bash -c 'mix test test/sigra/planning/phase_236_retry_wrapper_prohibition_test.exs'` — passed, 7 tests.
- `bash -c 'mix format --check-formatted'` — passed.
- The full fixture cross-product and each named instrument-failure probe are captured in `241-05-EVIDENCE.md`.
- `bash -c 'test -z "$(git diff --name-only 864f1f4a^ -- .github/workflows/ci.yml mix.exs)"'` — passed; neither constrained file changed.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Added an explicit injected file-list seam for the empty-input control**

- **Found during:** Task 3
- **Issue:** The helper had no deterministic way to execute the required empty-tier instrument check without mutating tracked files or relying on a renamed control.
- **Fix:** Allowed `scanBookkeeping()` callers to supply an explicit file list; normal guards still resolve only tracked tiers or the one injected subject.
- **Files modified:** `scripts/ci/prohibitions/_p18-lib.mjs`
- **Verification:** The recorded empty-list probe emits `P18 INSTRUMENT FAILURE: empty file list`.
- **Committed in:** `0c529dfc`

**Total deviations:** 1 auto-fixed (Rule 3).

## Known Stubs

None.

## Next Phase Readiness

Plan 241-06 can extend `_p18-lib.mjs` with the doc-range walker, add its third hard-fail class, and introduce the three independently ratcheted baselines. SURF-04 remains open until that work is complete.

## Self-Check: PASSED

All seven plan artifacts exist, all three task commits resolve from the local history, and the
created source/fixture files contain no tracked stub markers.
