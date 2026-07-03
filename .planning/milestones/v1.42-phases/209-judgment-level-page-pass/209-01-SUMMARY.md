---
phase: 209-judgment-level-page-pass
plan: "01"
subsystem: ci
tags: [ci, playwright, snapshots, admin-checkpoints, canary, recapture]
dependency_graph:
  requires: []
  provides: [admin_checkpoint_recapture-job]
  affects: [.github/workflows/ci.yml]
tech_stack:
  added: []
  patterns: [CI-native-ubuntu-recapture, snapshot-canary-guard, delete-before-recapture]
key_files:
  created: []
  modified:
    - .github/workflows/ci.yml
decisions:
  - Boot prelude cloned verbatim from admin_design_recapture (same SHA-pinned actions, MIX_ENV dev, postgres service, deps cache, Playwright install, warmup loop) — no drift between design and checkpoint lane boot sequences
  - Delete impersonation-banner-admin-checkpoints-*.png before recapture (D-10 part 2) so canary re-establishes as 'added' not 'modified' — preserves WCAG contrast fix (Phase 204-03) without allowlisting the canary
  - Guard step uses snapshot-allowlist (not snapshot-allowlist-design) and --canary impersonation-banner to match the existing guard configuration in snapshot-canary-guard.sh
  - Job placed after admin_design_recapture and before nightly_probe; not added to ci-gate.needs (out-of-band recapture, matching the design-lane pattern)
metrics:
  duration: "~4 minutes"
  completed: "2026-07-01"
  tasks_completed: 1
  tasks_total: 1
status: complete
---

# Phase 209 Plan 01: Add admin_checkpoint_recapture CI job — Summary

**One-liner:** CI-native ubuntu checkpoint recapture job mirroring the proven design-lane pattern with impersonation-banner canary re-establishment as 'added' (D-10 part 2).

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Add admin_checkpoint_recapture job mirroring design-lane pattern | 272e187c | .github/workflows/ci.yml (+199 lines) |

## What Was Built

Added a new `admin_checkpoint_recapture` job to `.github/workflows/ci.yml` that:

1. **Boot prelude** — Cloned verbatim from `admin_design_recapture`: SHA-pinned `actions/checkout`, `erlef/setup-beam`, `actions/setup-node`; postgres service; `MIX_ENV: dev`; example deps cache; `mix deps.get` + `mix compile`; `mix ecto.create && mix ecto.migrate`; `mix run priv/repo/seeds.exs`; `npm ci` + `npx playwright install --with-deps chromium webkit`; background `mix phx.server` + 30s readiness loop + warmup curl pass.

2. **Canary re-establish step** — Deletes `impersonation-banner-admin-checkpoints-*.png` before `--update-snapshots` so the canary re-appears as `added` (guard line 100 — legitimate birth path) rather than `modified` (guard line 104 — forbidden). This is D-10 part 2: a one-time deliberate re-baseline preserving the Phase 204-03 WCAG contrast fix (color-mix ratio lowered from 62%/64% to 45% for WCAG AA).

3. **Recapture step** — `npx playwright test tests/admin-checkpoints.spec.ts --project=admin-checkpoints-chromium --project=admin-checkpoints-mobile --project=admin-checkpoints-dark --update-snapshots`

4. **Guard + commit/PR step** — Computes changed slugs via `slug_of` strip (`-admin-checkpoints-(chromium|mobile|dark).png`); builds `--allow` args for all non-canary slugs; calls `snapshot-canary-guard.sh --base HEAD --allowlist test/example/priv/playwright/snapshot-allowlist --canary impersonation-banner`; commits to `ci/recapture-admin-checkpoints-<run_id>` branch + `gh pr create --base main`; `[skip ci]` prevents recursive triggering.

5. **Failure dump step** — Surfaces `/tmp/example-checkpoint-recapture-server.log` on failure.

**Trigger:** `if: github.event_name != 'pull_request'` (push-to-main, nightly cron, manual dispatch)
**Needs:** `release_ref_guard` (same as design lane)
**Permissions:** `contents: write`, `pull-requests: write`
**NOT in `ci-gate.needs`** — out-of-band recapture job

## Deviations from Plan

None — plan executed exactly as written.

## Threat Surface Scan

No new network endpoints, auth paths, file access patterns, or schema changes introduced. The job's `contents: write` permission mirrors the already-accepted `admin_design_recapture` job and is constrained to a `ci/recapture-admin-checkpoints-*` branch + PR create (never pushes to main). `[skip ci]` prevents recursive triggering. No new attack surface beyond the already-accepted design-lane job.

## Self-Check: PASSED

- FOUND: `.planning/phases/209-judgment-level-page-pass/209-01-SUMMARY.md`
- FOUND: `.github/workflows/ci.yml`
- FOUND: commit `272e187c` (feat(209-01): add admin_checkpoint_recapture CI job)
