---
phase: 95-optional-dep-boot-validation-mix-sigra-doctor-hard-02
plan: 1
subsystem: auth
tags: [optional-deps, jwt, joken, diagnostics, elixir]
requires: []
provides:
  - "Authoritative optional dependency registry with enforced and advisory feature metadata"
  - "Tagged missing dependency exception with structured fields for Sigra runtime failures"
  - "JWT signer baseline routed through the shared registry contract"
affects: [mix-sigra-doctor, compile-warnings, jwt, optional-dependencies]
tech-stack:
  added: []
  patterns: [registry-backed optional dependency policy, tagged runtime dependency errors]
key-files:
  created:
    - lib/sigra/optional_deps.ex
    - lib/sigra/optional_deps/missing_dependency_error.ex
    - test/sigra/optional_deps_test.exs
  modified:
    - lib/sigra/jwt/signer.ex
    - test/sigra/jwt/signer_test.exs
key-decisions:
  - "Modeled optional dependencies as staged feature specs with per-feature enablement evidence and remediation copy."
  - "Kept Hammer, Assent, and Swoosh centralized as advisory rows so they inform doctor output without becoming Phase 95 blockers."
  - "Preserved ensure_joken!/0 as the public JWT boundary while delegating enforcement to Sigra.OptionalDeps."
patterns-established:
  - "Optional dependency callers should use Sigra.OptionalDeps.ensure_available!/2 instead of ad hoc Code.ensure_loaded? guards."
  - "Missing dependency exceptions should expose feature, dependency, spec, evidence, and remediation fields for stable assertions."
requirements-completed: [HARD-02]
duration: 8 min
completed: 2026-04-30
---

# Phase 95 Plan 1: Optional Dependency Registry Summary

**Optional dependency registry with tagged Sigra errors and a JWT signer migrated onto the shared Joken contract**

## Performance

- **Duration:** 8 min
- **Started:** 2026-04-30T20:51:59Z
- **Completed:** 2026-04-30T20:59:01Z
- **Tasks:** 2
- **Files modified:** 5

## Accomplishments

- Added `Sigra.OptionalDeps` as the single source of truth for enforced Phase 95 features and advisory optional integrations.
- Added `Sigra.OptionalDeps.MissingDependencyError` with structured fields and Sigra-branded remediation copy.
- Migrated `Sigra.JWT.Signer.ensure_joken!/0` to the registry contract and verified the `:jwt` entry remains host-proven instead of speculative.

## Task Commits

Each task was committed atomically:

1. **Task 1: Create the registry and tagged missing-dependency error** - `973e0e6` (`feat`)
2. **Task 2: Migrate the JWT baseline onto the registry-backed contract** - `d437fa6` (`feat`)

## Files Created/Modified

- `lib/sigra/optional_deps.ex` - Registry entries, enablement/evidence helpers, availability checks, and doctor rows.
- `lib/sigra/optional_deps/missing_dependency_error.ex` - Structured Sigra exception for missing optional dependencies.
- `lib/sigra/jwt/signer.ex` - Registry-backed `ensure_joken!/0` boundary for JWT signing.
- `test/sigra/optional_deps_test.exs` - Coverage for staged registry metadata, tagged errors, and advisory versus enforced behavior.
- `test/sigra/jwt/signer_test.exs` - Coverage for the JWT path remaining explicit while using the shared registry seam.

## Decisions Made

- The registry stores staged metadata per feature so runtime checks, doctor rows, and later warning work can share one policy source.
- Advisory rows remain non-blocking when inactive, which preserves optionality for Hammer, Assent, and Swoosh while still centralizing their metadata now.
- `ensure_joken!/0` treats invocation itself as proof of active JWT use, so it can preserve its public API while emitting the shared optional-dependency contract.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

- The first registry implementation used a module attribute to hold local callback references, which Elixir rejected at compile time. Moving the registry into a private function kept the API unchanged and resolved the compilation issue before Task 1 verification.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Later Phase 95 plans can consume `Sigra.OptionalDeps` for doctor output, compile-warning proofs, and additional runtime boundary rewrites.
- The `:jwt` path is now the baseline production consumer for the shared optional-dependency contract.

## Self-Check

PASSED

- Found `.planning/phases/95-optional-dep-boot-validation-mix-sigra-doctor-hard-02/95-01-SUMMARY.md`.
- Verified task commits `973e0e6` and `d437fa6` in `git log --oneline --all`.

---
*Phase: 95-optional-dep-boot-validation-mix-sigra-doctor-hard-02*
*Completed: 2026-04-30*
