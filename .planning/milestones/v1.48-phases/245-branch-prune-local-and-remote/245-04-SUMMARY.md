---
phase: 245-branch-prune-local-and-remote
plan: 04
subsystem: repository-maintenance
tags: [git, origin, branch-pruning, pull-requests, evidence]
requires:
  - phase: 245-03
    provides: committed exact-name remote allowlist and exhaustive ref classification
  - phase: 244
    provides: verified completion and resolved ref-dependent dispositions
provides:
  - Guarded deletion receipts for exactly two committed origin refs
  - Independent full-ref, safety-ref, local-ref, and object-readability proofs
  - Durable diagnostics for 11 pre-existing PR base-OID mismatches
affects: [REPO-04]
actuals:
  tokens: 6500
  tasks: 2
  commits: 6
tech-stack:
  added: []
  patterns:
    - Exact full-ref mutation with fresh PR and safety guards
    - Independent post-mutation ref and object readbacks
key-files:
  created:
    - .planning/phases/245-branch-prune-local-and-remote/245-VERIFICATION.md
    - .planning/phases/245-branch-prune-local-and-remote/245-04-SUMMARY.md
  modified:
    - .planning/phases/245-branch-prune-local-and-remote/245-OPEN-PR-STATE.json
    - .planning/phases/245-branch-prune-local-and-remote/245-EVIDENCE.json
    - .planning/phases/245-branch-prune-local-and-remote/245-ORIGIN-ACCESS-PREFLIGHT.json
    - .planning/STATE.md
    - .planning/ROADMAP.md
    - .planning/state.json
key-decisions:
  - "Delete only the two committed remote=yes rows after fresh PR, safety, push-permission, and exact-ref checks."
  - "Do not invoke an empty tracking pass: the committed matching tracking-row count is zero, and Plan 03 records that no-op decision."
  - "Keep REPO-04 open because the strict post-prune PR base-ref/OID proof fails for 11 open PRs."
patterns-established:
  - "Record successful ref readbacks and failed integrity proofs in machine-readable phase evidence."
requirements-completed: []
coverage:
  - id: D1
    description: "The two exact allowlisted origin refs were deleted and ref, safety, and object proofs passed."
    requirement: REPO-04
    verification:
      - kind: other
        ref: "prune-stale-branches.sh remote --apply; verify-remote; verify-local; verify-safety; verify-objects"
        status: pass
    human_judgment: false
  - id: D2
    description: "Every baseline PR remains open with its head/base identity intact at the recorded OIDs."
    requirement: REPO-04
    verification:
      - kind: other
        ref: "prune-stale-branches.sh verify-prs --pr-state-commit 9c0a6b818d2d58858b5db274cc1cf0a9803f69f5"
        status: fail
    human_judgment: false
duration: approximately 30 minutes
completed: 2026-09-27
status: halted
---

# Phase 245 Plan 04: Prune Reviewed Origin Branches and Preserve the PR Integrity Blocker

**Two exact allowlisted origin branches were deleted and all ref/object/safety readbacks passed; phase completion is halted by 11 pre-existing PR base-OID mismatches.**

## Performance

- **Duration:** Approximately 30 minutes
- **Started:** After the Wave 3 state update at 2026-09-27T20:07:44Z; exact start time was not captured
- **Completed:** 2026-09-27T20:52:56Z
- **Tasks:** 2 executed; Plan 04 halted at its PR base-OID gate
- **Files modified:** 8

## Accomplishments

- Deleted only refs/heads/brandbook-rail-accent-logo-system at 093a2a77b3ff13ea17a4cc2a2439a56ddf54c8cd and refs/heads/v1.37-auth-branding-admin-polish at b9cbb7a7b442f0d04b985c01c30a4a4db24a1d1f.
- Independently verified the complete origin ref set against the 359-ref baseline minus those two rows; all 357 expected refs and identities match.
- Verified the unchanged 73-ref local set, all 3 required safety refs, and all 73 local / 359 origin snapshot objects.
- Captured all 13 open PRs immediately before and after pruning. Their captured head/base fields remained identical; both historical main base OIDs remain readable ancestors of live origin/main.
- Recorded the exact base-ref mismatch instead of treating the failed proof as passed.

