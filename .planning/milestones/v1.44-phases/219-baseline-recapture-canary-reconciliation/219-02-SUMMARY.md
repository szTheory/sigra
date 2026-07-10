---
phase: 219-baseline-recapture-canary-reconciliation
plan: 02
subsystem: ci
tags: [ci, github-actions, playwright, snapshot-canary, recapture]

# Dependency graph
requires:
  - phase: 219-01
    provides: "example icon/1 :global attr + {@rest} spread — compile-warnings-as-errors gate cleared, unblocking every downstream recapture/smoke job"
provides:
  - "ci.yml workflow_dispatch input recapture_branch (D-04) — branch-scoped, non-tag amd64 recapture dispatch"
  - "release_ref_guard recapture-only relaxation (exits 0 on non-empty recapture_branch, unchanged tag requirement otherwise)"
  - "gh pr create --base retargeted to RECAPTURE_BASE (dispatched branch, fallback main) in both recapture jobs"
  - "demo-showcase (4 PNGs) recapture step folded into admin_checkpoint_recapture"
  - "impersonation-banner delete-rebirth + self-gated snapshot-canary-guard commit step in admin_checkpoint_recapture"
  - "canary-never-allowlistable assertion in scripts/ci/snapshot-canary-guard.sh (D-06)"
affects: [219-03, 219-04, 219-05, admin-checkpoint-recapture, admin-design-recapture]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Delete-then-recapture canary rebirth pattern (already used for board-notice) extended to impersonation-banner so a changed canary is born 'added' (guard-tolerated), not 'modified' (guard-forbidden)."
    - "workflow_dispatch string input consumed as a narrow, single-condition guard relaxation (non-empty input only) rather than a broad bypass — keeps the release-evidence tag requirement intact for every other dispatch."

key-files:
  created: []
  modified:
    - .github/workflows/ci.yml
    - scripts/ci/snapshot-canary-guard.sh

key-decisions:
  - "D-04 implementation: single new workflow_dispatch string input `recapture_branch` (default empty); release_ref_guard checks it BEFORE the refs/tags/v* case and exits 0 only when non-empty — recapture-only relaxation, not a general bypass."
  - "Retargeted gh pr create --base in both recapture jobs via a RECAPTURE_BASE env var sourced from github.event.inputs.recapture_branch, falling back to main when empty."
  - "D-03.1: folded demo-showcase recapture into admin_checkpoint_recapture (cheapest — job already boots the example on :4000) rather than adding a third job. No canary/allowlist choreography since demo-showcase has neither."
  - "D-03.2: mirrored the design job's board-notice delete-rebirth pattern for impersonation-banner, then converted the checkpoint commit step from human-visual-review-only to a self-gated snapshot-canary-guard.sh run with per-slug --allow flags (D-05 zero-human posture)."
  - "D-06: canary-never-allowlistable assertion placed immediately after the ALLOWED map is fully populated (committed manifest + --allow flags), before CHANGED_SLUGS collection — fails unconditionally if the canary is present, independent of whether it changed this run."
  - "Did not widen either recapture job's permissions: block and did not add either job to ci-gate.needs — both stay one-time, non-PR-gated utilities per the plan's explicit constraint."

patterns-established:
  - "A canary's delete-rebirth step is now duplicated across both recapture jobs (board-notice in admin_design_recapture, impersonation-banner in admin_checkpoint_recapture) with identical structure — a future third canary lane should follow the same 3-step shape (delete → --update-snapshots → guard with --allow list)."

requirements-completed: [RECAP-01]

coverage:
  - id: D-04
    description: "recapture_branch workflow_dispatch input exists and narrows release_ref_guard without touching the tag-path requirement for other dispatches"
    requirement: RECAP-01
    verification:
      - kind: other
        ref: "python3 -c \"import yaml; d=yaml.safe_load(open('.github/workflows/ci.yml')); assert 'recapture_branch' in d[True]['workflow_dispatch']['inputs']\""
        status: pass
    human_judgment: false
  - id: D-03
    description: "demo-showcase recapture step + impersonation-banner delete-rebirth + self-gated commit step + corrected 84/28 comments"
    requirement: RECAP-01
    verification:
      - kind: other
        ref: "grep -c 'demo-showcase.spec.ts --project=demo-showcase-chromium --update-snapshots' .github/workflows/ci.yml; grep -c \"impersonation-banner-admin-checkpoints-\\*.png' -delete\" .github/workflows/ci.yml"
        status: pass
    human_judgment: false
  - id: D-06
    description: "snapshot-canary-guard.sh rejects a canary present in the allowlist or passed via --allow"
    requirement: RECAP-01
    verification:
      - kind: other
        ref: "bash scripts/ci/snapshot-canary-guard.sh --base HEAD --canary board-notice --allow board-notice --allowlist /dev/null (expect non-zero exit)"
        status: pass
    human_judgment: false

