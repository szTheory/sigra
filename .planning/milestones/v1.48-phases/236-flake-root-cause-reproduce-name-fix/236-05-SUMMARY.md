---
phase: 236-flake-root-cause-reproduce-name-fix
plan: "05"
subsystem: testing
tags: [ci, provenance, evidence-ledger, security, prohibitions]
requires:
  - phase: 236-04
    provides: "Phase 236 RED/GREEN evidence ledger and five-run CI proof"
provides:
  - "A default p12 guard that validates both archived Phase 230 and live Phase 236 ledgers"
  - "Committed Phase 236 provenance negative control and independent CI-route contract"
  - "Verified closure of T-236-03 and T-236-15"
affects: [fast_checks, evidence-ledgers, phase-236-security]
plan_head_before: ebc9b8370e38d24fc88b816a8bf46288b4006ab3
actuals:
  tokens: 5744
  tasks: 3
  commits: 4
tech-stack:
  added: []
  patterns:
    - "Per-ledger provenance floors let one hermetic guard protect archived and live evidence without weakening either contract."
key-files:
  created:
    - test/fixtures/prohibitions/p12-phase236-claim-without-run-id.md
    - test/sigra/planning/phase_236_evidence_provenance_guard_test.exs
  modified:
    - scripts/ci/prohibitions/p12-run-id-provenance.test.mjs
    - .planning/phases/236-flake-root-cause-reproduce-name-fix/236-EVIDENCE.md
    - .planning/phases/236-flake-root-cause-reproduce-name-fix/236-SECURITY.md
key-decisions:
  - "Kept the default Phase 230 path archive-aware; direct fixture substitution uses its archived file path because injected subjects intentionally fail fast rather than silently relocating."
  - "Used the existing Fast checks CI receipt (35034938082) to make AFTER-P17-GUARD-OBSERVED satisfy the same evidence grammar as the other captured Phase 236 slots."
requirements-completed: [GREEN-01, GREEN-02]
coverage:
  - id: D1
    description: "The default p12 provenance guard mechanically validates both the Phase 230 and Phase 236 evidence ledgers."
    requirement: GREEN-01
    verification:
      - kind: other
        ref: "node --test --test-reporter=tap scripts/ci/prohibitions/p12-run-id-provenance.test.mjs"
        status: pass
    human_judgment: false
  - id: D2
    description: "Both ledger-specific malformed fixtures fail for named provenance defects while clean ledgers pass."
    requirement: GREEN-01
    verification:
      - kind: other
        ref: "Phase 230 archived and Phase 236 clean substitutions plus both committed negative controls"
        status: pass
    human_judgment: false
  - id: D3
    description: "The standing Fast checks route and Phase 236 security closure are pinned by an independent ExUnit contract."
    requirement: GREEN-02
    verification:
      - kind: unit
        ref: "MIX_ENV=test mix test test/sigra/planning/phase_236_evidence_provenance_guard_test.exs"
        status: pass
    human_judgment: false
duration: 30min
completed: 2026-09-19
status: complete
---

# Phase 236 Plan 05 Summary

**Phase 236’s flake RED/GREEN ledger is now protected by the existing offline Fast checks provenance guard, with both high-severity repudiation findings closed.**

## Accomplishments

- Generalized p12 into a dual-ledger guard with independent 4/3 (Phase 230) and 3/3 (Phase 236) floors.
- Added a Phase 236 malformed-ledger fixture and an ExUnit contract that pins both ledger paths and the unchanged CI prohibition glob.
- Recorded the Fast checks receipt for the p17 observation and closed T-236-03/T-236-15 only after the deterministic matrix passed.

## Task Commits

1. **Task 1: Dual-ledger guard and run-backed ledger** — `1278b05e`, `a5d3a921`
2. **Task 2: Independent contract and matrix** — `5cceceea`
3. **Task 3: Security closure** — `37ea4499`

## Verification

- Default p12: 12/12 passing checks.
- Full prohibition suite: 112/112 passing checks.
- Focused ExUnit contract: 5/5 passing tests.
- Both clean ledger substitutions pass; both committed known-bad fixtures fail with named provenance violations.

## Deviations from Plan

The Phase 230 direct substitution path had been archived. The guard’s default path remains archive-aware; the explicit clean-subject verification used `.planning/milestones/v1.47-phases/230-tier-1-critical-path-reclamation/230-EVIDENCE.md`, preserving the injected-subject fail-fast contract.

## Next Phase Readiness

The Phase 236 evidence claims now have recurring CI enforcement without workflow changes, network access in the guard, or a `mix ci` topology change.
