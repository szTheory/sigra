---
phase: 234-hygiene-supply-chain-and-contributor-dx
plan: 01
subsystem: ci
tags: [mix, github-actions, contributor-dx, formatter]
requires:
  - phase: 233-library-suite-economics
    provides: protected Library tests aggregation and CI gate wiring
provides:
  - one seven-leg `mix ci` command shared by contributors and the PR library suite
  - fail-closed contracts for alias order, formatter ownership, and CI suite ownership
affects: [mix.exs, .github/workflows/ci.yml, CONTRIBUTING.md]
tech-stack:
  added: []
  patterns: [ExUnit structural contracts, fixed GitHub Actions env mappings]
key-files:
  created: []
  modified:
    - .formatter.exs
    - mix.exs
    - .github/workflows/ci.yml
    - test/sigra/planning/phase_198_contributor_dx_contract_test.exs
    - test/sigra/planning/phase_233_library_economics_contract_test.exs
    - CONTRIBUTING.md
decisions:
  - "library_tests_shard is the sole full-suite owner and invokes literal MIX_ENV=test mix ci once."
  - "Generated install-golden tree bytes are outside formatter ownership; CSS and prohibition fixtures remain covered."
metrics:
  duration: 7m
  completed: 2026-07-31
status: complete
---

# Phase 234 Plan 01: Contributor CI Parity Summary

`mix ci` now performs the locked seven-leg contributor gate and is invoked directly once by the sole PR library-suite owner.

## Tasks Completed

1. Added a RED/GREEN structural contract that locks alias order, format ownership, a sole direct CI invocation, protected aggregation, and the docs-only dep-off lane boundary.
2. Updated contributor instructions with all seven legs, required Postgres and `phx_new 1.8.8` setup, the direct CI host, retry-free parity, and optional-tool exclusions.

## Verification

- RED observed: focused Phase 198/233 contracts failed in six assertions before implementation.
- `mix test test/sigra/planning/phase_198_contributor_dx_contract_test.exs test/sigra/planning/phase_233_library_economics_contract_test.exs` — 8 tests passed.
- `mix format --check-formatted .formatter.exs mix.exs test/sigra/planning/phase_198_contributor_dx_contract_test.exs test/sigra/planning/phase_233_library_economics_contract_test.exs` — passed.
- `git diff --check` — passed.

## Decisions Made

- `library_tests_shard` owns the complete suite through literal `MIX_ENV=test mix ci`; `Library tests` preserves its required-check name and always-running aggregation.
- The formatter uses explicit non-golden fixture globs, preventing any `test/fixtures/install_golden/tree/**` byte churn.

## Deviations from Plan

None - plan executed exactly as written.

## Known Stubs

None.

## Self-Check: PASSED

- Confirmed all six implementation/documentation files and this summary exist.
- Confirmed task commits `7f5b8bb1`, `283ae705`, and `0c5d5bf8` exist in git history.
