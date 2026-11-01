---
phase: 245-branch-prune-local-and-remote
plan: 26
subsystem: infra
tags: [git, branch-pruning, readiness, coordinator, testing]
requires:
  - phase: 245-23
    provides: committed schema-2 readiness receipt with nine immutable evidence pins
  - phase: 245-25
    provides: immutable blocked operation result that exposed the public verifier path defect
provides:
  - public operator verification of the authoritative committed schema-2 receipt path
  - isolated tracking-apply and fail-closed regression coverage
  - read-only production readiness result and fresh-contract handoff
affects: [245, REPO-04]
actuals:
  tokens: 42612 # ceil(170446 realized diff characters / 4)
  tasks: 3
  commits: 11
plan_head_before: 9e53cc6483f36bdcee907c8d12ea68c0234b8e5b
tech-stack:
  added: []
  patterns:
    - exact committed receipt path is passed to the readiness helper
    - disposable bare-origin and strict local SSH fixtures exercise pinned Git
    - exact source bytes reach pinned Git through a private regular-file descriptor
key-files:
  created:
    - .planning/phases/245-branch-prune-local-and-remote/245-26-RED-EVIDENCE.json
    - .planning/phases/245-branch-prune-local-and-remote/245-26-RESULT.json
    - .planning/phases/245-branch-prune-local-and-remote/245-26-HANDOFF.json
    - .planning/phases/245-branch-prune-local-and-remote/245-26-TEST-GATE.json
    - .planning/phases/245-branch-prune-local-and-remote/245-26-RUNTIME-DIAGNOSTIC.json
    - .planning/phases/245-branch-prune-local-and-remote/245-26-TESTS.tap
  modified:
    - scripts/maintainers/prune-stale-branches.sh
    - scripts/maintainers/prune-stale-branches.operator-readiness.test.mjs
    - scripts/maintainers/prune-stale-branches-readiness.mjs
    - scripts/maintainers/prune-stale-branches-readiness.test.mjs
    - scripts/maintainers/prune-stale-branches.remote.test.sh
requirements-completed: []
coverage:
  - id: D1
    description: Public verify-readiness accepts the exact committed schema-2 receipt and rejects altered or missing evidence.
    verification:
      - kind: integration
        ref: scripts/maintainers/prune-stale-branches.operator-readiness.test.mjs#schema-2 operator read-only
        status: pass
      - kind: other
        ref: .planning/phases/245-branch-prune-local-and-remote/245-26-RESULT.json
        status: pass
    human_judgment: false
  - id: D2
    description: Disposable tracking apply preserves coordinator, exact-OID, PR protection, and object-readability gates.
    verification:
      - kind: integration
        ref: scripts/maintainers/prune-stale-branches.operator-readiness.test.mjs#tracking apply serializes a concurrent local tracking-ref update and blocks on the following PR gate
        status: pass
      - kind: integration
        ref: .planning/phases/245-branch-prune-local-and-remote/245-26-TEST-GATE.json
        status: pass
    human_judgment: false
  - id: D3
    description: Production readiness is verified read-only against the immutable Plan 23 artifact with unchanged local refs and stashes.
    verification:
      - kind: other
        ref: .planning/phases/245-branch-prune-local-and-remote/245-26-RESULT.json
        status: pass
      - kind: other
        ref: .planning/phases/245-branch-prune-local-and-remote/245-26-HANDOFF.json
        status: pass
    human_judgment: false
  - id: D4
    description: Large committed-source hashing is reliable without changing Git or artifact provenance semantics.
    verification:
      - kind: unit
        ref: scripts/maintainers/prune-stale-branches-readiness.test.mjs#schema 2 captures and verifies a large committed markdown source
        status: pass
      - kind: integration
        ref: .planning/phases/245-branch-prune-local-and-remote/245-26-TEST-GATE.json
        status: pass
    human_judgment: false
duration: 144min
completed: 2026-10-01
status: complete
---

# Phase 245 Plan 26: Public readiness gate repair and handoff

The public branch-prune operator now verifies the authoritative committed schema-2 receipt path, with disposable tracking coverage and read-only production proof.