# Metrics
duration: 4min
completed: 2026-07-09
status: complete
---

# Phase 219 Plan 02: CI Recapture-Trigger Surgery + Gap Closure + Canary Hardening Summary

**Added a branch-scoped `recapture_branch` workflow_dispatch input that narrows `release_ref_guard` (D-04), closed the three recapture-mechanism gaps — demo-showcase recapture, `impersonation-banner` delete-rebirth, stale PNG-count comments (D-03) — and made the canary provably never-allowlistable in `snapshot-canary-guard.sh` (D-06), so the existing ubuntu/amd64 recapture jobs can now run branch-scoped before merge and produce a complete, self-gated recapture.**

## Performance

- **Duration:** ~4 min
- **Started:** 2026-07-09T20:23:49Z
- **Completed:** 2026-07-09T20:27:50Z
- **Tasks:** 3
- **Files modified:** 2

## Accomplishments

- `on.workflow_dispatch.inputs.recapture_branch` (string, default `''`) added alongside the existing `force_fail_probe` input.
- `release_ref_guard` now exits 0 immediately when `github.event.inputs.recapture_branch` is non-empty, before evaluating the `refs/tags/v*` requirement — the tag requirement is otherwise byte-unchanged for every other manual dispatch.
- Both `admin_design_recapture` and `admin_checkpoint_recapture`'s `gh pr create --base` now resolve to `${RECAPTURE_BASE:-main}`, sourced from `github.event.inputs.recapture_branch` — recaptured PNGs will PR into the dispatched branch instead of always targeting `main`.
- `admin_checkpoint_recapture` gained a `demo-showcase.spec.ts --project=demo-showcase-chromium --update-snapshots` step and now `git add`s the demo-showcase snapshots directory alongside the checkpoint snapshots directory in its commit step — the 4 demo-showcase PNGs now have an in-CI recapture path (previously none).
- `admin_checkpoint_recapture` gained an `impersonation-banner-admin-checkpoints-*.png -delete` step (mirroring the design job's `board-notice` pattern) immediately before `--update-snapshots`, so the canary re-appears as `added` (guard-tolerated) instead of `modified` (guard-forbidden).
- The checkpoint job's commit step was converted from "human visual review is the gate" to a self-gated flow: it computes changed slugs, builds `--allow` args for every non-canary slug, and runs `bash scripts/ci/snapshot-canary-guard.sh --base HEAD --allowlist test/example/priv/playwright/snapshot-allowlist --canary impersonation-banner` before committing (D-05 zero-human posture, matching the design job).
- Stale "72 admin-design / 24 boards" comments at the job header and the recapture step corrected to "84 admin-design PNGs (28 boards × chromium/mobile/dark)".
- `scripts/ci/snapshot-canary-guard.sh` now hard-fails (`fail "canary '${CANARY}' must never be allowlisted..."`) if the canary slug is present in `ALLOWED` (committed allowlist entries or `--allow` flags), placed right after the `ALLOWED` map is fully populated and before `CHANGED_SLUGS` collection. Existing added-tolerated / modified-forbidden canary semantics (lines 93-105, now shifted +9) are untouched.
- Neither recapture job's `permissions:` block was widened; neither was added to `ci-gate.needs` — both remain one-time, non-PR-gated utilities.

## Task Commits

Each task was committed atomically:

1. **Task 1: Branch-scoped recapture dispatch + narrow release_ref_guard relaxation + PR base retarget (D-04)** - `f79340cb` (feat)
2. **Task 2: Close the three recapture gaps — demo-showcase recapture, checkpoint canary delete-rebirth, stale comments (D-03)** - `2c656357` (feat)
3. **Task 3: Enforce canary-is-never-allowlistable in snapshot-canary-guard.sh (D-06)** - `0d2e5fc4` (feat)

**Plan metadata:** (this commit, following SUMMARY/STATE/ROADMAP updates)

## Files Created/Modified

- `.github/workflows/ci.yml` — added `recapture_branch` workflow_dispatch input; narrowed `release_ref_guard`; retargeted both recapture jobs' `gh pr create --base` via `RECAPTURE_BASE`; added demo-showcase recapture step + git-add to `admin_checkpoint_recapture`; added `impersonation-banner` delete-rebirth step; converted the checkpoint commit step to self-gate via `snapshot-canary-guard.sh`; corrected two stale "72/24" comments to "84/28".
- `scripts/ci/snapshot-canary-guard.sh` — added the canary-never-allowlistable assertion after the `ALLOWED` map is populated.

## Decisions Made

- D-04: chose the narrowest possible `release_ref_guard` relaxation — a single non-empty-string check on `recapture_branch`, evaluated before the tag-ref case, so every other manual dispatch (including ordinary release-evidence tag dispatches) is unaffected.
- D-03.1: folded demo-showcase recapture into the existing `admin_checkpoint_recapture` job rather than a new job, since it already boots the example app on `:4000` — cheapest correct wiring per the plan's Claude's-Discretion note.
- D-03.2/D-05: converted the checkpoint job's commit step from a human-visual-review gate to an automated `snapshot-canary-guard.sh` self-gate, matching the design job's already-established pattern, now that the delete-rebirth step makes the canary evaluate as `added` rather than `modified`.
- D-06: placed the never-allowlistable assertion as an unconditional check on the fully-populated `ALLOWED` map (not tied to whether the canary changed in this particular diff) — this closes the safety hole regardless of run context.

## Deviations from Plan

None — plan executed exactly as written. One implementation-detail adjustment (not a deviation from acceptance criteria): the plan's Task 2 automated verify grep expects the demo-showcase Playwright invocation as a single literal string (`demo-showcase.spec.ts --project=demo-showcase-chromium --update-snapshots`); rather than following the file's usual multi-line backslash-continuation style used by every other `npx playwright test` invocation in `ci.yml`, that one step was written on a single line so the plan's own verify command matches exactly. This is intentional literal-match compliance with the plan's stated verification, not a functional change.

## Issues Encountered

- `actionlint` (run as the plan's optional verify step) reports one net-new `shellcheck SC2010` warning ("Don't use ls | grep") at the new impersonation-banner delete-rebirth step. This is a byte-for-byte mirror of the pre-existing `board-notice` delete-rebirth step (ci.yml, admin_design_recapture job), which already carries the identical warning and was accepted in prior phases — not a new class of issue, just a second occurrence of an already-accepted pattern. No functional risk (the `ls | grep` is informational logging only, guarded by `|| echo "(none...)"`). Left as-is per least-surface / pattern-mirroring instruction in the plan.

## User Setup Required

None — no external service configuration required. The new `recapture_branch` dispatch input will be exercised by a later Phase 219 plan (`219-03`+) that actually triggers the recapture run against the Phase 219 branch.

## Next Phase Readiness

- The branch-scoped recapture mechanism (D-04), all three D-03 gaps, and the D-06 canary hardening are in place and verified statically (YAML parse, `bash -n`, canary-in-allowlist rejection). The mechanism has NOT yet been exercised live (no `gh workflow run` dispatch was performed in this plan — that is the subject of a subsequent Phase 219 plan per the phase's natural decomposition: icon-fix → ci.yml recapture-trigger + gaps → recapture-run/land PR → allowlist-reset follow-up PR → parity confirm).
- No blockers identified for `219-03` (expected to trigger the actual dispatch and land the recapture PR).

---
*Phase: 219-baseline-recapture-canary-reconciliation*
*Completed: 2026-07-09*

## Self-Check: PASSED

- FOUND: f79340cb (task 1 commit)
- FOUND: 2c656357 (task 2 commit)
- FOUND: 0d2e5fc4 (task 3 commit)
- FOUND: .github/workflows/ci.yml
- FOUND: scripts/ci/snapshot-canary-guard.sh