## Task Commits

1. **Task 1: Pin fresh PR state, preflight, and record guarded remote pruning** — 9c0a6b81, 326e10d7, d0b32356, 6e5d2306.
2. **Task 2: Record final verification and the unresolved PR base-OID gate** — included in the plan metadata commit.

## Files Created/Modified

- 245-OPEN-PR-STATE.json — complete pre- and post-prune PR captures.
- 245-ORIGIN-ACCESS-PREFLIGHT.json — passing exact-ref deletion access preflight.
- 245-EVIDENCE.json — exact deletion receipts, readbacks, and 11 PR base-OID mismatch rows.
- 245-VERIFICATION.md — phase-level evidence with REPO-04 left blocked.
- 245-04-SUMMARY.md — this halted Plan 04 summary.
- .planning/STATE.md, .planning/state.json, and .planning/ROADMAP.md — next action points to Phase 245 gap planning; the phase remains in progress.

## Decisions Made

- No local or tracking branch was deleted. The committed allowlist contains no matching local-tracking rows; the prior no-op decision was preserved.
- The pre-prune and post-prune PR captures both contain 13 identical records.
- REPO-04 remains unchecked because the plan requires each captured base OID to match its live origin ref.

## Deviations from Plan

### Tracking pass

No tracking mutation pass ran because the committed tracking allowlist contains zero matching rows. This preserves the explicit Plan 03 decision not to invoke an empty pass. The independent verify-local check passed.

### PR base identity

The post-prune verify-prs command failed at PR #275. It found 11 open PRs whose recorded main base OIDs differ from the live origin/main tip. The same mismatch exists in the committed Wave 3 PR capture, and the historical OID objects remain readable ancestors of live origin/main. No attempt was made to alter PRs or main; Plan 04 is halted pending resolution of the identity contract.

**Total deviations:** 1 intentional empty-tracking-pass skip; 1 planned verification gate failure recorded without waiver.
**Impact on plan:** Only the exact reviewed origin candidates were deleted. All other refs and objects remain proven intact; REPO-04 is not marked complete.

## Issues Encountered

- The first verify-allowlist invocation omitted --allowlist-commit and stopped before mutation. The corrected full-SHA invocation passed.
- verify-prs failed its exact base-ref/OID comparison for 11 open PRs. Their GitHub PR fields remained stable across the pre/post captures; the failure predates Wave 4.

## User Setup Required

None.

## Plan 245-08 evidence update

cleanup audit ID: 245-cleanup-history-628dba08-b187-468a-bf4d-ea64e234743e
cleanup truth status: unresolved
cleanup command-history coverage is unresolved: the audit contains 30 phase/family rows, all `unknown` (24 `missing`, 6 `partial`). Phases 236–243 have no committed direct command-history source; Phases 244–245 have only bounded command-output or operation records. Phase 245 has no completion boundary because it remains active. No milestone-wide absence statement is supported by this evidence.

PR identity audit ID: e897a9ea-3808-49bb-8751-1d32207e3424
PR integrity result ID: 885c9fd1-5e97-481f-a98b-2bdf9a2c362e
Identity audit source commit: adb15816b6ace5aca4392679b3d775c0158bbe47
Identity audit source blob: 4414693790b11c19b93c8d565ab55d2d6ebbe0e8
Baseline commit: 9c0a6b818d2d58858b5db274cc1cf0a9803f69f5
Baseline state blob: 913e4d0ab10cfa3b4fb42bd4d347d47f5832dc85
Baseline evidence blob: eb9f3fa848e41578bd6f6d03d375f66207bbc8e9
REPO-04 status: blocked
verify-prs exit status: 1
current open PR inventory complete: true (13 rows)
strict non-exception base checks: 2/2 passed

