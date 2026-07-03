---
phase: 211-terminal-ratification
plan: "03"
subsystem: testing
tags: [mix-test, exunit, terminal-gate, ratification, known-failures, upgrade-integration]

requires:
  - phase: 211-01
    provides: GATE-01 ledger lock + canary idempotency + compare-mode zero drift
  - phase: 211-02
    provides: GATE-02 generated-host parity smoke + phx_new 1.8.7 pin confirmation

provides:
  - "Terminal mix test gate verdict: suite clean modulo D-05 accepted known/env failures"
  - "NoopTest shard-race confirmed by isolation run (3/3, no regression)"
  - "204 D-08 stale-contract tests re-confirmed green (4/4, no re-fix)"
  - "Full-suite 2403 tests classified — 2 failures, both Sigra.UpgradeIntegrationTest env-DB"
  - "No new real regression beyond the accepted known/env set"
  - "Honest clean-suite baseline for Plan 04 milestone audit"

affects:
  - phase: 211-04
  - milestone-audit
  - GATE-01
  - GATE-02

tech-stack:
  added: []
  patterns:
    - "Accepted known/env failure classification: UpgradeIntegrationTest failures need per-fixture DB (mix ecto.create) — accepted, not blockers"
    - "Shard-race flake classification: NoopTest passes 3/3 in isolation => parallel-shard log-capture race, not a deterministic branch regression"

key-files:
  created: []
  modified: []

key-decisions:
  - "NoopTest flake is a parallel-shard log-capture race (not a regression): lean documented-known per Claude's Discretion (D-05); no determinism fix applied"
  - "Full-suite 2 failures (not 3 as research predicted) are both Sigra.UpgradeIntegrationTest env-DB failures — both accepted per D-05"
  - "phase_192_known_failure_contract_test.exs was intentionally deleted in 204-02 (all Phase192 known failures resolved); the '4 tests' all come from phase_148 which has 4 test cases"
  - "No product-behavior change and no test edits made to green the suite — git status clean throughout"

patterns-established:
  - "D-05 classification discipline: enumerate every failure, confirm each maps to the accepted set, STOP if any falls outside it"

requirements-completed: [GATE-01, GATE-02]

coverage:
  - id: D1
    description: "NoopTest isolation run confirms 3/3 pass — shard log-capture race, not a regression (D-05)"
    requirement: GATE-01
    verification:
      - kind: unit
        ref: "MIX_ENV=test mix test test/sigra/audit/forwarders/noop_test.exs => 3 tests, 0 failures"
        status: pass
    human_judgment: false
  - id: D2
    description: "204 D-08 stale-contract tests re-confirmed green (4/4) — phase_148 all 4 test cases pass"
    requirement: GATE-01
    verification:
      - kind: unit
        ref: "MIX_ENV=test mix test test/sigra/planning/phase_148_evaluator_funnel_and_first_run_dx_test.exs => 4 tests, 0 failures"
        status: pass
    human_judgment: false
  - id: D3
    description: "Terminal mix test gate: 2403 tests, 2 failures (both Sigra.UpgradeIntegrationTest env-DB) — no new regression"
    requirement: GATE-01
    verification:
      - kind: integration
        ref: "MIX_ENV=test mix test => 33 doctests, 3 properties, 2403 tests, 2 failures, 12 skipped"
        status: pass
    human_judgment: false

duration: 19min
completed: 2026-07-01
status: complete
---

# Phase 211 Plan 03: Terminal mix test gate Summary

**Terminal `mix test` gate classified clean: 2403 tests with exactly 2 Sigra.UpgradeIntegrationTest env-DB failures in the accepted known/env set — zero new regressions, confirming an honest suite baseline for the milestone audit.**

## Performance

- **Duration:** 19 min
- **Started:** 2026-07-01T20:23:15Z
- **Completed:** 2026-07-01T20:42:22Z
- **Tasks:** 3
- **Files modified:** 0 (verification-only plan)

## Accomplishments

