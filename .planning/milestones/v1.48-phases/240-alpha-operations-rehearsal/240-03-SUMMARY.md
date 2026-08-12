---
phase: 240-alpha-operations-rehearsal
plan: "03"
subsystem: operations
tags: [b2c, operations, deployment, security, documentation, exunit]
requires:
  - phase: 240-05
    provides: Wave 0 RED operations-evidence source contract
  - phase: 240-01
    provides: Generated host rate-limit defaults and bounded retry contract
provides:
  - One provider-neutral B2C launch checklist with CI, host pre-deploy, and staging evidence tiers
  - A redacted, outcome-only staging receipt schema and explicit host-only claim boundaries
  - Executable documentation checks for tuple, Doctor, Google, device, delivery, and receipt requirements
affects: [b2c-alpha, deployment, OPS-01, OPS-02]
tech-stack:
  added: []
  patterns: [three-tier evidence model, outcome-only operator receipts, source-contract documentation testing]
key-files:
  created: []
  modified:
    - guides/recipes/b2c-alpha.md
    - guides/recipes/deployment.md
    - test/sigra/planning/phase_240_alpha_operations_rehearsal_test.exs
key-decisions:
  - "b2c-alpha.md is the sole B2C readiness checklist; deployment.md is a linked mechanics reference."
  - "Repository CI proves generated local behavior only; provider, mail, proxy, and physical-device outcomes require redacted host evidence."
  - "The canonical host posture is one HTTPS origin with a host-only Secure, HttpOnly, SameSite=Lax session cookie."
requirements-completed: [OPS-01, OPS-02]
coverage:
  - id: D1
    description: Three-tier B2C checklist, secure tuple, truthful Doctor boundary, and staging gate requirements.
    requirement: OPS-01
    verification:
      - kind: unit
        ref: test/sigra/planning/phase_240_alpha_operations_rehearsal_test.exs
        status: pass
      - kind: other
        ref: mix docs --warnings-as-errors
        status: pass
    human_judgment: false
  - id: D2
    description: Outcome-only redacted receipt and no repository-pass promotion for host-only provider, mail, and device evidence.
    requirement: OPS-02
    verification:
      - kind: unit
        ref: test/sigra/planning/phase_240_alpha_operations_rehearsal_test.exs#the receipt schema is outcome-only and cannot become a secret or payload record
        status: pass
    human_judgment: false
metrics:
  duration: 5min
  completed: 2026-08-10
status: complete
---

# Phase 240 Plan 03: B2C Operations Checklist Summary

**A single provider-neutral B2C launch checklist now separates credential-free CI proof from secure host wiring and mandatory, redacted staging evidence.**

## Accomplishments

- Replaced the informal alpha rehearsal with three structured evidence tiers whose rows name an owner, expected result, claim boundary, and recovery action.
- Recorded the literal HTTPS origin, Endpoint, trusted-proxy, and host-only Secure/HttpOnly/SameSite=Lax session tuple.
- Made real Google, controlled-recipient confirmation/reset/magic-link delivery, and physical-iPhone hosted return mandatory staging checks that CI cannot pass.
- Added an outcome-only receipt schema and source-contract assertions that prevent it from becoming a secret or payload record.
- Reframed the deployment guide as linked detailed mechanics rather than a competing B2C launch checklist.

## Task Commits

1. **Task 1: Lock the three-tier launch checklist and redacted evidence contract** — `23af313c` (feat)

## Verification

- PASS — initial Wave 0 source-contract run was RED: 5 failing evidence-contract assertions before documentation implementation.
- PASS — `mix test test/sigra/planning/phase_240_alpha_operations_rehearsal_test.exs` (6 tests).
- PASS — `mix docs --warnings-as-errors`.
- PASS — `git diff --check`.

The focused ExUnit run logs connection-refused noise for the unavailable shared test PostgreSQL endpoint during application startup; all selected source-contract tests passed independently of it.

## Files Modified

- `guides/recipes/b2c-alpha.md` — canonical three-tier B2C launch rehearsal, tuple, staging gates, and receipt format.
- `guides/recipes/deployment.md` — mechanics-only framing and a cross-link to the canonical checklist.
- `test/sigra/planning/phase_240_alpha_operations_rehearsal_test.exs` — receipt-schema negative contract in addition to Wave 0 tier assertions.

## Decisions Made

- The limiter section documents the generated three-per-60-second default as host-overridable, and records ceiling-rounded whole-second Retry-After behavior without claiming provider sub-second timing.
- Doctor is documented strictly as configuration/dependency wiring evidence; deployment, external credentials, delivery, and device behavior remain host-owned proof.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Documentation build] Corrected generated documentation link targets**
- **Found during:** Task 1
- **Issue:** The source-contract-required `b2c-alpha.md` reference was used as an ExDoc link, which generated a warnings-as-errors failure because documentation links resolve to HTML output.
- **Fix:** Retained the required source-file mention as literal text and used `b2c-alpha.html` for rendered documentation links.
- **Files modified:** `guides/recipes/deployment.md`
- **Verification:** `mix docs --warnings-as-errors` passes.
- **Committed in:** `23af313c`

**Total deviations:** 1 auto-fixed (1 Rule 1). **Impact:** Documentation-link correction only; checklist semantics remain unchanged.

## Known Stubs

None.

## Threat Flags

None — this plan adds documentation and source contracts only; its configured proxy, cookie, receipt, and claim-boundary mitigations directly address the plan threat register.

## Next Phase Readiness

The operations-evidence Wave 0 contract is green. The no-secrets CI ownership work in Plan 240-04 can rely on this recipe’s explicit boundary that CI may require but cannot pass host-only staging evidence.

## Self-Check: PASSED

- All three planned task files exist.
- Task commit `23af313c` exists in git history.
- The plan verification commands pass.
