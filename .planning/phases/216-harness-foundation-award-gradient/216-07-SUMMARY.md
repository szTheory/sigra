---
phase: 216-harness-foundation-award-gradient
plan: "07"
subsystem: admin-eval-harness
tags:
  - harness
  - award-bands
  - ci-guards
  - pilot-loop
dependency_graph:
  requires:
    - "216-01: ci.yml id:base merge-base fix"
    - "216-02: award-ledger + render-sha JSON skeleton"
    - "216-03: quality-findings-monotonic guard"
    - "216-04: award-guard + settled-findings-lint"
    - "216-05: evidence-anchor-check"
    - "216-06: render/probe engine (admin-eval.spec.ts, stale-render-guard)"
  provides:
    - scripts/ci/admin-eval-harness.sh
    - Pilot verify-then-climb (users-index-live=A2, user-show-live=A1)
    - guides/reference/admin-eval-runbook.md
    - fast_checks guard wiring + admin_eval_render CI job
  affects:
    - .github/workflows/ci.yml (fast_checks lane + new admin_eval_render job)
    - guides/reference/admin-award-ledger.json
    - guides/reference/admin-render-sha.json
    - guides/reference/admin-quality-ledger.md
tech_stack:
  added: []
  patterns:
    - Thin bash orchestrator cloned from snapshot-recapture-gate.sh shape
    - Verify-then-climb: axis up requires rendered:true + fresh verified_at_sha + resolving evidence_ref
    - JUDGE-CI-01: render+probe in separate non-gating job; only committed-ledger guards gate merges
    - band = min(axes) enforced by award-guard (never hand-typed)
key_files:
  created:
    - scripts/ci/admin-eval-harness.sh
    - guides/reference/admin-eval-runbook.md
  modified:
    - guides/reference/admin-award-ledger.json
    - guides/reference/admin-render-sha.json
    - guides/reference/admin-quality-ledger.md
    - .github/workflows/ci.yml
decisions:
  - "stale-render-guard.sh excluded from fast_checks (hard-fails on absent bundles in clean checkout) — runs in admin_eval_render job only; self-test runs in fast_checks"
  - "evidence-anchor-check.mjs added to fast_checks with soft-skip on absent bundles (exit 0) — real check fires in render job"
  - "user-show-live capped at A1: a11y_polish stays A1 because overlay-axe evidence applies to UserSessionsLive (D-24 stale claim caught)"
  - "award-guard.mjs and quality-findings-monotonic.sh both use system Node (no npm deps) — safe in fast_checks without npm ci"
metrics:
  duration: "~45 minutes (cross-session; context continued from prior run)"
  completed: "2026-07-03"
  tasks_completed: 4
  tasks_total: 5
status: checkpoint
requirements_covered:
  - HARNESS-01
  - HARNESS-02
  - HARNESS-03
  - RATCHET-01
  - RATCHET-02
---

# Phase 216 Plan 07: Convergence — Harness, Pilots, CI Wiring Summary

**One-liner:** Thin bash orchestrator + two pilot verify-then-climb (users-index-live=A2, user-show-live=A1) + guards wired into fast_checks + separate admin_eval_render CI job.

## What Was Built

### Task 1: scripts/ci/admin-eval-harness.sh

Thin bash orchestrator cloned from `snapshot-recapture-gate.sh`'s shape. Drives:
- Phase (a): runs `tests/admin-eval.spec.ts` across 3 Playwright projects (admin-eval, admin-eval-mobile, admin-eval-dark) and writes evidence bundles under `eval/<app_git_sha>/`
- Phase (b): chains all 5 derivative guards in sequence: stale-render-guard, evidence-anchor-check, quality-findings-monotonic, award-guard, settled-findings-lint

