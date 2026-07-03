---
phase: 215
plan: "04"
subsystem: ci/ship
tags: [health-04, ship-pr, required-checks, ci-gate, milestone-close, ruleset-14941512]
dependency_graph:
  requires: [215-01-SUMMARY, 215-02-SUMMARY, 215-03-SUMMARY]
  provides: [v1.43-ship-pr, health-04-ci-green-signal, deferred-merge-archival-handoff]
  affects: [HEALTH-04, RATIFY-01, /gsd-ship, /gsd-complete-milestone]
tech_stack:
  added: []
  patterns: [ship-branch-convention, required-check-gate, deletion-restore-disposition]
key_files:
  created:
    - .planning/phases/215-terminal-ratification/215-04-SUMMARY.md
  modified: []
decisions:
  - "110 uncommitted .planning/ deletions (v1.42 phase-dirs 205-212) dispositioned by RESTORE, not commit-as-chore: they were never actually archived (no .planning/milestones/v1.42-phases/ exists, unlike every prior milestone), so committing the raw deletion would drop them permanently without archiving. Restore preserves them for proper archive-move by /gsd-complete-milestone (D-01). User-confirmed."
  - "Ship PR cut via the milestone ship convention (ship/vX.Y-<slug> -> main), mirroring v1.42 PR #63 (ship/v1.42-ci-gate-remediation). PR #67: ship/v1.43-stabilize -> main, 51 commits."
  - "All FIVE required checks under ruleset 14941512 GREEN on the unmerged PR — the HEALTH-04 signal of record (D-01). Local mix test/act runs are confidence-only."
  - "Human-verify checkpoint auto-approved: the gate condition (5 required contexts SUCCESS, PR unmerged, branch current with base) is machine-verified via `gh pr checks 67 --required`, not a judgment call (zero-human-UAT)."
  - "Merge to origin/main deferred to /gsd-ship (final); milestone archival deferred to /gsd-complete-milestone (D-01). This plan gets the checks GREEN only; PR remains UNMERGED."
metrics:
  duration: "~35 minutes (26m of it CI wall-clock)"
  completed: "2026-07-03"
  tasks: 4
  files: 1
status: complete
---

# Phase 215 Plan 04: v1.43 Ship PR & HEALTH-04 CI-Green Signal

## What this plan did

Surfaced the never-CI'd v1.43 body (local `main`, 51 commits ahead of `origin/main`) to
GitHub Actions as a clean, unmerged ship PR and gated **HEALTH-04** on all five required
checks passing green under branch ruleset 14941512 (strict policy). The suites and ledger
were already proven green locally by 215-01/02/03; this plan is the remote signal of record.

## Task 1 — `.planning/` deletion disposition (D-01)

- **Observed git state:** `main` 51 commits ahead of `origin/main`; **110** uncommitted
  working-tree deletions, all under `.planning/phases/` for the **v1.42 phase dirs**
  (205-foundation, 206, 207, 208, 208.1, 209, 210, 211, 212).
- **Cross-check:** The canonical milestone-close pattern (v1.28/v1.32/v1.34–v1.41) is an
  **archive-MOVE** to `.planning/milestones/vX.Y-phases/`. There is **no
  `.planning/milestones/v1.42-phases/`** — only `v1.42-{ROADMAP,REQUIREMENTS,MILESTONE-AUDIT}.md`
  files. So the 205-212 dirs were `rm`'d from the working tree but **never archived**. The
  content is still intact at HEAD (fully recoverable).
- **Disposition — RESTORE (not commit-as-chore):** committing the raw deletion would drop the
  v1.42 phase artifacts permanently without them ever reaching the `milestones/` archive every
  other milestone has. Since D-01 defers milestone archival to `/gsd-complete-milestone`, the
  correct, reversible, canonical-preserving disposition is to **restore** the dirs and leave the
  proper archive-move to milestone completion. This is the plan's sanctioned restore branch
  ("`git restore` … if archival policy says /gsd-cleanup owns that sweep"). **User-confirmed.**
- **End state:** worktree clean, **0 stray `.planning/` deletions**, dirs 205-212 restored,
  v1.43 body intact on `main`.

## Task 2 — Cut and push the v1.43 ship PR (D-01)

- **Path:** milestone ship convention (user-selected `/gsd-ship`; executed the ship mechanics
  directly because this gsd install's `verification.status`/`git.base-branch` registry verbs
  are unavailable and verification is genuinely the final execute-phase step, post-215-04).
- **Branch:** `ship/v1.43-stabilize` (mirrors `ship/v1.42-ci-gate-remediation` / PR #63),
  cut from `main` HEAD, pushed to origin.
- **PR:** **#67** — https://github.com/szTheory/sigra/pull/67
  - base `main`, head `ship/v1.43-stabilize`, **51 commits**, `MERGEABLE` / `mergeStateStatus: CLEAN`
  - Body references the 215-01/02/03 green evidence and enumerates the five required checks.
- GitHub Actions run `28649739883` triggered the full required-lane matrix.

## Checkpoint — five required checks GREEN on the unmerged PR (HEALTH-04)

Confirmed via `gh pr checks 67 --required` — **the HEALTH-04 signal of record (D-01)**:

| # | Required check (ruleset 14941512) | Status | Duration |
|---|-----------------------------------|--------|----------|
| 1 | `Library tests` | ✅ pass | 3s (aggregate; shards 1/2 + dep-off all green) |
| 2 | `Example unit smoke (ExUnit + ConnTest)` | ✅ pass | 56s |
| 3 | `Install smoke (fresh phx.new + sigra.install)` | ✅ pass | 1m49s |
| 4 | `Example HTTP smoke (boot + curl critical routes)` | ✅ pass | 50s |
| 5 | `Example Playwright smoke (full lifecycle)` | ✅ pass | 26m10s |

Supporting lanes also green (Install golden + idempotency contract 5m44s, Fast checks 11s,
Release ref guard 4s, `ci-gate` 2s). Conditional lanes (admin Playwright/design recapture,
passkeys, upgrade smoke, install matrix, nightly probe) reported `skipping` as expected —
none is a disguised failure. **Zero red checks. No masked gates, no fixture/baseline edits.**

- PR **current with base**: 0 commits behind `origin/main` (strict policy satisfied).
- Checkpoint **auto-approved** — the gate is machine-verified (5 required SUCCESS + unmerged +
  current with base), consistent with zero-human-UAT.

## Task 3 — HEALTH-04 signal + deferred hand-off (D-01)

- **HEALTH-04 signal of record:** PR #67's GitHub Actions run with all five required checks
  green (above). Local `mix test`/`act` were confidence-only.
- **RATIFY-01 "full suite + CI green" legs** are fully evidenced: 215-01 (library 0-fail) +
  215-02 (example 0-fail) for the suites, this plan (5 required checks green) for CI, and
  215-03 for the reconciled ledger + close-readiness record.
- **Deferred (D-01):** merge to `origin/main` → `/gsd-ship` (final); milestone archival →
  `/gsd-complete-milestone`. **PR #67 remains UNMERGED.** The v1.42 phase-dir archive-move
  (restored in Task 1) is part of that deferred archival.

## Verification

- [x] 110 `.planning/` deletions dispositioned (restore); `git status` clean worktree.
- [x] v1.43 ship PR (#67) open against `origin/main` via the ship convention; Actions ran the required matrix.
- [x] All five required checks GREEN on the unmerged PR (human-verify gate, machine-confirmed).
- [x] PR remains UNMERGED; merge + archival deferred to /gsd-ship + /gsd-complete-milestone (D-01).
- [x] No product code, test, fixture, or baseline modified to pass any gate (D-06).