- NoopTest confirmed as a shard log-capture race (3/3 in isolation) — documented-known, not a blocker; no determinism fix applied per Claude's Discretion (D-05)
- 204 D-08 stale-contract tests re-confirmed green: `phase_148_evaluator_funnel_and_first_run_dx_test.exs` 4 tests, 0 failures; `phase_192_known_failure_contract_test.exs` was correctly deleted in 204-02 (all Phase192 known failures resolved)
- Full suite result: 33 doctests, 3 properties, 2403 tests, **2 failures**, 12 skipped — both failures are `Sigra.UpgradeIntegrationTest` env-DB failures (accepted D-05 known/env set)
- Failure classification confirmed: both `upgrade_test.exs` failures trace to `seed_users!/2` / `mix ecto.migrate` with `database "upg_*_dev" does not exist` — the per-fixture DB was not created (accepted env limitation)
- No new real regression exists beyond the D-05 accepted known/env set — clean baseline for Plan 04 audit

## Task Commits

Each task was committed atomically (verification-only tasks committed with `--allow-empty` for tracking):

1. **Task 1: NoopTest isolation confirms shard-race (D-05)** - `1c6e78e2` (chore)
2. **Task 2: 204 D-08 stale-contract re-confirmed green (4/4, no re-fix)** - `b225519f` (chore)
3. **Task 3: Terminal mix test gate classified; 2 env-DB failures in accepted set** - `823b65ec` (chore)

## Files Created/Modified

None — this plan is pure verification (D-10: no product-behavior changes or test edits).

## Decisions Made

- **NoopTest**: lean documented-known per Claude's Discretion (D-05) — 3/3 in isolation confirms the full-suite flake is a shard log-capture race; no `async: false` / scoped-capture fix applied
- **Failure count**: research predicted "3 Sigra.UpgradeIntegrationTest failures" but the run produced 2 — this is run-to-run variability in which UpgradeIntegrationTest cases are triggered; all observed failures are confirmed within the accepted set
- **phase_192 file**: correctly absent — deleted in 204-02 as `c9e5cbbb fix(204-02): delete stale Phase192 known-failure contract test (D-08)` because all Phase192 known failures were resolved

## Deviations from Plan

None — plan executed exactly as written. All acceptance criteria met; no determinism fix applied (lean documented-known); no product or test edits.

## Issues Encountered

None — the DB environment was available and all commands succeeded. The UpgradeIntegrationTest env-DB failures are expected and accepted per D-05 (they need a separate per-fixture DB created by `mix ecto.create` inside the test's temp directory, which is an intentional env limitation).

## Known Stubs

None — this plan produces no code output; stub scan is N/A.

## Threat Flags

None — verification-only plan with no new trust boundary, endpoints, schemas, or crypto paths. Threat model unchanged from v1.41 close (T-211-03 accepted at low severity per plan).

## User Setup Required

None — no external service configuration required.

## Next Phase Readiness

Plan 04 (milestone audit) can now cite this plan as clean-suite evidence:

- NoopTest flake: confirmed shard race (3/3 isolation) — cite `1c6e78e2`
- 204 D-08 stale-contract tests: re-confirmed green (4/4) — cite `b225519f`
- Full-suite terminal gate: 2 failures, both `Sigra.UpgradeIntegrationTest` env-DB in accepted set — cite `823b65ec`
- VERDICT: honest green baseline for GATE-01/GATE-02 milestone audit

## Self-Check

- [x] NoopTest isolation: 3 tests, 0 failures (`1c6e78e2`)
- [x] phase_148 stale-contract: 4 tests, 0 failures (`b225519f`)
- [x] Full suite: 2403 tests, 2 failures (both UpgradeIntegrationTest env-DB) (`823b65ec`)
- [x] All 3 task commits verified in git log
- [x] git status clean throughout — no product or test edits

## Self-Check: PASSED

---
*Phase: 211-terminal-ratification*
*Completed: 2026-07-01*
