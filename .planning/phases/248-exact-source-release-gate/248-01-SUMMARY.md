---
phase: 248-exact-source-release-gate
plan: 01
subsystem: infra
tags: [github-actions, release-please, ci-gate, provenance]
requires: []
provides:
  - "Release tag, Release Please SHA, and checked-out HEAD equality preflight before package setup"
  - "Exact-head ci-gate validation with structured run identity and timestamps"
affects: [release-automation, phase-248]
actuals:
  tokens: 5699
  tasks: 2
  commits: 2
plan_head_before: 17585574724ce5c9b256c18c8f1605de5865d3d4
plan_head_after: 8e96f56dfff52880f51d802900d791767cdacc34
commits: 2
tech-stack:
  added: []
  patterns: ["Fail-closed GitHub Actions provenance checks", "Hermetic Bash fixtures"]
key-files:
  created:
    - scripts/ci/release-exact-source.sh
    - scripts/ci/release-exact-source.test.sh
  modified:
    - .github/workflows/release-please.yml
    - scripts/ci/wait-for-ci-gate.sh
    - scripts/ci/wait-for-ci-gate.test.sh
key-decisions:
  - "Reject any returned workflow run whose headSha or required identity metadata does not match the requested release SHA."
  - "Keep existing ci-gate JSON keys and add exact run identity, head SHA, timestamps, and gate verdict for downstream receipts."
requirements-completed: [AUTO-01]
coverage:
  - id: D1
    description: "The package job verifies resolved tag commit, Release Please SHA, and checkout HEAD before package setup."
    requirement: AUTO-01
    verification:
      - kind: unit
        ref: "bash scripts/ci/release-exact-source.test.sh"
        status: pass
      - kind: other
        ref: "actionlint .github/workflows/release-please.yml"
        status: pass
    human_judgment: false
  - id: D2
    description: "The gate accepts only a successful ci-gate run on the requested release SHA and emits auditable run metadata."
    requirement: AUTO-01
    verification:
      - kind: unit
        ref: "bash scripts/ci/wait-for-ci-gate.test.sh (13 cases)"
        status: pass
      - kind: other
        ref: "actionlint .github/workflows/release-please.yml"
        status: pass
    human_judgment: false
duration: 18m
completed: 2026-10-08
status: complete
---

# Phase 248 Plan 01: Exact-Source Release Gate Summary

**The Release Please package job now asserts tag/SHA/HEAD identity before setup, and the ci-gate poller proves the successful run belongs to that same full SHA.**

## Performance

- **Duration:** Approximately 18 minutes
- **Started:** 2026-10-08
- **Completed:** 2026-10-08
- **Tasks:** 2
- **Files modified:** 5

## Accomplishments

- Added a hermetic annotated-tag fixture and a fail-closed helper that compares the resolved tag commit, Release Please source SHA, and checked-out HEAD.
- Invoked the identity helper immediately after tag checkout and before Beam or package setup.
- Required each returned CI run to include matching `headSha` plus run identity and timestamps; mismatches and missing metadata fail before `ci-gate` inspection.
- Preserved the existing JSON result keys while adding run ID, head SHA, created/updated timestamps, and `gate_verdict`; exposed the compact result as a `gate-ci-green` job output.
- Added regression coverage for the 120-attempt, 30-second interval, and 75-minute timeout budget.

## Task Commits

1. **Task 1: End-to-end exact-source release preflight** - `60dbf35949aadcf3624680521099cbc525a2a89a`
2. **Task 2: Bind ci-gate success to its run SHA and preserve the timeout ceiling** - `8e96f56dfff52880f51d802900d791767cdacc34`

## Files Created/Modified

- `scripts/ci/release-exact-source.sh` - validates full release tag/SHA/HEAD identity.
- `scripts/ci/release-exact-source.test.sh` - exercises matching and mismatched annotated-tag cases and workflow order.
- `.github/workflows/release-please.yml` - wires the source preflight and exports gate result metadata.
- `scripts/ci/wait-for-ci-gate.sh` - validates run head identity and emits structured run evidence.
- `scripts/ci/wait-for-ci-gate.test.sh` - covers run metadata, head mismatch, result fields, and polling ceilings.

## Decisions Made

- Kept existing result fields for compatibility and added distinct exact-run fields for downstream receipt consumers.
- Sent polling progress to stderr so `--format json` has a single machine-readable stdout line for the GitHub Actions output.

## Deviations from Plan

None. The output stream adjustment supports the planned compact job output without changing polling behavior.

## Verification

- `bash scripts/ci/release-exact-source.test.sh` — passed.
- `bash scripts/ci/wait-for-ci-gate.test.sh` — passed, 13 cases.
- `actionlint .github/workflows/release-please.yml` — passed.
- `git diff --check` on all Plan 01 implementation paths — passed.
- No live Actions run was started by Plan 01; exact-head live verification remains part of the release workflow.

## Next Phase Readiness

Plan 01 is complete. Continue with the remaining runnable plans in Phase 248 using `$gsd-execute-phase 248`; Plan 02 owns guarded Release Please PR auto-merge. No PR #224 merge, tag, or package publication was performed here.

---
*Phase: 248-exact-source-release-gate*
*Completed: 2026-10-08*

## Self-Check: PASSED

- Summary file exists at the required plan path.
- Both task commits are present in history: `60dbf35949aadcf3624680521099cbc525a2a89a` and `8e96f56dfff52880f51d802900d791767cdacc34`.
- The measured plan commit range is 2 commits from `17585574724ce5c9b256c18c8f1605de5865d3d4` through `8e96f56dfff52880f51d802900d791767cdacc34`.
