---
phase: 235-terminal-ratification-measured-not-read
plan: 17
subsystem: ci
tags: [github-actions, sigstore, source-complete-evidence, offline-verification, fast-01]

requires:
  - phase: 235-16
    provides: protected-main source-complete producer and seven-blob landing proof
provides:
  - one exactly correlated protected-main FAST-01 evidence dispatch
  - signed source-complete 52-run population with authoritative 469-second wall p50
  - network-denied provenance verification and independent source-page replay
affects: [235-18, fast-01, gate-05, terminal-ratification]

tech-stack:
  added: []
  patterns: [sealed preflight dispatch correlation, singleton pre-post projection, source-first offline replay]

key-files:
  created:
    - .planning/phases/235-terminal-ratification-measured-not-read/235-FAST-01-SOURCE-COMPLETE-REMEASUREMENT.json
    - .planning/phases/235-terminal-ratification-measured-not-read/235-FAST-01-SOURCE-COMPLETE-REMEASUREMENT.attestation.jsonl
    - .planning/phases/235-terminal-ratification-measured-not-read/235-FAST-01-SOURCE-COMPLETE-REMEASUREMENT-TRUSTED-ROOT.jsonl
  modified:
    - .planning/phases/235-terminal-ratification-measured-not-read/235-FAST-01-SOURCE-COMPLETE-DISPATCH-CORRELATION.json
    - scripts/ci/verify-fast-01-source-complete-attestation-offline.sh
    - test/sigra/planning/phase_235_fast_01_source_complete_contract_test.exs

key-decisions:
  - "The user selected authorize-once at Task 2, authorizing exactly one immediate protected-main dispatch from the unchanged sealed preflight."
  - "Retained the authenticated scripts/ci/ci-run-metrics.sh wall output as terminal authority and used raw signed pages only for an independent exact-agreement replay."
  - "Recorded the observed pass without reroll: 52 eligible rows, 469-second p50, and 1331-second maximum."

patterns-established:
  - "An irreversible dispatch follows a locally revalidated sealed receipt, then a single bounded post-projection is atomically correlated before any watcher starts."
  - "Evidence handoff retains subject, attestation bundle, trusted root, immutable pins, and a network-denied replay banner."

requirements-completed: []

coverage:
  - id: D1
    description: "The sole dispatch is bound to protected main by a durable singleton pre/post projection before the watcher."
    requirement: FAST-01
    verification:
      - kind: integration
        ref: "test/sigra/planning/phase_235_fast_01_source_complete_contract_test.exs#dispatched correlation"
        status: pass
      - kind: e2e
        ref: "GitHub Actions run 34350618761"
        status: pass
    human_judgment: false
  - id: D2
    description: "The signed source-complete population authenticates and independently reproduces the authoritative wall-mode n, p50, order, and strict verdict."
    requirement: FAST-01
    verification:
      - kind: integration
        ref: "scripts/ci/verify-fast-01-source-complete-attestation-offline.sh#source_complete_offline_attestation_verified"
        status: pass
      - kind: unit
        ref: "test/sigra/planning/phase_235_fast_01_source_complete_contract_test.exs#source replay"
        status: pass
    human_judgment: false
  - id: D3
    description: "Historical FAST evidence, completed GATE-05 proof, requirement state, and contributor topology remain unchanged."
    requirement: GATE-05
    verification:
      - kind: integration
        ref: "scripts/ci/verify-terminal-ratification-attestation-offline.sh#offline_attestation_verified"
        status: pass
      - kind: unit
        ref: "test/sigra/planning/phase_235_terminal_ratification_contract_test.exs"
        status: pass
    human_judgment: false

actuals:
  tokens: 42443
  tasks: 3
  commits: 5

duration: 10m 03s
completed: 2026-09-09
status: complete
---

# Phase 235 Plan 17: Source-Complete FAST-01 Measurement Summary

**Exactly one protected-main evidence run produced a signed, source-complete 52-run population whose authoritative wall p50 is 469 seconds and whose offline replay agrees exactly.**

## Performance

- **Duration:** 10m 03s
- **Started:** 2026-09-09T12:21:53Z
- **Completed:** 2026-09-09T12:31:56Z
- **Tasks:** 3
- **Files modified:** 6

## Accomplishments

- Dispatched workflow ID `326592557` exactly once as the first post-authorization GitHub request and selected only run `34350618761` from the one bounded post-dispatch projection.
- Atomically finalized and validated the dispatch correlation before the sole watcher, binding run URL `https://github.com/szTheory/sigra/actions/runs/34350618761` to protected SHA `158aca14b11de13cbc5ab2fdea1bff790cc7ab29`.
- Retained the exact subject, attestation bundle, and trusted root; network-denied verification authenticated repository, signer, main ref, workflow SHA, and subject digest.
- Independently replayed three signed source pages (`100`, `20`, `0` rows) through explicit exhaustion and reproduced all 52 eligible rows, stable order, 469-second p50, 1331-second maximum, and strict `pass` verdict.
- Preserved both historical FAST misses, the rejected derived-only candidate, GATE-05's 93-row proof, requirement records, and contributor topology unchanged.

