---
phase: 221-unblock-the-gate-ship-honest-generated-host-debt
plan: 05
subsystem: release
tags: [hex, retire, ci, upgrade-smoke, gate, deferred]

# Dependency graph
requires: ["221-01", "221-02", "221-03", "221-04"]
provides:
  - "Phase-close record: retire (PUB-04) deferred by operator; PUB-01 terminal gate-green proof deferred to ship (push-to-main only)"
affects: []

# Tech tracking
tech-stack:
  added: []
  patterns: []

key-files:
  created: []
  modified:
    - .planning/todos/pending/2026-07-03-hex-retire-stray-1-20-0.md

key-decisions:
  - "PUB-04 (retire stray 1.20.0) DEFERRED by explicit operator decision at phase close (2026-07-10): near-zero current adoption, and Hex 2.5.0 blocks the programmatic path — the OAuth device-flow token from `mix hex.user auth` returns `key not authorized for this action` on `mix hex.retire` (sztheory is a `full` owner, so this is a token-scope limitation, not ownership), and Hex 2.5 dropped the CLI `key generate` subcommand. Only remaining path is a dashboard-minted API write key + `HEX_API_KEY=… mix hex.retire`, which the operator chose not to pursue now. Tracked in the updated pending todo."
  - "Retire is ORTHOGONAL to the gate (plan Pitfall 1): it changes latest_stable_version / `~> 1.0` adopter resolution but NOT the upgrade-smoke `sort -V`. The `SIGRA_UPGRADE_SMOKE_START_VERSION=1.3.0` pin (Plan 03) is what greens the smoke — so deferring PUB-04 does NOT block PUB-01 or the phase's gate-unblock goal."
  - "PUB-01 terminal proof is inherently CI/registry-side and cannot be observed until the phase PR merges: `upgrade_smoke` is `skipped` on PRs and runs only on push-to-`main` (D-16). The pin + both publishes (v1.2.0, v1.3.0) are in place; the actual green `upgrade_smoke` + `ci-gate` run is observed at ship, after merge to `main`."

requirements-completed: []

coverage:
  - id: D1
    description: "PUB-04 — retire stray 1.20.0 so latest_stable_version resolves to 1.3.0"
    requirement: "PUB-04"
    verification:
      - kind: manual
        ref: "DEFERRED by operator (2026-07-10). Preflight confirmed 1.2.0 + 1.3.0 published and 1.20.0 un-retired (latest_stable_version 1.20.0, retirements {}). Retire not performed: Hex 2.5.0 OAuth device-flow token → `key not authorized for this action`; CLI key-gen removed; dashboard write-key path declined by operator (near-zero adoption). Tracked in .planning/todos/pending/2026-07-03-hex-retire-stray-1-20-0.md (updated with the Hex 2.5 runbook + 1.3.0 target)."
        status: deferred
    human_judgment: true
  - id: D2
    description: "PUB-01 — on push-to-main with the merged PR, upgrade_smoke compiles clean under --warnings-as-errors and concludes success, and ci-gate prints 'passed: all required release lanes succeeded'"
    requirement: "PUB-01"
    verification:
      - kind: integration
        ref: "Groundwork complete and verified: SIGRA_UPGRADE_SMOKE_START_VERSION=1.3.0 pin present at ci.yml (Plan 03), v1.2.0 + v1.3.0 live on Hex (Plan 04 — grep -x confirms both), SHIP edits from Plans 01/02 committed. Terminal push-to-main proof is DEFERRED to ship: upgrade_smoke is skipped on PRs and only runs on push-to-main. To be observed via `gh run view` on the post-merge run."
        status: deferred
    human_judgment: true

# Metrics
duration: 35min
completed: 2026-07-10
status: complete
---

# Phase 221 Plan 05: Retire Stray 1.20.0 + Observe Gate-Green — Summary (with deferrals)

**Both of this plan's tasks are terminally deferred rather than executed in-session: PUB-04 (retire stray Hex `1.20.0`) was DEFERRED by explicit operator decision (near-zero adoption + a Hex 2.5.0 tooling block on programmatic retire), and PUB-01's terminal gate-green proof is inherently CI-side and DEFERRED to ship (`upgrade_smoke` runs only on push-to-`main`). The gate-unblock groundwork — the `1.3.0` pin and both Hex publishes — is complete and verified; the retire is orthogonal to the gate and does not block it.**

## Performance