## Performance

- Duration: 137 minutes.
- Started: 2026-10-01T16:40:01Z, the first durable RED capture.
- Completed: 2026-10-01T19:03:37Z.
- Tasks: 3 of 3.
- Files changed in committed Plan 26 diffs before this summary: 13.

## Accomplishments

- Captured the original public operator failure while direct verification passed. The public shell reported all three temporary-copy rejection codes, and durable RED evidence was committed before the operator repair.
- Fixed the shell seam to pass the validated repository-relative readiness path and exact receipt commit to the real helper. The private committed-byte extraction remains a separate integrity check.
- Added a named public readiness negative matrix and disposable tracking-apply coverage for complete bare-origin inventories, protected PR head/base, row ordering, absent or busy coordinator, exact-OID changes, and a local concurrent ref mutation while the coordinator lock is held.
- Verified the Plan 23 receipt with both the public operator and direct helper. All four required artifact pins and all nine nested source pins matched; Phase 244 remained complete in current HEAD, index, and worktree observations.
- Compared all 128 local ref identities and six stash entries before and after production verification. Both inventories were byte-identical. Plan 26 performed zero production prune, origin-ref, or PR-ref operations.
- Recorded a fresh handoff requiring new D-06 and D-07 evidence, live PR head/base and origin/safety inventories, direct and peeled object proof, coordinator verification, and exact-OID checks before any later live apply.

## TDD Gate Compliance

Task 1 followed RED then GREEN. The original RED fixture showed direct helper exit 0 and ready, while public verification exited 1 with readiness_artifact_path_outside_repository, readiness_artifact_missing_from_commit, and readiness_artifact_missing_from_worktree. The RED receipt is 245-26-RED-EVIDENCE.json. After repair, the exact named schema-2 operator read-only test passed.

The final prescribed command was:

    node --test --test-concurrency=1 scripts/maintainers/prune-stale-branches.operator-readiness.test.mjs scripts/maintainers/prune-stale-branches-readiness.test.mjs scripts/maintainers/prune-stale-branches.test.mjs

It passed 53 of 53 tests, with zero failures, cancellations, skips, or todos; exit 0 in 678082.821 ms (11 minutes 18 seconds), using Node 22.14.0 and pinned /usr/bin/git 2.50.1. The named gate also exited 0 with output “ok 1 - schema-2 operator read-only”. The added large-source test passed 1/1 in 4.38 seconds, and the concurrent tracking test passed 1/1 in 21.47 seconds. Interrupted runs caused by the hash-object pipe stall are recorded as diagnostics and are not counted as passing evidence.

## Task Commits

1. Task 1 RED and repair: 041d6ccf (original RED evidence), f1759509 (operator path repair), 7c83345c (byte-mismatch regression correction).
2. Task 2 fixture and matrix: b8d29761 (public readiness and tracking matrix), 09a4bae9 (coordinator-held local concurrency case), a483e0e9 (large committed-source regression).
3. Verification deviations and gate evidence: f1085e79 (offline remote harness compatible with pinned Git), 0739adfe (regular-file hash input repair), f12e0909 (full regression gate and runtime diagnostics).
4. Task 3 production evidence: 56423369 (read-only result and handoff), e027cb15 (canonical result/handoff field alignment).

The 11 task commits above are measured from plan_head_before 9e53cc6483f36bdcee907c8d12ea68c0234b8e5b. This summary is committed separately as plan metadata.

## Files Created and Modified

- scripts/maintainers/prune-stale-branches.sh: passes the validated repository-relative readiness path to the schema-2 helper.
- scripts/maintainers/prune-stale-branches.operator-readiness.test.mjs: public readiness failure matrix, disposable tracking apply, and FIFO-coordinated concurrent mutation test.
- scripts/maintainers/prune-stale-branches-readiness.mjs: hashes exact source bytes through a private regular-file descriptor after repeated synchronous pipe stalls.
- scripts/maintainers/prune-stale-branches-readiness.test.mjs: command timeout handling and large committed markdown capture/verify regression.
- scripts/maintainers/prune-stale-branches.remote.test.sh: strict offline SSH fixture transport and actual bare-origin race injection for the pinned Git invariant.
- 245-26-RESULT.json and 245-26-HANDOFF.json: full source/ref evidence and fresh-current-contract requirements.
- 245-26-TEST-GATE.json, 245-26-TESTS.tap, 245-26-REVIEW.md, and 245-26-RUNTIME-DIAGNOSTIC.json: reproducible final test, review, and runtime evidence.

