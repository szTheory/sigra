---
phase: 241-retire-v1-47-s-dishonest-debt-adopter-leakage-guard
plan: "07"
subsystem: ci-prohibitions
tags: [node-test, elixir-docs, scanner-parity, D-30]
requires:
  - phase: 237-clean-working-tree-green-pages-clean-lib-docs-surface
    provides: "Committed Python doc-attribute scanner that defines the R1 language"
  - phase: 241-retire-v1-47-s-dishonest-debt-adopter-leakage-guard/06
    provides: "Synchronous JavaScript R1 scanner and baseline"
provides:
  - "Exact D-30 JavaScript port of the Phase-237 doc-attribute state machine"
  - "Manifest-backed accepted and rejected fixture parity regression tests"
  - "Same-commit Python/JavaScript/R1 parity evidence"
affects: [SURF-04, scripts/ci/prohibitions]
tech-stack:
  added: []
  patterns:
    - "Use a committed TSV of independently measured Python totals for Node-only parity regressions."
    - "Keep Phase-237's uppercase-S grammar and boolean heredoc state literal in the JS port."
key-files:
  created:
    - test/fixtures/prohibitions/p18-doc-range-python-language.ex
    - test/fixtures/prohibitions/p18-doc-range-parity.tsv
    - .planning/phases/241-retire-v1-47-s-dishonest-debt-adopter-leakage-guard/241-07-EVIDENCE.md
  modified:
    - scripts/ci/prohibitions/_p18-lib.mjs
    - scripts/ci/prohibitions/p18-doc-range.test.mjs
key-decisions:
  - "D-30 accepts only plain and uppercase-~S quote forms; lowercase and generalized sigils remain outside the scanner language."
  - "Permanent CI parity is Node-only; Python remains a same-commit evidence oracle."
requirements-completed: [SURF-04]
actuals:
  tokens: 3142
  tasks: 2
  commits: 3
commits: 3
plan_head_before: dcf7e22f1fc84204052f2f0c3a89e689cc53f5d1
duration: 10min
completed: 2026-09-19
status: complete
coverage:
  - id: D1
    description: "The JavaScript R1 scanner reproduces the locked Phase-237 accepted and rejected doc-attribute language."
    requirement: SURF-04
    verification:
      - kind: unit
        ref: "scripts/ci/prohibitions/p18-doc-range.test.mjs (4/4)"
        status: pass
    human_judgment: false
  - id: D2
    description: "Python/JavaScript parity covers real lib/ plus all four committed fixture subjects, and all prohibition consumers remain green."
    requirement: SURF-04
    verification:
      - kind: integration
        ref: "241-07-EVIDENCE.md; node --test --test-reporter=tap scripts/ci/prohibitions/*.test.mjs (106/106)"
        status: pass
    human_judgment: false
---

# Phase 241 Plan 07: D-30 Scanner Parity Summary

**Replaced the broadened JavaScript string-sigil parser with the exact Phase-237 doc-attribute state machine, pinned its language boundary in a committed parity corpus, and proved parity across fixtures and the R1 baseline.**

## Performance

- **Duration:** 10 min
- **Started:** 2026-09-19T18:44:35Z
- **Completed:** 2026-09-19T18:55:01Z
- **Tasks:** 2/2
- **Files modified:** 5

## Accomplishments

- Restored the literal `start` / `oneline` / `in_block` Phase-237 grammar: plain and uppercase-`~S` quote forms only.
- Added a four-row machine-readable corpus that pins leak `1`, lowercase `0`, delimited `0`, and accepted-language `4` Python-measured totals.
- Bound real `lib/` to the existing R1 baseline without duplicating or changing it, and recorded `337/337/337` Python/JavaScript/R1 evidence.
- Mutation-proved the uppercase-only grammar boundary: widening it to lowercase made the `P18 D-30 PARITY` assertion fail before restoration.

## Task Commits

1. **Task 1: End-to-end D-30 parity — RED counterexample to exact bounded scanner**
   - `15b56c70` `test(241-07): add D-30 parity corpus`
   - `1fa86ff5` `feat(241-07): restore bounded doc-range scanner`
2. **Task 2: Capture full Python/JS corpus parity and gate all prohibitions**
   - `7765089b` `docs(241-07): record scanner parity evidence`

## Verification

- `mix format --check-formatted test/fixtures/prohibitions/p18-doc-range-python-language.ex` — passed.
- `node --test --test-reporter=tap scripts/ci/prohibitions/p18-doc-range.test.mjs` — 4 passed, 0 failed.
- Injected known-bad leak — exited nonzero with `P18 DIRTY SURFACE: doc-range planning artifact`.
- Python/JavaScript corpus sweep — `lib/` 337/337/R1=337; leak 1/1; lowercase 0/0; delimited 0/0; accepted-language 4/4.
- `node --test --test-reporter=tap scripts/ci/prohibitions/*.test.mjs` — 106 passed, 0 failed.

## TDD Gate Compliance

- **RED:** `15b56c70` introduced the parity corpus; its target test failed intentionally on `P18 D-30 PARITY` with lowercase `1≠0` and delimited `2≠0`. `tdd-red-evidence` returned `RED_EVIDENCE_OK`.
- **GREEN:** `1fa86ff5` replaced the generalized parser with the bounded state machine; the focused suite passed 4/4.
- **REFACTOR:** Not needed; the literal state-machine port is the minimal implementation.

## Decisions Made

- The scanner's semantic source of truth is the committed Phase-237 Python state machine, not the coincidental real-tree aggregate.
- The TSV records measured Python totals once; permanent Node tests neither invoke Python nor alter the R1 baseline.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Test-fixture encoding] Corrected the initial parity-manifest separator encoding.**

- **Found during:** Task 1 RED setup
- **Issue:** The first TSV write contained literal `\\t` characters, producing a manifest-header failure before scanner behavior could be tested.
- **Fix:** Rewrote the manifest with real tab delimiters, then reran and machine-validated the intended `P18 D-30 PARITY` RED.
- **Files modified:** `test/fixtures/prohibitions/p18-doc-range-parity.tsv`
- **Committed in:** `15b56c70`

**Impact:** No scope expansion; the correction made the planned behavioral RED valid.

## Known Stubs

None.

## Issues Encountered

- The shared checkout sandbox cannot create `.git/index.lock`; Git staging/commits were performed only after explicit authorization. The user-owned `.planning/config.json` and `.planning/state.json` edits were preserved and excluded from every commit.

## Next Phase Readiness

SURF-04 now has a bounded, fixture-complete D-30 parity contract. The planning config/state files were intentionally not updated because they were already user-owned dirty changes.

## Self-Check: PASSED

All five implementation/evidence artifacts exist and all three task commits (`15b56c70`,
`1fa86ff5`, and `7765089b`) resolve to commits in Git history.