Terminal `echo "admin-eval-harness: PASS — all phases green"`. Consumes `SIGRA_EXAMPLE_URL` (default http://localhost:4011) — no embedded boot brain.

Commit: `eeb6bf14`

### Task 2: Two-pilot verify-then-climb

**D-24 user-show modal ownership re-verified**: Confirmed via `admin-modal-interaction.spec.ts` lines 90-96 that the confirm overlay navigates from user-show to `/admin/users/:id/sessions` (UserSessionsLive) — the modal is NOT on user-show-live. Stale APG claim caught as designed by D-24.

**Pilots climbed (capped at A2 per D-25):**

| Surface | Band | All axes | verified_at_sha |
|---------|------|----------|-----------------|
| users-index-live | A2 | all A2 | eeb6bf14... |
| user-show-live | A1 | all A1 | eeb6bf14... |

users-index-live: all 9 probes executed, axe 0 violations, adversarial states rendered via MG-2+MG-5 gallery boards → A2 earned.

user-show-live: all 9 probes executed, gallery boards MG-9+MG-10+MG-11 rendered → A1 (a11y_polish stays A1 because the overlay is on UserSessionsLive, not user-show-live, so overlay-axe evidence is stale for this surface).

`admin-render-sha.json` populated with real render_sha256 values from MG-5 and MG-9 gallery board bundles. 132 total bundles written.

award-guard PASS confirmed at HEAD. quality-findings-monotonic PASS confirmed.

Commit: `c214b574`

### Task 3: guides/reference/admin-eval-runbook.md

Documents:
- Single-command local iteration (scripts/db/up.sh → boot example on 4011 → admin-eval-harness.sh)
- Bundle directory layout (gitignored eval/<app_git_sha>/)
- Guard descriptions: merge-blocking fast_checks guards vs separate render job (JUDGE-CI-01)
- How to add a settled finding (settled-findings-lint.sh --add)
- How a cell climbs an award band (verify-then-climb, band=min(axes) never hand-typed)
- Human sign-off placement (milestone-terminal PR; LLM panel is Phase 217)
- Self-tests and troubleshooting

Commit: `ffb2e274`

### Task 4: .github/workflows/ci.yml wiring

**Added to fast_checks** (reads committed ledgers + merge-base, all deterministic):
- Quality findings monotonic guard (`quality-findings-monotonic.sh --base ${{ steps.base.outputs.ref }}`) + self-test
- Award ledger verify-then-climb guard (`award-guard.mjs --base ${{ steps.base.outputs.ref }}`) + self-test
- Settled findings lint (`settled-findings-lint.sh`) + self-test
- Evidence anchor integrity check (`evidence-anchor-check.mjs`) — soft-skips on absent bundles
- Stale-render guard self-test (unit test only; guard itself hard-fails on absent bundles so excluded from fast_checks clean checkout)

**Added separate `admin_eval_render` job** (NOT in ci-gate.needs per JUDGE-CI-01):
- Boots example on PORT=4011 with Postgres service
- Runs `scripts/ci/admin-eval-harness.sh` (render matrix + derivative guards)
- Uploads `eval/` bundles as CI artifacts (`admin-eval-bundles-${{ github.run_id }}`, 7-day retention)
- continue-on-error on harness step so partial bundles upload even on failure; re-fails after upload

YAML validated: `python3 -c "import yaml; yaml.safe_load(...)"` → YAML_OK

ci-gate.needs is UNCHANGED: still exactly the same 9 jobs (install_golden_contract, library_tests, library_tests_dep_off, install_smoke, upgrade_smoke, example_http_smoke, example_playwright_smoke, generated_admin_playwright_smoke, fast_checks). admin_eval_render is NOT in ci-gate.needs.

Commit: `717b69b3`

### Task 5: CHECKPOINT — Human verify

Stopping here for human verification. See checkpoint details below.

## D-24 Stale Modal Claim — Finding

The user-show-live surface's original APG/overlay-axe claim was stale. Confirmation:

- `admin-modal-interaction.spec.ts` lines 90-96: spec navigates user-show via "Manage sessions" link to `/admin/users/:id/sessions` (UserSessionsLive), then finds `#user-session-confirm-overlay`
- The confirm overlay is on **UserSessionsLive** (user-sessions), NOT user-show-live
- Therefore: a11y_polish for user-show-live cannot cite overlay-axe evidence from user-show; it stays at A1
- This was a D-24 design feature — the harness caught the stale claim rather than silently trusting it

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Architecture judgment] stale-render-guard excluded from fast_checks**
- **Found during:** Task 4
- **Issue:** Plan says "add stale-render-guard to fast_checks" but stale-render-guard.sh hard-fails on absent bundles (`eval/` is gitignored; clean checkout has no bundles). Adding it to fast_checks would cause every PR CI run to fail immediately.
- **Fix:** stale-render-guard self-test added to fast_checks (unit test, no bundles needed). The guard itself runs in admin_eval_render where bundles are produced (it's already chained as harness phase b1).
- **Alignment:** Consistent with JUDGE-CI-01 — the fast_checks guards read committed ledgers; the render job reads bundles.

**2. [Rule 1 - Architecture judgment] evidence-anchor-check placed in fast_checks with soft-skip**
- **Found during:** Task 4
- **Issue:** evidence-anchor-check.mjs requires cheerio from playwright node_modules (not installed in fast_checks). However, the script exits 0 (soft-skip) when no bundles found, so it won't fail on a clean checkout.
- **Fix:** Added to fast_checks — it will soft-skip on clean checkout (harmless), and provides real value in admin_eval_render where bundles exist. The test is also present in the harness chain.

## Threat Flags

No new network endpoints, auth paths, file access patterns, or schema changes beyond the planned CI job additions.

## Known Stubs

None — all ledger cells have real render_sha256 values from the pilot harness run.

## Self-Check: PASSED

- scripts/ci/admin-eval-harness.sh: FOUND
- guides/reference/admin-eval-runbook.md: FOUND
- guides/reference/admin-award-ledger.json: FOUND
- guides/reference/admin-render-sha.json: FOUND
- Commit eeb6bf14: FOUND
- Commit c214b574: FOUND
- Commit ffb2e274: FOUND
- Commit 717b69b3: FOUND
