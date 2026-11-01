---
phase: 249-publish-and-prove-sigra-1-6-0
plan: 07
subsystem: release-proof
tags: [github-actions, artifacts, hex, hexdocs, bash, security]
requires:
  - phase: 249-01
    provides: read-only public release proof and source-bound receipt contract
provides:
  - Exact live source-CI run identity checks and rendered-source redirect validation
  - Hermetic release artifact mismatch and hostile-input regression matrix
affects: [249-03, 249-05, 249-06, release-proof]
actuals:
  tokens: 7600
  tasks: 2
  commits: 4
tech-stack:
  added: []
  patterns: [exact identity joins, inert artifact parsing, allowlisted receipt projection]
key-files:
  created:
    - .planning/phases/249-publish-and-prove-sigra-1-6-0/249-07-TASK-1-RED.json
    - .planning/phases/249-publish-and-prove-sigra-1-6-0/249-07-TASK-2-RED.json
  modified:
    - scripts/ci/release-public-proof.sh
    - scripts/ci/release-public-proof.test.sh
key-decisions:
  - "A successful package-source CI join now validates the run object before validating its attempt and ci-gate job."
  - "The rendered source page may remain on the exact version tag or resolve to that tag's commit and path; any other destination blocks the receipt."
  - "The receipt schema stays unchanged; ZIP members must be regular files and artifact values remain data rather than executable shell input."
patterns-established:
  - "Fail closed on mismatched external identity fields with stable preflight blocker IDs."
  - "Accept only explicitly projected receipt fields; never include arbitrary artifact diagnostics."
requirements-completed: [REL-01, REL-02]
coverage:
  - id: D1
    description: Exact package-source CI and rendered source destinations are joined to the published release identity.
    requirement: REL-01
    verification:
      - kind: integration
        ref: bash scripts/ci/release-public-proof.test.sh (identity and destination matrix)
        status: pass
      - kind: integration
        ref: bash scripts/ci/release-receipt.test.sh
        status: pass
    human_judgment: false
  - id: D2
    description: Hostile artifact bytes cannot execute, leak diagnostics, or produce a receipt from a symlink member.
    requirement: REL-02
    verification:
      - kind: integration
        ref: bash scripts/ci/release-public-proof.test.sh (hostile archive and payload fixtures)
        status: pass
      - kind: other
        ref: gsd-tools check tdd-red-evidence for both Plan 07 task records
        status: pass
    human_judgment: false
duration: 17min
completed: 2026-10-09
status: complete
---

# Phase 249 Plan 07 Summary

**Release proof now rejects mismatched source-CI run objects, redirected source pages, and symlinked artifact members while preserving the existing receipt schema.**

## Performance

- **Duration:** 17 minutes
- **Started:** 2026-10-09T13:39:00Z
- **Completed:** 2026-10-09T13:56:00Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments

- Added exact run ID, workflow, head, status, conclusion, and attempt checks for the live package-source CI response before joining its attempt and `ci-gate` job.
- Verified the rendered source URL lands on the exact version-tag path or its resolved commit path; redirects to another tag, commit, path, or query-bearing URL block the proof.
- Expanded the hermetic matrix for release/artifact/tag/CI/Hex/HexDocs mismatches, malformed and duplicate archive data, path traversal, symlink members, credential-shaped keys, arbitrary diagnostics, and shell-like values.
- Preserved the release receipt schema and verified success projection remains an explicit allowlist.

## TDD Gate Compliance

- **Task 1 RED:** `249-07-TASK-1-RED.json` was classified `RED_EVIDENCE_OK`; the test demonstrated a mismatched live CI run ID and redirected source pages could still produce a receipt. **GREEN:** exact CI run-object and final source-destination checks were added.
- **Task 2 RED:** `249-07-TASK-2-RED.json` was classified `RED_EVIDENCE_OK`; a symlink whose target contained valid JSON produced a successful receipt. **GREEN:** archive metadata is inspected and non-regular members are blocked before JSON parsing.
- No additional refactor was needed. Both red records are durable and committed before their corresponding implementation commits.

## Task Commits

1. **Task 1 tests:** `119526d0e` — mismatch and source-destination fixtures plus RED evidence.
2. **Task 1 implementation:** `9622966d0` — verify live source-CI and rendered-source identity joins.
3. **Task 2 tests:** `50652b7b0` — hostile artifact fixtures plus RED evidence.
4. **Task 2 implementation:** `813123925` — reject symlinked release artifact members.

## Files Created/Modified

- `scripts/ci/release-public-proof.sh` — validates exact live CI run identity, allowed rendered-source destinations, and regular ZIP member type.
- `scripts/ci/release-public-proof.test.sh` — exercises 44 positive, mismatch, and hostile-input checks without live mutation.
- `249-07-TASK-1-RED.json`, `249-07-TASK-2-RED.json` — classifier-verified TDD evidence for both tasks.

## Decisions Made

- Kept the source identity contract narrow: the fetched page must remain on the exact tag/path or resolve to the exact source commit/path.
- Kept untrusted artifact diagnostics out of preflight and receipt outputs, using stable blocker IDs instead.
- Left the committed release receipt schema unchanged.

## Deviations from Plan

None. The current branch's Plan 01 helper and existing receipt suite supplied the implementation and test patterns because the new helper is not yet present on `origin/main`.

## Issues Encountered

The ZIP parser previously checked member names but not member types. A hermetic symlink fixture proved that `unzip -p` can yield valid JSON from a symlink target; the helper now rejects non-regular archive members.

## Verification

- `bash -n scripts/ci/release-public-proof.sh scripts/ci/release-public-proof.test.sh` — passed.
- `bash scripts/ci/release-public-proof.test.sh` — 44 passed, 0 failed.
- `bash scripts/ci/release-receipt.test.sh` — 15 passed, 0 failed.
- `git diff --check` on both scoped scripts — passed.

## Next Phase Readiness

Plan 249-07 is complete and Wave 2 is now complete (4/7 plans). Plan 249-03 is the next roadmap plan. Plan 249-05 still owns preservation proof for the 95 inherited dirty paths recorded by Plan 04; no clean-repository closeout is claimed here.

---
*Phase: 249-publish-and-prove-sigra-1-6-0*
*Completed: 2026-10-09*
