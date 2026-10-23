---
phase: "241"
slug: "retire-v1-47-s-dishonest-debt-adopter-leakage-guard"
status: reconciled
nyquist_compliant: true
created: "2026-09-25"
updated: "2026-09-25"
---

# Phase 241 — Validation Strategy

> Maps the completed phase goal to its existing regression contracts, hermetic evidence collector,
> and immutable final-head receipt. Scope is limited to real guards and adopter-visible leakage.

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Frameworks** | Node built-in test runner, ExUnit, Bash hermetic test harness |
| **Prohibition suite** | `node --test --test-reporter=tap scripts/ci/prohibitions/*.test.mjs` |
| **Final-head collector** | `bash scripts/ci/capture-phase-241-final-head.test.sh` |
| **Focused ExUnit contracts** | `MIX_ENV=test mix test test/sigra/planning/phase_233_library_economics_contract_test.exs test/sigra/planning/phase_234_action_pinning_contract_test.exs` |
| **Full suite** | `MIX_ENV=test mix ci` (rerun against the current working tree; blocked by unrelated Phase 242 formatting drift) |

## Goal-to-Evidence Map

| Goal area | Deterministic check | Current result |
|-----------|---------------------|----------------|
| Retired timing formatter and unchanged single-owner `mix ci` topology | Phase 233 ExUnit contract plus source absence/ADR checks in `241-VERIFICATION.md`; final-head CI receipt verifies the exact alias step | ExUnit 18/18 combined with Phase 234 contract; final-head receipt documented at PR #254, final SHA `782328e65c134dc4b1f9bba522190838366bf08d` |
| Reject multiple full-suite owners and preserve action pin coverage, including composite bare `uses:` forms | `MIX_ENV=test mix test ...phase_233... phase_234...` | **18 tests, 0 failures** (current rerun) |
| Honest-skip documentation parity, P18 leakage guards, template/bookkeeping guard, independent R1/R2/R3 ratchets, and scanner parity corpus | `node --test --test-reporter=tap scripts/ci/prohibitions/*.test.mjs` | **112 tests, 0 failures** (current rerun); counters R1=337, R2=220, R3=58 at their separate baselines |
| Same-SHA final-head receipt collector rejects identity, pagination, job, step, and rate-limit failures | `bash scripts/ci/capture-phase-241-final-head.test.sh` | **71 assertions passed** (current rerun) |
| External final-head CI proves exact frozen SHA, required jobs and steps, and API coverage is declared | `241-VERIFICATION.md` plus `241-01-EVIDENCE.md`; seal gate: `node ~/.codex/gsd-core/bin/gsd-tools.cjs check api-coverage.verify-pre .planning/phases/241-retire-v1-47-s-dishonest-debt-adopter-leakage-guard --raw` | Existing PR #254 receipt covers frozen SHA `782328e65c134dc4b1f9bba522190838366bf08d`, before the current collector hardening; it does not prove this working-tree version. The API coverage gate passes (6 capabilities, 0 opt-out). A new exact-SHA receipt remains required. |

## UAT Coverage

All 18 UAT checks are recorded automated-pass in `241-UAT.md`. They cover formatter retirement,
single-owner CI, plan evidence, negative controls for workflow/guard changes, scanner and fixture
parity, hermetic receipt validation, clean Threadline build plus exact CI alias, final-head CI, and
API-coverage declaration. The linked plan evidence files provide task-level commands and results.

## Current Audit Notes

- The current prohibition suite, final-head collector self-test, and Phase 233/234 ExUnit contracts
  all passed as listed above.
- `MIX_ENV=test mix clean` followed by the six-case Threadline test initially failed because the
  configured PostgreSQL port had no listener. After bringing up the repository's isolated test DB
  and keeping the fresh build, the same focused test passed **6/6**.
- The exact `MIX_ENV=test mix ci` rerun stops at `mix format --check-formatted` because
  `test/sigra/planning/phase_242_shift_left_contract_test.exs` is unformatted. This is a
  deterministic failure in Phase 242's dirty working-tree file, outside Phase 241's scope; it was
  left unchanged. Plan 241-08 requires this unrelated failure to be resolved before freezing and
  publishing the final evidence SHA.
- A broader optional ExUnit batch that also included Phase 235 source-complete tests produced
  **42 tests, 2 failures** because those tests attempted a nested `sandbox-exec` that returned
  `Operation not permitted` (exit 71). The failures are environment restrictions in Phase 235
  tests, outside Phase 241's phase-owned test suite; the Phase 241-relevant Phase 233/234 contracts
  were rerun separately and passed. Prior phase UAT records the broader related group passing when
  run with permission for the nested offline sandbox.
- Test application startup emits local Postgres connection-refused log messages; the focused
  Phase 233/234 contracts and repository guards still complete successfully.
- `241-VERIFICATION.md` records 43/43 must-haves and zero behavior-unverified claims. The phase UAT
  also flags legacy `241-08-SUMMARY.md` commit-count metadata as unverified; that is not a product
  behavior gap and is not upgraded to a pass by this validation map.

**Validation status:** Phase 241's focused local checks are green, but the exact full-suite local
gate is blocked by the unrelated Phase 242 formatting failure. The old PR #254 receipt predates
the current collector edits, so exact-SHA external proof is also still pending. Phase 241 remains
unverified for transition until the unrelated formatting issue is resolved and the collector
follow-up is committed and proven on its exact SHA.
