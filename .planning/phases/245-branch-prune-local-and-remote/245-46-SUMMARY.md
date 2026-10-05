---
phase: 245-branch-prune-local-and-remote
plan: 46
subsystem: git-maintenance
tags: [git, branch-pruning, disposable-fixtures, source-latency]
requires:
  - phase: 245-45
    provides: bounded small-fixture trace and zero-attempt blocked result
provides:
  - Production-cardinality disposable public tracking fixture with per-source timing spans
  - Machine-readable blocked diagnostic with zero production ref operations
affects: [phase-245, REPO-04, 245-47]
actuals:
  tokens: 7654
  tasks: 2
  commits: 2
plan_head_before: 05dbb27f9a347215bcd24d0c6bec11b418fdd7d9
plan_head_after: 3e1a24a99e82b172813ec9bccac6da78afb5044b
tech-stack:
  added: []
  patterns: [Disposable Git common directory, monotonic external-source spans, blocked admission by default]
key-files:
  created:
    - .planning/phases/245-branch-prune-local-and-remote/245-46-DIAGNOSTIC.json
    - .planning/phases/245-branch-prune-local-and-remote/245-46-SUMMARY.md
  modified:
    - scripts/maintainers/prune-stale-branches.operator-readiness.test.mjs
key-decisions:
  - "Synthetic source latency is measured, but Plan 44 has no production-stage trace linking it to the 600713 ms silence; keep live admission blocked."
  - "No deterministic operator defect was reproduced, so no production operator code was changed and REPO-04 remains open."
requirements-completed: []
coverage:
  - id: D1
    description: "A production-cardinality disposable public-path fixture records source spans and exact ref and object post-state across three scenarios."
    requirement: REPO-04
    verification:
      - kind: integration
        ref: "scripts/maintainers/prune-stale-branches.operator-readiness.test.mjs#production-scale tracking source latency"
        status: pass
    human_judgment: false
  - id: D2
    description: "The diagnostic keeps live admission blocked with zero production ref operations and the Plan 45 digest intact."
    requirement: REPO-04
    verification:
      - kind: unit
        ref: "245-46-DIAGNOSTIC.json jq plan acceptance gate and Plan 45 SHA-256 match"
        status: pass
    human_judgment: false
duration: 10min observed closeout after fixture completion
completed: 2026-10-05
status: complete
---

# Phase 245 Plan 46: Production-scale tracking-source diagnosis

**The disposable public tracking path passed exact deletion and interruption checks at production source cardinality, but the cause of Plan 44's silence remains unlocalized, so live admission stays blocked.**

## Performance

- **Recorded fixture artifact:** 2026-10-05T22:18:36Z, after the final focused fixture run.
- **Tasks:** 2 of 2.
- **Measured commits:** 2, from the persisted plan HEAD ledger.
- **Files changed:** 2 task artifacts.

## Accomplishments

- Exercised the actual public `tracking --apply` entry point in a disposable Git common directory with 155 local refs, 360 origin refs, 14 unique open PR heads, and 38 external-source spans.
- Proved the held REST page received one SIGINT and left fixture refs exact. Zero-latency and injected-delay runs deleted only the admitted fixture ref, preserved every origin ref, and kept the target commit readable.
- Recorded source-stage timings and the explicit missing production signal in `245-46-DIAGNOSTIC.json`. The diagnostic records zero production ref operations, unchanged production refs, the unchanged Plan 45 receipt digest, REPO-04 open, and `live_admission_permitted=false`.

## Task Commits

1. **Task 1: Reproduce the public path at production source cardinality** — `b5e2467d` (`test`).
2. **Task 2: Classify the silence and repair only a reproduced operator defect** — `3e1a24a9` (`docs`); no operator defect was reproduced, so no repair was made.

## Verification

- The focused named test completed before the diagnostic was written; its three scenarios assert exact fixture post-state and source spans before writing the artifact.
- The Plan 46 `jq` acceptance gate passed. The recorded Plan 45 SHA-256 matches the current receipt bytes: `78d227ea6ffc5cd16e9c3518623ef727bb8442501bcdac96a7c52f595e2761b0`.
- No production tracking command was launched for this plan. The fixture asserts the production ref inventory and Plan 45 bytes are unchanged before and after its scenarios.

## Decisions Made

- The 35 ms injected per-source delay produced 1,325.208 ms of aggregate measured source time. The zero-delay case measured 620.793 ms. Neither result links a specific production stage to Plan 44's 600,713 ms silence because that attempt recorded no production-stage spans.
- `status=blocked_unlocalized` and `live_admission_permitted=false` remain the exact Plan 47 gate. A synthetic delay alone grants no live operation.

## Deviations from Plan

None. The plan explicitly requires a blocked diagnostic when a deterministic operator defect cannot be proven.

## Known Stubs

None in the changed files. Fixture-only synthetic values are intentional test data and are not wired to a production UI or data path.

## Next Phase Readiness

Plan 47's ready-diagnostic dependency is unmet. Phase 245 and REPO-04 remain open. The 11-row PR-base and 30-row cleanup-history audits are separate unresolved work.

## Self-Check: PASSED

The summary and diagnostic exist. Both task commits exist, and the persisted plan ledger measures exactly two task commits. The acceptance gate and Plan 45 digest match passed.

---
*Phase: 245-branch-prune-local-and-remote*
*Completed: 2026-10-05*
