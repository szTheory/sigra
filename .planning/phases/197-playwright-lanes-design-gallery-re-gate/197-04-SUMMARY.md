---
phase: 197-playwright-lanes-design-gallery-re-gate
plan: "04"
subsystem: ci
tags: [playwright, ci, baseline-recapture, canary-guard, visual-regression, github-actions]
dependency_graph:
  requires:
    - phase: 197-02
      provides: guarded Playwright seams + aggregator
    - phase: 197-03
      provides: deterministic font render (woff2 + fonts.check guard)
  provides:
    - admin_design_recapture CI job (D-09)
    - OQ1 canary re-baseline strategy (board-notice as 'added' not 'modified')
    - OQ2 reviewable PR commit path (ci/recapture-* branch)
    - OQ3 cross-lane compare gate (admin-checkpoints + demo-showcase in compare mode)
  affects:
    - 197-05 (gallery re-gate — requires deterministic baselines to remove continue-on-error)
tech_stack:
  added: []
  patterns:
    - "Non-PR-gated sibling job with job-level contents: write (Phase-196 precedent)"
    - "OQ1 canary re-baseline via pre-delete so guard sees 'added' not 'modified'"
    - "OQ2 reviewable commit via ci/recapture-<run_id> branch + gh pr create"
    - "OQ3 compare-and-report bounded scope: compare mode only, deferred todo if shift"
    - "WR-04 backgrounded-server log + failure dump idiom"
key_files:
  created: []
  modified:
    - .github/workflows/ci.yml
decisions:
  - "OQ1: board-notice PNGs deleted before --update-snapshots so guard sees 'added' (birth path) not 'modified' (forbidden) — canary tripwire stays armed"
  - "OQ2: recaptured PNGs committed to ci/recapture-admin-design-<run_id> branch + gh pr create for human review; NOT a silent push to main"
  - "OQ3: bounded compare-and-report scope — sibling lanes run in compare mode only; if shift detected, write tracked todo with per-lane recapture command, NOT an unscoped mid-run recapture"
  - "Job-level permissions: contents: write + pull-requests: write (for gh pr create); workflow default contents: read is unchanged"
  - "cross_lane_compare uses continue-on-error: true so compare failure does not block the recapture PR"
metrics:
  duration: "~5 minutes"
  completed: "2026-06-20"
  tasks_completed: 3
  files_modified: 1
status: complete
requirements: [PW-03]
---

# Phase 197 Plan 04: PW-03 In-CI Baseline Recapture Job Summary

**Non-PR-gated `admin_design_recapture` CI job with OQ1 canary re-baseline (board-notice as `added`), OQ2 reviewable PR commit path, and OQ3 cross-lane compare-mode drift check**

## Performance

- **Duration:** ~5 minutes
- **Started:** 2026-06-20T19:16:41Z
- **Completed:** 2026-06-20T19:21:41Z
- **Tasks:** 3
- **Files modified:** 1

## Accomplishments

- Added `admin_design_recapture` sibling job to `.github/workflows/ci.yml` (D-09):
  - `if: github.event_name != 'pull_request'` (schedule + push + dispatch only — never runs on PRs)
  - Job-level `permissions: { contents: write, pull-requests: write }` — the workflow default `permissions: { contents: read }` at ci.yml:26 is unchanged
  - `needs: release_ref_guard`, `runs-on: ubuntu-latest`
  - Postgres `services:` block copied verbatim from `upgrade_smoke`
  - Full boot prelude cloned from `example_playwright_smoke` (same SHA-pinned action refs, `MIX_ENV: dev`, PGUSER/PGPASSWORD/PGHOST, readiness loops)
  - Recapture step: `npx playwright test tests/admin-design.spec.ts --project=admin-design-{chromium,mobile,dark} --update-snapshots`

- **OQ1 (canary re-baseline):** `Re-establish board-notice canary` step deletes existing `board-notice-admin-design-*.png` files before `--update-snapshots` runs. This makes Playwright re-create them as newly-added files. `snapshot-canary-guard.sh` tolerates `added` (line 100) but FORBIDS `modified` (line 104). Result: the canary re-baseline is a deliberate one-time birth event, NOT allowlisted, and the tripwire stays armed for all future incremental PRs.

- **OQ2 (reviewable commit):** `Gate + commit recaptured baselines` step:
  1. Computes changed slugs from `git diff --name-status HEAD` + `git status --porcelain` over the snapshot dir
  2. Runs `snapshot-canary-guard.sh --base HEAD --allowlist snapshot-allowlist-design --canary board-notice --allow <each non-canary slug>`
  3. Creates `ci/recapture-admin-design-<run_id>` branch
  4. Commits with `[skip ci]` message (avoids re-triggering this job)
  5. Pushes and opens a PR via `gh pr create`
  The `snapshot-allowlist-design` file remains empty (its steady-state contract is unchanged).

