---
phase: 245-branch-prune-local-and-remote
plan: 02
subsystem: repository-maintenance
tags: [git, origin, safety-refs, evidence, pull-requests]
requires:
  - phase: 245-01
    provides: report-first exact-ref operator and fail-closed origin/PR checks
  - phase: 244
    provides: verified completion and resolved ref-dependent dispositions
provides:
  - Immutable 72-ref local and 357-ref pre-prune origin snapshots pinned to commit f8b04c6a
  - Complete 13-PR baseline with captured pre- and post-safety identities
  - Exact origin publication and readback of the local-only archive safety tag
  - Full `mix ci` pass evidence before any production origin ref change
affects: [REPO-04, Phase 245 Plans 03–04]
actuals:
  tasks: 2
  commits: 9
tech-stack:
  added: []
  patterns:
    - Immutable inventory commit followed by a separate evidence pin
    - Exact absent-only safety tag publication guarded by complete PR and origin reads
key-files:
  created:
    - .planning/phases/245-branch-prune-local-and-remote/245-LOCAL-REFS.tsv
    - .planning/phases/245-branch-prune-local-and-remote/245-ORIGIN-REFS.tsv
    - .planning/phases/245-branch-prune-local-and-remote/245-SAFETY-PUBLISH.tsv
    - .planning/phases/245-branch-prune-local-and-remote/245-OPEN-PR-STATE.json
    - .planning/phases/245-branch-prune-local-and-remote/245-ORIGIN-ACCESS-PREFLIGHT.json
    - .planning/phases/245-branch-prune-local-and-remote/245-POST-SAFETY-ORIGIN-REFS.tsv
    - .planning/phases/245-branch-prune-local-and-remote/245-POST-SAFETY-OPEN-PR-STATE.json
  modified:
    - scripts/maintainers/prune-stale-branches.sh
    - scripts/maintainers/prune-stale-branches.test.sh
    - scripts/maintainers/prune-stale-branches.remote.test.sh
    - .planning/phases/245-branch-prune-local-and-remote/245-EVIDENCE.json
requirements-completed: []
coverage:
  - id: D1
    description: Complete committed local/origin inventories, current open PR state, and Phase 244 readiness are pinned before branch deletion.
    requirement: REPO-04
    verification:
      - kind: other
        ref: "prune-stale-branches.sh verify-snapshot --snapshot-commit f8b04c6a --origin-commit f8b04c6a --evidence-commit a2c22d6f --safety-commit f8b04c6a"
        status: pass
      - kind: other
        ref: "prune-stale-branches.sh verify-objects --snapshot-commit f8b04c6a --origin-commit f8b04c6a"
        status: pass
    human_judgment: false
  - id: D2
    description: Required safety refs keep exact origin identities, with the missing local archive tag published under a verified exact-ref preflight.
    requirement: REPO-04
    verification:
      - kind: other
        ref: .planning/phases/245-branch-prune-local-and-remote/245-ORIGIN-ACCESS-PREFLIGHT.json
        status: pass
      - kind: other
        ref: "prune-stale-branches.sh verify-safety --snapshot-commit f8b04c6a --origin-commit f8b04c6a --safety-commit f8b04c6a"
        status: pass
    human_judgment: false
metrics:
  duration: 37min
  completed: 2026-09-27
  status: complete
---

# Phase 245 Plan 02: Committed Ref Inventories and Safety Publication

**The complete pre-prune inventories and PR baseline are pinned, and the local-only archive safety tag is now present on origin at its exact identity.**

## Performance

- **Duration:** 37 minutes
- **Started:** 2026-09-27T18:28:38Z
- **Completed:** 2026-09-27T19:04:46Z
- **Tasks:** 2
- **Files created or modified:** 15

## Accomplishments

- Committed 72 local refs and 357 origin refs, including direct/peeled object identities and the origin `HEAD` symref, in snapshot commit `f8b04c6a3b0339fd6576dbaa9b84685ae526331e`. A separate evidence commit pins that snapshot.
- Captured all 13 open PRs, including head/base names and OIDs. The full set remained unchanged through the safety publication window.
- Recorded Phase 244 readiness: verification passed 29/29; PR #213 remains deferred with its measured-drift todo, the Phase 242 `mix ci` blocker is resolved, and PR #283 remains an open draft at its recorded Phase 244 disposition.
- Published only `refs/tags/archive/local-main-pre-235-recovery` at `f9e036d2a2b28bc63eac34d7d8ae9bbeab6cd972`. The exact-ref preflight confirmed authenticated repository identity, complete PR state, `permissions.push`, and a non-mutating dry run. Independent readback confirmed this was the sole addition to origin's 357-ref snapshot.
- Preserved the origin-only `refs/heads/ci/phase-235-16-source-complete` at `e932a2c84fd356b5a3fe561fb9c77925fa836b34`; no local counterpart existed to align. No `safety/local-main-before-release-cleanup-*` refs were present.
- `verify-snapshot`, `verify-objects`, and `verify-safety` passed. All 72 local and 357 original origin snapshot rows had readable direct/peeled objects; the two observed safety refs retained their exact identities.
- Ran `MIX_ENV=test HEX_HOME=/private/tmp/sigra-phase244-hex-cache mix ci` before the origin tag push. The workspace sandbox initially blocked two Phase 235 contract-test child processes (`sandbox-exec`, exit 71); the exact gate then passed with exit 0 outside that restriction. Both diagnostic and successful logs are committed.