## Measurement Handoff

| Fact | Retained value |
| --- | --- |
| Run | `34350618761` |
| URL | `https://github.com/szTheory/sigra/actions/runs/34350618761` |
| Conclusion | `success` |
| Protected SHA | `158aca14b11de13cbc5ab2fdea1bff790cc7ab29` |
| Capture endpoint | `2026-09-09T12:22:29Z` |
| Eligible PR runs | `52` |
| Authoritative mode | `wall` |
| p50 | `469 seconds` |
| Maximum | `1331 seconds` |
| Verdict | `pass` (`469 < 720`) |
| Median run | `33222894174` |
| Maximum run | `30855541236` |

Artifact SHA-256 digests:

- Correlation: `ae9fbdd978d930b7c621def4d840247a67cf315171c12ea4c9cb78ba51e3d723`
- Subject: `a5f4f6d5335755fcac14e9de8827f47f2b04ad3a143df4b6f283ebfc20853594`
- Attestation bundle: `b38b8269481b056d14551c6b264aba163479addb8ec67a73127709e50e290218`
- Trusted root: `65ca537f6ed8a47fd0e560c421baa1f6c1efb8b25fc200d8c5c02c0e92eb2b9c`

## Task Commits

1. **Task 1 RED — dispatch preflight contract:** `fd6f3160` (test)
2. **Task 1 GREEN — reversible sealed preflight:** `d24b6586` (feat)
3. **Task 3 RED — dispatch correlation contract:** `206f3f2d` (test)
4. **Task 3 RED — signed source replay contract:** `ce7079b8` (test)
5. **Task 3 GREEN — retained verified measurement:** `4d406ba3` (feat)

Task 2 was the blocking-human decision checkpoint. The user selected `authorize-once`; no code commit was appropriate for the decision itself.

## Verification

- Sole watcher: `gh run watch 34350618761 --repo szTheory/sigra --compact --interval 60 --exit-status` — success.
- Structured run summary fetched exactly once; capture job `102462714039` succeeded; no failed logs were fetched.
- `bash scripts/ci/ci-run-metrics.test.sh`: 11 passed, 0 failed.
- `bash scripts/ci/capture-fast-01-gap-closure.test.sh`: PASS.
- `bash scripts/ci/verify-fast-01-source-complete-attestation-offline.sh`: `source_complete_offline_attestation_verified`.
- `bash scripts/ci/verify-terminal-ratification-attestation-offline.sh`: `offline_attestation_verified`.
- Focused Phase 235 ExUnit contracts: 31 tests, 0 failures.

## Decisions Made

- Honored the explicit `authorize-once` response and issued no second dispatch under any condition.
- Preserved the sealed Task 1 preflight byte-for-value, adding only the finalized post-projection, singleton selection, cardinality, and dispatched status.
- Kept FAST-01 requirement reconciliation out of this plan. Plan 18 alone may consume this passing handoff and update closeout surfaces; GATE-05 remains Complete.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Aligned offline statistics replay with the authoritative instrument schema**
- **Found during:** Task 3 offline replay implementation.
- **Issue:** The Plan 16 verifier fixture compared replayed outcome counts using obsolete `pass`/`fail` fields, while the protected authoritative instrument emits `statistics.outcomes.success` and `statistics.outcomes.failure`.
- **Fix:** Replayed the same counts into the exact protected instrument schema before requiring full statistics equality.
- **Files modified:** `scripts/ci/verify-fast-01-source-complete-attestation-offline.sh`.
- **Verification:** Network-denied source-complete verifier passed against the signed subject, and the focused contracts passed 31 tests.
- **Committed in:** `4d406ba3`.

**Total deviations:** 1 auto-fixed bug.  
**Impact on plan:** The correction enforces exact agreement with the protected authority and does not alter the population, statistic, threshold, or verdict.

## Known Stubs

None. All Plan 16 fail-closed capture pins now contain the retained Plan 17 values.

## Issues Encountered

- The first combined verification command had a local filename typo (`.jsonjson`). The corrected deterministic command ran immediately and all required checks passed; no external operation was repeated.
- The repository's unrelated `.tool-versions` edit and untracked `.gsd/`, `.planning/milestone.lock`, and `.planning/state.json` remain untouched and uncommitted.

## User Setup Required

None.

## Next Phase Readiness

Plan 18 can consume the authenticated pass branch using the exact subject digest and retained `n=52`, `p50=469`, `verdict=pass` handoff. No requirement or closeout surface was changed by Plan 17.

## Self-Check: PASSED

All six planned artifacts exist, all five execution commits are present in git history, and the retained digests match the verifier and measurement handoff above.

---
*Phase: 235-terminal-ratification-measured-not-read*
*Completed: 2026-09-09*