- **OQ3 (cross-lane compare):** `Check cross-lane baseline drift from global --font-sans` step runs `admin-checkpoints.spec.ts` (all 3 projects) and `demo-showcase.spec.ts` in COMPARE mode (no `--update-snapshots`) against the font-loaded app. Uses `continue-on-error: true` so a compare failure does not block the recapture PR. `Record OQ3 cross-lane drift result` step (always runs) writes a tracked todo to `.planning/todos/pending/` if either lane shifted, capturing the concrete per-lane recapture commands (admin-checkpoints via `snapshot-recapture-gate.sh` + `impersonation-banner` canary; demo-showcase via manual review). If both pass, records that scope stays admin-design only.

- **WR-04 failure dump:** `Dump example app log (on failure)` step surfaces `/tmp/example-recapture-server.log` so a boot failure in the recapture job is legible.

## Task Commits

Each task was committed atomically:

1. **Task 1: Add admin_design_recapture sibling job (boot prelude + recapture step) (D-09)** - `ca3e1d03` (feat)
2. **Task 2: Gate + commit recaptured baselines via canary-guard; handle OQ1 + OQ2** - `f432d084` (feat)
3. **Task 3: Check cross-lane baseline drift from the global --font-sans (OQ3)** - `052b1fd9` (feat)

## Files Modified

- `.github/workflows/ci.yml` — added `admin_design_recapture` job with 10 steps (boot prelude + canary re-baseline + recapture + gate/commit + cross-lane compare + OQ3 record + failure dump); no edits to existing jobs; global `permissions: { contents: read }` unchanged

## Decisions Made

- **OQ1 resolution:** The `board-notice` canary conflict (font modifies it; guard forbids `modify`) is resolved by deleting the 3 board-notice PNGs before `--update-snapshots` runs, making them appear as `added` — the guard's legitimate birth path (line 100). This is a one-time deliberate re-baseline, explicitly documented in the step comment. The canary is NOT added to the allowlist (canary is never allowlistable; the comment in `snapshot-allowlist-design` line 18 says "The `board-notice` canary must NEVER appear here").
- **OQ2 resolution:** Recaptured baselines land on a `ci/recapture-admin-design-<run_id>` branch + a PR opened via `gh pr create`. The commit carries `[skip ci]` to avoid re-triggering CI. This satisfies T-197-10 (unreviewed baseline commit threat — baselines get human review before merge).
- **OQ3 bounded scope:** The plan mandates compare-and-report without triggering an unscoped sibling-lane recapture. `continue-on-error: true` on the compare step ensures the recapture PR is never blocked by cross-lane drift. If drift is detected, a tracked todo captures the concrete per-lane recapture path. If neither lane shifts, the SUMMARY records OQ3 closed (scope stays admin-design only).
- **Least privilege (T-197-09):** `contents: write` + `pull-requests: write` scoped to the job block only; the workflow-level `permissions: contents: read` at ci.yml:26 is unchanged. The job is gated to `github.event_name != 'pull_request'` so untrusted PRs cannot trigger write-capable runs.

## Deviations from Plan

None — plan executed exactly as written. All three open questions (OQ1, OQ2, OQ3) are resolved per the plan's prescribed strategy.

## Known Stubs

None. The recapture job is complete CI YAML — it will execute when triggered on a non-PR event. The baselines themselves will be recaptured when the job runs in CI.

## Threat Flags

| Flag | File | Description |
|------|------|-------------|
| Mitigated — T-197-09 | .github/workflows/ci.yml | `contents: write` scoped to job level only; `if: github.event_name != 'pull_request'` prevents untrusted PR from triggering write-capable run |
| Mitigated — T-197-10 | .github/workflows/ci.yml | Recapture commits land on `ci/recapture-*` branch + PR (not silent push to main); baseline changes require human review before merge |
| Mitigated — T-197-11 | .github/workflows/ci.yml | `board-notice` canary re-established as `added` (not allowlisted, not `modify`); tripwire stays armed for future incremental PRs |

## Self-Check: PASSED

- `.github/workflows/ci.yml` — modified (verified; YAML valid per `python3 yaml.safe_load`)
- `admin_design_recapture` job — present (grep verified)
- Job-level `permissions: contents: write` — present (Python YAML parse verified)
- Global `permissions: contents: read` — unchanged (Python YAML parse verified)
- `--update-snapshots` in recapture step — present (grep verified)
- `if: github.event_name != 'pull_request'` — present (grep verified)
- `snapshot-canary-guard.sh` consumed — NOT modified (scripts/ci/snapshot-canary-guard.sh SHA unchanged)
- `snapshot-allowlist-design` — zero non-comment lines (grep -vc '^#' verified → 0)
- Commit `ca3e1d03` — exists (git log verified)
- Commit `f432d084` — exists (git log verified)
- Commit `052b1fd9` — exists (git log verified)
- `phase_58_oauth_oa01_ci_contract_test.exs` — 1 test, 0 failures (mix test verified)
