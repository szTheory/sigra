---
phase: 137-optional-dependency-source-of-truth
plan: 01
subsystem: auth
tags: [optional-deps, source-of-truth, encryption, oban, assent, hammer, bcrypt, joken]

# Dependency graph
requires: []
provides:
  - "Sigra.OptionalDeps module: 9 flat zero-arity availability predicates for Oban, Bcrypt, EQRCode, Threadline, Assent, Swoosh, Joken, Hammer, Req"
  - "encryption_active?/1 predicate mirroring config-driven stub-vs-vault encryption posture check"
  - "Unit test file asserting drift-catching equality for all 9 predicates + 3 encryption cases"
affects:
  - "137-02 (Wave 2 delegation — plan will delegate Bucket A call sites to use this SOT)"
  - "137-03 (Wave 2 compound guard delegation)"
  - "phase-138 (mix sigra.doctor — consumes this SOT module)"
  - "phase-140 (PROOF-01/DOC-01 verifier checks @moduledoc scope strings)"

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Flat predicate SOT module: one Code.ensure_loaded?(Mod) wrapper per optional dep — no caching, no ETS, no persistent_term (D-01, D-03)"
    - "Config-driven encryption posture: mirror __sigra_encryption_mode__/0 NOT Code.ensure_loaded?(Cloak) (D-07)"
    - "Drift-catching test tautology: assert predicate() == Code.ensure_loaded?(Mod) stays valid in dep-on and dep-off CI lanes"

key-files:
  created:
    - lib/sigra/optional_deps.ex
    - test/sigra/optional_deps_test.exs
  modified: []

key-decisions:
  - "D-05 @moduledoc scope note: runtime call-site guards only; defmodule wrappers (workers/*.ex, audit/forwarders/threadline.ex) stay literal (D-04, compile-ordering circularity risk)"
  - "D-07 encryption predicate: config-driven __sigra_encryption_mode__() != :stub check, NOT Code.ensure_loaded?(Cloak) — avoids silent encryption-disabled regression (ASVS V6)"
  - "D-10: no new no_warn_undefined entries in mix.exs — Code.ensure_loaded?/1 takes module atoms and emits no compile warnings"
  - "Open Question 1 default: application.ex:77 boot-warning Code.ensure_loaded?(Oban) left literal; noted in @moduledoc"

patterns-established:
  - "SOT predicate shape: @spec name() :: boolean() + def name, do: Code.ensure_loaded?(Mod) — nine instances"
  - "Private encrypted_binary_module/1 helper mirrors application.ex:218-230 exactly for encryption posture derivation"
  - "In-test fixture modules (StubVault.Encrypted.Binary / RealVault.Encrypted.Binary) for encryption_active?/1 tests"

requirements-completed: [OD-01]

# Metrics
duration: 5min
completed: 2026-05-29
---

# Phase 137 Plan 01: OptionalDeps SOT Module Summary

**`Sigra.OptionalDeps` established as single-source-of-truth for 9 optional-dep availability predicates plus config-driven `encryption_active?/1`, closing the Wave 0 test gap from VALIDATION.md**

## Performance

- **Duration:** ~5 min
- **Started:** 2026-05-29T12:21:29Z
- **Completed:** 2026-05-29T12:26:07Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments

- Created `Sigra.OptionalDeps` with 9 flat zero-arity `Code.ensure_loaded?/1` wrappers for Oban, Bcrypt, EQRCode, Threadline, Assent, Swoosh, Joken, Hammer, and Req
- Implemented `encryption_active?/1` mirroring `application.ex:184-230` `__sigra_encryption_mode__() != :stub` config check (D-07 — no `Code.ensure_loaded?(Cloak)`)
- Added D-05 `@moduledoc` scope note with "runtime" and "compile-time" scope boundaries, `defmodule`-wrapper out-of-scope note, and Open Question 1 acknowledgement
- Created SOT unit test file closing the Wave 0 gap from 137-VALIDATION.md: 9 drift-catching equality assertions + 3 encryption fixture cases (stub→false, vault→true, missing→false)
- `mix compile --warnings-as-errors` exits 0; `mix test test/sigra/optional_deps_test.exs` exits 0 (12 tests, 0 failures); `git diff mix.exs` empty (D-10)

## Task Commits

1. **Task 1: Create Sigra.OptionalDeps module** - `de3f3f8` (feat)
2. **Task 2: Create SOT unit test file** - `8b59943` (test)

## Files Created/Modified

- `lib/sigra/optional_deps.ex` — `Sigra.OptionalDeps` SOT: 9 availability predicates + `encryption_active?/1` + private `encrypted_binary_module/1` helper; D-05 `@moduledoc` scope note
- `test/sigra/optional_deps_test.exs` — drift-catching unit tests: 9 equality assertions + 3 encryption cases with in-test fixture modules

## Decisions Made

- `encryption_active?/1` uses `!= :stub` (not `== :vault`) matching `application.ex:194` which only checks `== :stub` — semantics are stub-vs-everything-else
- `swoosh_available?/0` and `req_available?/0` created for SOT completeness/Phase-138 despite having no in-scope delegation target (Swoosh's only `lib/` guard is out-of-scope `testing.ex:98`; Req's compound guard is plan 03 scope)
- Worktree required `deps` symlink to main project `deps/` for compilation; `_build` created fresh in worktree

## Deviations from Plan

None — plan executed exactly as written.

## Issues Encountered

The worktree had no `deps` directory. Resolved by creating a symlink `deps -> /Users/jon/projects/sigra/deps`. The `_build` directory was created fresh by the compiler in the worktree (normal worktree behavior).

## User Setup Required

None — no external service configuration required.

## Next Phase Readiness

- `Sigra.OptionalDeps` is ready to consume: Wave 2 delegation plans (137-02/137-03) can now replace Bucket A `Code.ensure_loaded?/1` call sites with `Sigra.OptionalDeps.<dep>_available?()` one-to-one
- Phase 138 (`mix sigra.doctor`) has a stable, queryable SOT surface
- Phase 140 verifier can check `@moduledoc` for D-04/D-05 scope strings

## Threat Flags

None — internal refactor with no new external input boundaries. `encryption_active?/1` mitigates T-137-01 (encryption-disabled silent regression) as planned via config-driven check.

## Self-Check

- [x] `lib/sigra/optional_deps.ex` exists: YES
- [x] `test/sigra/optional_deps_test.exs` exists: YES
- [x] commit `de3f3f8` exists: YES
- [x] commit `8b59943` exists: YES

## Self-Check: PASSED

---
*Phase: 137-optional-dependency-source-of-truth*
*Completed: 2026-05-29*
