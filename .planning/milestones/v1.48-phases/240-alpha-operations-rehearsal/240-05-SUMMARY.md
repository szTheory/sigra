---
phase: 240-alpha-operations-rehearsal
plan: 05
subsystem: testing
tags: [exunit, rate-limiting, hammer, generated-host, ci, operations]
requires: []
provides:
  - Active RED contracts for generated Hammer limiter ownership and deterministic route/context behavior.
  - Active RED contracts for three-tier operator evidence and credential-free CI claim boundaries.
affects: [240-01, 240-02, 240-03, 240-04]
tech-stack:
  added: []
  patterns: [focused source contracts, deterministic no-wait rate-limit assertions, fail-closed CI claim checks]
key-files:
  created:
    - test/sigra/install/generated_rate_limit_contract_test.exs
    - test/sigra/install/generated_rate_limit_context_test.exs
    - test/sigra/planning/phase_240_alpha_operations_rehearsal_test.exs
    - test/sigra/planning/phase_240_no_secrets_ci_test.exs
  modified: []
key-decisions:
  - "Wave 0 contracts inspect generated/source seams only and remain RED until their owning implementation plans run."
  - "Rate-limit contracts assert bounded counts and key separation without sleeps or window-crossing polls."
requirements-completed: [OPS-01, OPS-02]
coverage:
  - id: D1
    description: Generated-host Hammer ownership and route/context limiter contracts.
    requirement: OPS-01
    verification:
      - kind: unit
        ref: mix test test/sigra/install/generated_rate_limit_contract_test.exs test/sigra/install/generated_rate_limit_context_test.exs
        status: unknown
    human_judgment: true
    rationale: "These intentionally RED Wave 0 targets require Plans 240-01 and 240-02 before they can be proven green."
  - id: D2
    description: Operator evidence and credential-free CI source contracts.
    requirement: OPS-02
    verification:
      - kind: unit
        ref: mix test test/sigra/planning/phase_240_alpha_operations_rehearsal_test.exs test/sigra/planning/phase_240_no_secrets_ci_test.exs
        status: unknown
    human_judgment: true
    rationale: "These intentionally RED Wave 0 targets require Plans 240-03 and 240-04 before they can be proven green."
metrics:
  duration: 8m
  completed: 2026-08-10
status: complete
---

# Phase 240 Plan 05: Wave 0 Operations Contracts Summary

**Four active ExUnit RED contracts now define the generated limiter, operator-evidence, and no-secrets CI behavior that Plans 240-01 through 240-04 must implement.**

## Accomplishments

- Defined generated-host ownership contracts for Hammer dependency, module, supervisor, config, route prefix, idempotency, bounded exhaustion, and integer Retry-After behavior.
- Defined the selected route/context flow map with independent keys and generic anti-enumeration outcomes without rate-window waits.
- Defined structured three-tier recipe, staging receipt, truthful Doctor, and literal host/session tuple requirements.
- Defined independent credential-free lane, fixture provenance, inherited-Google unsetting, claim-boundary, and exact local-only coverage requirements.

## Task Commits

1. **Task 1: Define generated-host limiter ownership and flow-map contracts** — `c22eeb84` (test)
2. **Task 2: Define operator evidence and no-secrets CI contracts** — `2e94e64c` (test)

## Files Created

- `test/sigra/install/generated_rate_limit_contract_test.exs` — RED generated Hammer ownership, bounded tracer, and idempotency contract.
- `test/sigra/install/generated_rate_limit_context_test.exs` — RED full route/context map, independence, and generic-outcome contract.
- `test/sigra/planning/phase_240_alpha_operations_rehearsal_test.exs` — RED structured operator checklist and receipt contract.
- `test/sigra/planning/phase_240_no_secrets_ci_test.exs` — RED independent no-secrets lane and exact coverage contract.

## Decisions Made

- Used source/render contracts as the Wave 0 seam; production and document changes remain owned by Plans 240-01 through 240-04.
- Kept all limiter assertions synchronous and bounded; no test uses sleeps, elapsed-window polling, or a skipped placeholder.

## Verification

- PASS — `mix format --check-formatted` for all four new ExUnit modules.
- PASS — `Code.string_to_quoted!` parsing for all four new ExUnit modules.
- RED as designed — focused `mix test` executions expose absent generated limiter, recipe, and CI behavior for downstream plans. The local PostgreSQL endpoint was unavailable, producing connection-refused log noise during ExUnit initialization; it did not prevent source-contract execution.

## Deviations from Plan

None — plan executed exactly as written.

## Known Stubs

None.

## Next Phase Readiness

Plans 240-01 through 240-04 have focused, active, deterministic tests to turn green. No implementation behavior was added in Wave 0.

## Self-Check: PASSED

- All four required contract files exist and parse.
- Task commits `c22eeb84` and `2e94e64c` exist in git history.