## Decisions Made

- The committed repository-relative receipt remains authoritative; temporary bytes are used only as a separate hash input and cannot replace the artifact path.
- Plan 19’s one admitted local deletion is counted once. Plan 25 remains blocked with zero tracking-ref operations. Neither is replayed.
- REPO-04 remains open. The historical 11-row PR mismatch and 30-row cleanup audit remain unresolved; the historical baseline and independent full-window registry remain unknown. Plan 16 remains blocked by Plan 14.
- No live tracking continuation was issued. A later attempt must start from a fresh current-state contract.

## Deviations from Plan

### Auto-fixed Issues

1. Rule 3 - Blocking verification repair, found during full-suite execution. Repeated Git hash-object --stdin hangs left Node waiting for pipe EOF across Node 20.18.1, Node 22.14.0, and Node 24.19.0. The same 683,388 committed bytes passed through a regular-file stdin 1,000 of 1,000 times with the exact expected Git blob. Commit 0739adfe changes only the byte transport: a private temporary file is opened as stdin to the same pinned path-aware Git command, then closed and removed in finally. Provenance and readiness semantics are unchanged. The large-source regression and final 53-test suite passed under the original Node 22.14.0 runtime.

2. Rule 3 - Blocking test-harness repair, found while validating the pinned Git path. Existing remote tests intercepted URLs and races through PATH shims that the coordinator’s pinned /usr/bin/git bypasses. Commit f1085e79 moves the disposable transport to a strict local SSH fixture and injects races at the bare origin. The real public operator and pinned Git remain under test; the fixture performs no network access.

**Total deviations:** 2 auto-fixed (2 blocking verification/test-harness repairs).  
**Impact on plan:** Both fixes were limited to reproducible verification blockers. No production pruning scope was added.

## Issues Encountered

- The first full test attempts stalled inside Git hash-object while Node synchronously waited on subprocess output. These runs were interrupted after process-stack diagnosis and did not count as test evidence; the cross-runtime behavior and repair are recorded in the committed runtime diagnostic and follow-up todo.
- The default sandbox denied writes under .git, which the coordinator surfaced as a busy-or-stale admission gate. Scoped commits succeeded after requesting metadata-write escalation through the existing coordinator; hooks were not bypassed.
- The first RESULT/HANDOFF version lacked top-level fields required by the plan’s exact jq acceptance expression. Canonical fields were added, and the exact plan command plus both jq predicates then passed with exit 0.

## User Setup Required

None. No external service setup is required; all tracking fixtures use a disposable bare origin and stubbed GitHub responses.

## Next Phase Readiness

Plan 26 is complete, but Phase 245 remains active and REPO-04 remains open. Plan 16 is still blocked by Plan 14. Do not replay Plans 19, 21, 24, or 25. Any later live tracking action requires a new D-06 preflight and D-07 current contract. Root will refresh GSD readiness and route state before recording the next command; the roadmap has no Phase 246.

## Threat Flags

| Flag | File | Description |
|------|------|-------------|
| threat_flag: file_access | scripts/maintainers/prune-stale-branches-readiness.mjs | Uses a private 0600 temporary file as the hash-object input after a synchronous pipe stall; closes it and removes its temporary directory in a finally block. It carries source bytes only and never becomes the readiness artifact path. |

## Self-Check: PASSED

- SUMMARY, RESULT, HANDOFF, RED evidence, test gate, and runtime diagnostic files exist.
- All 11 measured Plan 26 commits resolve in Git history.
- The exact Task 3 public verification command and both plan jq predicates passed with exit 0.
- Added-diff stub scan found no TODO, FIXME, placeholder, coming soon, or not available patterns.