## Task Commits

1. **Task 1: Capture and commit the complete ref and PR inventories** — `f8b04c6a` (inventory bundle), `5f15928f` (snapshot pin), `1833ea7d` (CI and pre-safety captures), `0874ed71` (pre-safety pin).
2. **Task 2: Preflight and publish the absent safety tag** — `5349bd42` (preflight receipt), `e119c97c` (preflight pin), `4b9af574` (publish/readback evidence), `a2c22d6f` (readback pin).

**Operator alignment fix:** `30c4a51d` separates the safety-publication TSV from the future branch-deletion allowlist, as required by Plan 02 and Plan 03.

## Decisions

- The safety publication list is a separate committed artifact from the branch-deletion allowlist; an empty safety list is valid, while an empty deletion allowlist is not executable.
- The archive ref remains a tag. It was published into the same full tag namespace without force, and the divergent origin CI identity remains untouched.
- Local project heads are `main` and the active Phase 244 execution branch; no local-head deletion is planned unless the committed census proves a separate stale candidate.

## Deviations from Plan

### Auto-fixed plan alignment

Plan 01's operator originally reused the deletion allowlist for safety publication rows. Before capturing live inventories, the helper and fixtures were corrected to consume a distinct `245-SAFETY-PUBLISH.tsv`; the full local and bare-origin fixture passed. Committed as `30c4a51d`.

### Gate environment repair

The required `mix ci` command failed twice inside the workspace sandbox because the Phase 235 contract tests invoke `sandbox-exec`. The full diagnostic log records both failing child processes. The same exact gate then passed outside the workspace restriction; no tests or evidence requirements were waived.

### GSD progress bookkeeping

`roadmap.update-plan-progress 245` reported that it could not locate a writable Phase 245 entry, despite the visible phase section and progress row. The existing plan checkboxes and progress row were updated to 2/4, and `STATE.md` plus `state.json` now point to the exact Wave 3 command.

## Issues Encountered

- First `capture-origin` invocation omitted its required `--output` and exited before any capture. The command was rerun with the committed artifact destination.
- The initial in-sandbox `mix ci` attempts exited 2 on the restricted `sandbox-exec` children. The authorized out-of-sandbox run passed with exit 0.
- The GSD roadmap progress updater skipped its write; the phase's existing roadmap row and machine-readable route were then aligned directly with the two completed plan summaries.

## Cleanup and Ref Changes

- Production origin ref change: one exact tag addition, independently read back at the committed OID. No branch deletion has occurred yet.
- Stashes were untouched. No `git gc`, `git reflog expire`, or `--prune=now` command ran.
- The initial inventory remains immutable at `f8b04c6a`; the post-safety origin inventory records 358 refs, exactly one more than the original capture.

## Next Phase Readiness

Plan 03 is ready. It will classify the entire captured branch set, commit the exact deletion allowlist, record a local-head no-op if the census still contains no eligible local heads, and run the local-side verification before Plan 04 considers remote branch deletion.

## User Setup Required

None - no external service configuration is required.

## Self-Check: PASSED

- Summary and all listed artifacts exist in the committed execution history.
- `verify-snapshot`, `verify-objects`, and `verify-safety` passed against the pinned inventory commit.
- The exact required `mix ci` gate passed before the origin safety tag publication.
- Origin gained only the exact committed archive tag; branch deletion remains for the next plans.

---
*Phase: 245-branch-prune-local-and-remote*
*Plan: 02*
*Completed: 2026-09-27*

## Follow-up Correction: Additional Required Safety Branch

A later exhaustive D-04 scan found that the initial summary's statement that no `safety/local-main-before-release-cleanup-*` refs were present was incomplete: the first inventory contained a stale local tracking ref at `04ae0ba753e4f0613df5b3f840955018742ffbb9`, while its exact origin branch was absent. The exact source OID was materialized as a local safety head, the full `mix ci` gate and exact-ref origin preflight passed, and `refs/heads/safety/local-main-before-release-cleanup-20260831` was published at that OID. Independent readback confirmed the expected one-ref origin delta and unchanged 13-PR identities. The initial 72-local/357-origin snapshot remains preserved as history; the expanded 73-local/359-origin state and its verifiers are recorded in `245-EVIDENCE.json`. No deletion occurred during this correction.