All 11 historical base-identity rows remain unresolved. Their captured PR base OIDs disagree with exact `main` refs from the GitHub API and `git ls-remote`; ancestry does not reconcile that mismatch. The captured PR inventory and detail remain complete, all 11 head refs corroborate, and non-exception baseline checks for PRs #224 and #283 pass. The readiness receipt, exact local/origin/safety ref operations, object reachability proof, and deterministic fixture evidence pass; REPO-04 remains blocked by the 11 unresolved base identities.

| PR | Captured base OID | Exact current `main` OID | Disposition | Unresolved reasons |
|---:|---|---|---|---|
| 219 | `f06137b2ac0e9b2094aa1250e3c036b41e997651` | `5a00b90d2314bc93f27aec4090b5928018743d1b` | unresolved | `current_base_github_ref_disagrees_with_pr`; `current_base_ls_remote_disagrees_with_pr` |
| 266 | `fed35a4a3725d217486f45a571421dbbf5721765` | `5a00b90d2314bc93f27aec4090b5928018743d1b` | unresolved | `current_base_github_ref_disagrees_with_pr`; `current_base_ls_remote_disagrees_with_pr` |
| 267 | `fed35a4a3725d217486f45a571421dbbf5721765` | `5a00b90d2314bc93f27aec4090b5928018743d1b` | unresolved | `current_base_github_ref_disagrees_with_pr`; `current_base_ls_remote_disagrees_with_pr` |
| 268 | `fed35a4a3725d217486f45a571421dbbf5721765` | `5a00b90d2314bc93f27aec4090b5928018743d1b` | unresolved | `current_base_github_ref_disagrees_with_pr`; `current_base_ls_remote_disagrees_with_pr` |
| 269 | `fed35a4a3725d217486f45a571421dbbf5721765` | `5a00b90d2314bc93f27aec4090b5928018743d1b` | unresolved | `current_base_github_ref_disagrees_with_pr`; `current_base_ls_remote_disagrees_with_pr` |
| 270 | `fed35a4a3725d217486f45a571421dbbf5721765` | `5a00b90d2314bc93f27aec4090b5928018743d1b` | unresolved | `current_base_github_ref_disagrees_with_pr`; `current_base_ls_remote_disagrees_with_pr` |
| 271 | `fed35a4a3725d217486f45a571421dbbf5721765` | `5a00b90d2314bc93f27aec4090b5928018743d1b` | unresolved | `current_base_github_ref_disagrees_with_pr`; `current_base_ls_remote_disagrees_with_pr` |
| 272 | `fed35a4a3725d217486f45a571421dbbf5721765` | `5a00b90d2314bc93f27aec4090b5928018743d1b` | unresolved | `current_base_github_ref_disagrees_with_pr`; `current_base_ls_remote_disagrees_with_pr` |
| 273 | `fed35a4a3725d217486f45a571421dbbf5721765` | `5a00b90d2314bc93f27aec4090b5928018743d1b` | unresolved | `current_base_github_ref_disagrees_with_pr`; `current_base_ls_remote_disagrees_with_pr` |
| 274 | `fed35a4a3725d217486f45a571421dbbf5721765` | `5a00b90d2314bc93f27aec4090b5928018743d1b` | unresolved | `current_base_github_ref_disagrees_with_pr`; `current_base_ls_remote_disagrees_with_pr` |
| 275 | `fed35a4a3725d217486f45a571421dbbf5721765` | `5a00b90d2314bc93f27aec4090b5928018743d1b` | unresolved | `current_base_github_ref_disagrees_with_pr`; `current_base_ls_remote_disagrees_with_pr` |

The detailed 30-row ledger, phase boundaries, source OIDs, content digests, uncovered pairs, and source gaps are in `245-MILESTONE-CLEANUP-AUDIT.json`.

## Next Phase Readiness

Phase 245 remains in progress. Plan 245-08 is the active gap-closure plan; do not repeat the already-completed `$gsd-plan-phase 245 --gaps` command. The plan records cleanup history as unresolved and keeps REPO-04 blocked until the 11 current PR base identities are corroborated.

---
*Phase: 245-branch-prune-local-and-remote*
*Completed: 2026-09-27*