- **Duration:** ~35 min (agent preflight + operator retire attempt + diagnosis + deferral record)
- **Started:** 2026-07-10T18:20:00Z
- **Completed:** 2026-07-10T18:55:00Z
- **Tasks:** 2 (both `checkpoint:human-action`/`human-verify`, both deferred)
- **Files modified:** 1 (todo update only)

## Accomplishments
- **Task 1 preflight (agent):** confirmed live Hex shows `1.2.0` + `1.3.0` published and `1.20.0` un-retired (`latest_stable_version: 1.20.0`, `retirements: {}`) — the expected pre-retire state.
- **Task 1 retire attempt (operator):** `mix hex.user auth` succeeded via OAuth device flow (authed as `sztheory`, a `full` owner of sigra), but `mix hex.retire sigra 1.20.0 invalid --message …` returned **`key not authorized for this action`**. Diagnosed as a Hex 2.5.0 limitation: the device-flow token can read (owner-list works) but isn't authorized for retire, and 2.5 removed the CLI `key generate` subcommand. Remaining path is a dashboard-minted API write key via `HEX_API_KEY`.
- **Task 1 decision (operator):** DEFER — "nobody is really using this yet." Recorded and tracked; updated `.planning/todos/pending/2026-07-03-hex-retire-stray-1-20-0.md` with the Hex 2.5 runbook, the `key not authorized` finding, and the corrected `1.3.0` GA target.
- **Task 2 (PUB-01):** groundwork verified complete — pin at `ci.yml`, both publishes live, SHIP edits committed. Terminal proof (push-to-main `upgrade_smoke` = success @ floor 1.3.0, `ci-gate` green) is deferred to the ship merge, per D-16.

## Task Commits

1. **Task 1: PUB-04 retire** — DEFERRED (no registry write); todo updated (committed with this SUMMARY).
2. **Task 2: PUB-01 observe** — DEFERRED to ship (no in-session artifact; observed post-merge).

## Files Created/Modified
- `.planning/todos/pending/2026-07-03-hex-retire-stray-1-20-0.md` — refreshed with the Hex 2.5.0 device-flow limitation, the dashboard-write-key runbook, and the `1.3.0` GA target; re-noted as deferred at the Phase 221 close.

## Decisions Made
- Defer PUB-04 (operator call, near-zero adoption + Hex 2.5 programmatic-retire block). Orthogonal to the gate — does not affect PUB-01.
- Do NOT claim PUB-01 or PUB-04 as completed by this plan (`requirements-completed: []`). PUB-01's mechanism was delivered by Plan 03; its terminal push-to-main proof is observed at ship. PUB-04 remains open/tracked.

## Deviations from Plan
- Plan 221-05 assumed the operator would run the retire and then merge/push for the gate-green observation. Instead: the retire was attempted and hit a Hex 2.5 authorization wall, and the operator deprioritized it. Both tasks are therefore deferred (one won't-do-now/tracked, one to-ship), not executed. This is a documented operator deviation, not an execution failure.

## Issues Encountered
- **Hex 2.5.0 programmatic retire blocked:** `mix hex.retire` under an OAuth device-flow token returns `key not authorized for this action` despite full package ownership; CLI `key generate` was removed in 2.5. Full detail + workaround in the tracked todo.

## User Setup Required
- (Optional / deferred) To retire `1.20.0` later: mint an API write key at https://hex.pm/dashboard/keys, then `HEX_API_KEY=<key> mix hex.retire sigra 1.20.0 invalid --message "…"`. Reversible via `--unretire`.

## Next Phase Readiness
- **PUB-01 closes at ship:** after `/gsd-ship 221` merges the phase to `main`, observe the push-to-main run — `upgrade_smoke` = success (floor 1.3.0) and `ci-gate` green. That is the terminal PUB-01 proof.
- **PUB-04 remains a tracked deferral** (todo `2026-07-03-hex-retire-stray-1-20-0.md`, `resolves_phase: 223`). Not blocking.
- Ship must reconcile the `origin/main` divergence (local `main` was 9 ahead / 2 behind at phase start — a v1.44 follow-up docs PR).

---
*Phase: 221-unblock-the-gate-ship-honest-generated-host-debt*
*Completed (with deferrals): 2026-07-10*

## Self-Check: PASSED (with documented deferrals)

Live Hex confirmed `1.2.0` + `1.3.0` published; `1.20.0` intentionally left un-retired (PUB-04 deferred, tracked). PUB-01 groundwork (pin + publishes + SHIP edits) verified present; terminal push-to-main proof honestly deferred to ship rather than claimed. No false completion: `requirements-completed: []`, and both coverage items carry `status: deferred`.
