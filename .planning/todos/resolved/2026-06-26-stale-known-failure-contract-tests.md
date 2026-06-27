---
type: todo
created: 2026-06-26
surfaced_by: phase-201 regression gate
status: resolved
resolved: 2026-06-27
resolved_by: phase-204-02
---

# Two stale "known-failure contract" ExUnit tests now fail (pre-existing, not Phase 201)

Surfaced by the Phase 201 regression gate (`mix test`). Both are stale meta-tests that
assert a quarantine/branding state which earlier work already changed. Neither touches any
file Phase 201 modified — proven pre-existing (failure #1 already red at base commit
`7687b980`; failure #2 reads only README/llms.txt/demo-showcase/uat-scripts, none in the
Phase 201 diff). Filed so they are not lost; they are doc/test debt, not regressions.

## 1. `Sigra.Planning.Phase192KnownFailureContractTest` — `test/sigra/planning/phase_192_known_failure_contract_test.exs:32`
Asserts `admin-design.spec.ts` MG-5/6 block still contains a `test.skip(` quarantine marker.
The marker is **already gone** (the MG-5/6 content-equivalence test now runs — quarantine
appears to have been lifted by Phase 199's stress fixtures providing the 25+ audit events the
test needed). **Fix:** delete/relax this contract test AND resolve the companion todo
`.planning/todos/pending/2026-06-17-admin-design-mg5-6-content-equivalence-data-dependent.md`
(the quarantine it tracks is no longer in place).

## 2. `Sigra.Planning.Phase148EvaluatorFunnelAndFirstRunDxTest` — `test/sigra/planning/phase_148_evaluator_funnel_and_first_run_dx_test.exs:40`
Asserts `doc/llms.txt` contains `"- [Demo Showcase — Vaultr Example App](demo-showcase.md)"`
(and likely other `Vaultr` strings). The demo app was renamed **Vaultr → Tasklane** in quick
task `260622-jfr`, so the live docs drifted from this assertion. **Fix:** update the Phase 148
contract test's expected strings (and any demo-showcase/llms.txt copy) to `Tasklane`.

## Also still red (known env, unchanged): `Sigra.UpgradeIntegrationTest`
3 failures at `test/upgrade_test.exs:212` (`seed_users!/2`) — known local env-DB failures,
not a regression. Tracked in prior milestone known-failure notes.

## Resolution (2026-06-27, Phase 204-02)

Both stale contracts fixed in plan 204-02:
- `phase_192_known_failure_contract_test.exs` **deleted** (the `test.skip(` marker it asserted is gone; quarantine lifted in Phase 199/197).
- `phase_148_evaluator_funnel_and_first_run_dx_test.exs` updated Vaultr→Tasklane; companion docs (demo-showcase.md, doc/llms.txt) reconciled. `grep -ci vaultr` = 0 on all targets.

The 3 `Sigra.UpgradeIntegrationTest` env-DB failures remain accepted (D-09), not a regression.
