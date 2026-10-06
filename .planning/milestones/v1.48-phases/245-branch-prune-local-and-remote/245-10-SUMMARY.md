---
phase: 245-branch-prune-local-and-remote
plan: 10
subsystem: repository-maintenance
tags: [git, audit, ed25519, evidence-provenance]
requires:
  - phase: 245-08
    provides: committed cleanup-history ledger and unresolved evidence baseline
provides:
  - independently trusted recorder attestations for complete command-history transcripts
  - boundary timestamps checked against pinned Git committer metadata
  - schema-v2 cleanup audit preserving the current unknown evidence
affects: [phase-245-verification, cleanup-history-audit]
actuals:
  tokens: 11192
  tasks: 2
  commits: 1
tech-stack:
  added: []
  patterns: [Ed25519 trust registry, ordered signed command events, Git commit-bound UTC window]
key-files:
  created:
    - .planning/phases/245-branch-prune-local-and-remote/245-10-SUMMARY.md
  modified:
    - scripts/maintainers/validate-milestone-cleanup-audit.mjs
    - scripts/maintainers/validate-milestone-cleanup-audit.test.mjs
    - .planning/phases/245-branch-prune-local-and-remote/245-MILESTONE-CLEANUP-AUDIT.json
key-decisions:
  - "A recorder public key is trusted only through the separately provisioned GSD_HISTORY_TRUSTED_KEYS registry; transcript fields cannot introduce trust roots."
  - "Missing trust material leaves cleanup-history evidence unknown and the aggregate unresolved."
patterns-established:
  - "A complete history transcript signs its phase, pinned boundaries, contiguous event count, and ordered-event digest."
  - "Boundary committed_at values must equal the normalized UTC committer time of the pinned commit."
requirements-completed: []
coverage:
  - id: D1
    description: "The audit validator accepts complete-history absence only with an externally trusted signature over the exact ordered transcript and phase boundaries."
    requirement: REPO-04
    verification:
      - kind: unit
        ref: scripts/maintainers/validate-milestone-cleanup-audit.test.mjs#recorder attestation tests
        status: pass
    human_judgment: false
  - id: D2
    description: "Pinned phase-window timestamps are independently checked against Git committer times, while unavailable history remains unresolved."
    verification:
      - kind: unit
        ref: scripts/maintainers/validate-milestone-cleanup-audit.test.mjs#boundary timestamps must equal pinned Git committer timestamps
        status: pass
      - kind: other
        ref: node scripts/maintainers/validate-milestone-cleanup-audit.mjs validate .planning/phases/245-branch-prune-local-and-remote/245-MILESTONE-CLEANUP-AUDIT.json
        status: pass
    human_judgment: false
duration: 15min
completed: 2026-09-28
status: complete
---

# Phase 245 Plan 10: Independent History Attestations and Commit-Bound Windows

**Cleanup-history validation now verifies externally trusted Ed25519 recorder signatures and derives phase-window times from pinned Git commits without changing the 30 unknown rows.**

## Performance

- **Duration:** approximately 15 minutes
- **Started:** 2026-09-28T09:04:00Z (approximate)
- **Completed:** 2026-09-28T09:19:00Z
- **Tasks:** 2
- **Files modified:** 3, plus this summary

## Accomplishments

- Replaced self-attested completeness strings with a versioned Ed25519 recorder-attestation contract. The verifier checks the external registry fingerprint and trust-source identity, contiguous ordered events, event-chain digest, phase, and exact start/end identities.
- Added the `GSD_HISTORY_TRUSTED_KEYS` registry input. No production key was generated or installed; the ephemeral signing key exists only inside deterministic tests.
- Recomputed UTC committer timestamps from each pinned boundary commit before accepting its phase-window timestamp.
- Migrated the audit ledger to schema v2 while retaining all 30 unknown cleanup-history rows and the unresolved aggregate. The 11 unresolved PR base rows and Plan 04 halted disposition are unchanged.

## Task Commits

The tasks touch the same validator and fixture files; their changes were committed together atomically after both verification gates passed.

1. **Task 1: Require independently authenticated recorder completeness** - included in `cb2c6fc3`.
2. **Task 2: Verify phase-window times against pinned Git commits** - included in `cb2c6fc3`.

**Task commit:** `cb2c6fc3` (`fix(245-10): authenticate cleanup history and boundary times`).

## Files Created/Modified

- `scripts/maintainers/validate-milestone-cleanup-audit.mjs` - validates trusted recorder signatures, transcript event sequence/digest, and exact committed boundary timestamps.
- `scripts/maintainers/validate-milestone-cleanup-audit.test.mjs` - covers self-assertion, missing/unknown trust, tampering, incomplete sequences, valid test-only signatures, timestamp mismatch, and absent boundary behavior.
- `.planning/phases/245-branch-prune-local-and-remote/245-MILESTONE-CLEANUP-AUDIT.json` - schema v2 provenance policy; current evidence state remains unchanged.

## Decisions Made

- External trust roots are loaded from a separately supplied registry named by `GSD_HISTORY_TRUSTED_KEYS`; public keys embedded in transcripts are never consulted.
- Without qualifying independent recorder evidence, the validator preserves every current cleanup-history row as unknown.

## Deviations from Plan

- Tasks 1 and 2 shared the same production and test files, so the completed changes were kept in one atomic plan commit rather than split across commits. No implementation scope changed.

## Issues Encountered

- No independently trusted recorder key or complete full-window transcript is present in the checkout. This is the expected evidence boundary: all 30 rows remain unknown and the aggregate remains unresolved.

## Next Phase Readiness

- Plan 10 closes review findings CR-07 and CR-08. Phase 245 remains incomplete because the cleanup-history evidence is unresolved and all 11 PR base identity rows remain unresolved. Phase verification must preserve those blockers.

## Self-Check: PASSED

- The summary and three planned artifacts exist.
- Full validator tests passed (17/17, no skips).
- The committed-audit validator returned `valid: true`, `unknown_count: 30`, and `truth_status: unresolved`.

---
*Phase: 245-branch-prune-local-and-remote*
*Completed: 2026-09-28*
