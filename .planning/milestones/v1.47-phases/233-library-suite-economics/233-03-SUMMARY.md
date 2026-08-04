---
phase: 233-library-suite-economics
plan: 03
subsystem: ci
tags: [github-actions, exunit, postgres, scaffold, required-check]
requires:
  - phase: 233-library-suite-economics
    plan: 01
    provides: deterministic same-run ExUnit timing formatter and ordinary-shard receipts
  - phase: 233-library-suite-economics
    plan: 02
    provides: retry-free timing-probe baseline and per-file cost evidence
provides:
  - Universal Postgres-backed scaffold test receiver
  - Exact six-module ExUnit scaffold classification
  - Fail-closed two-input Library tests aggregate
affects: [233-04, 233-05, TEST-03, ci-workflow]
tech-stack:
  added: []
  patterns:
    - Unconditional receiving lane for extracted expensive test classes
    - Exact-success aggregation of CI dependency results through environment variables
key-files:
  created: []
  modified:
    - .github/workflows/ci.yml
    - test/sigra/planning/phase_233_library_economics_contract_test.exs
    - test/upgrade_test.exs
    - test/sigra/install/golden_diff_test.exs
    - test/sigra/install/idempotency_test.exs
    - test/sigra/install/generator_passkeys_opt_out_test.exs
    - test/sigra/install/features/passkeys_js_test.exs
    - test/sigra/install/vault_promotion_test.exs
key-decisions:
  - "Run the scaffold receiver on every event reached by release_ref_guard, with no paths/docs-only/event predicate."
  - "Keep the required context name Library tests and fail it unless both ordinary shards and scaffold receiver report exact success."
  - "Classify only the six InstallFixture-heavy modules; template_render_test.exs remains async and ordinary."
patterns-established:
  - "CI receiver pattern: extract a tag-selected class only after adding an unconditional Postgres-backed receiver and fail-closed aggregate."
requirements-completed: []
metrics:
  duration: 5m
  tasks_completed: 2
  files_modified: 8
completed: 2026-07-31
status: complete
---

# Phase 233 Plan 03: Scaffold Receiver and Required Aggregate Summary

**The six expensive Phoenix scaffold tests now run in an unconditional Postgres-backed receiver, while the byte-identical `Library tests` required context rejects any non-success ordinary or scaffold result.**

## Accomplishments

- Added module-level `:scaffold` tags to upgrade, golden diff, idempotency, passkeys opt-out, passkeys JS, and vault promotion tests without changing their test bodies, fixtures, timeouts, async modes, or existing tags.
- Added `library_tests_scaffold`, including strict Beam setup, shared library cache dimensions, Postgres, `phx_new`, same-run timing receipt, and retained scaffold timing artifact.
- Excluded scaffold tests only from ordinary shard execution, and extended the unchanged `Library tests` context with an `if: always()` two-result exact-success check.
- Added focused ExUnit contracts for receiver topology, result fail-closure, initial hazard modules, exact six-module membership, and the explicit ordinary async template-render exclusion.

## Verification

- `mix test test/sigra/planning/phase_233_library_economics_contract_test.exs` — passed (6 tests, 0 failures).
- `git diff --check` — passed.
- `actionlint .github/workflows/ci.yml` — reports only five pre-existing shellcheck warnings outside the changed workflow blocks; focused workflow contract passed. Plan 05 remains the required observed pull-request execution gate.

## Task Commits

1. Task 1 RED — `8354ec35` test: add failing scaffold receiver contract
2. Task 1 GREEN — `b55d84f9` feat: require scaffold test receiver
3. Task 2 RED — `c3ac39ff` test: define exact scaffold module set
4. Task 2 GREEN — `07e6f65f` feat: complete scaffold test classification

## Decisions Made

- The receiving lane intentionally has no path, docs-only, or event predicate; `release_ref_guard` remains its sole dependency.
- Both dependency result values are mapped through `env:` and checked with quoted strict-shell comparisons, making missing, skipped, cancelled, and failed results non-success.
- The ordinary suite keeps `template_render_test.exs`, which remains `async: true`, `:install`, and untagged as scaffold.

## Deviations from Plan

None - plan executed exactly as written.

## Known Stubs

None.

## Issues Encountered

The local test helper logged unavailable PostgreSQL connections during startup, but the focused static workflow contract completed with no skipped or failed assertions. GitHub-hosted Postgres-backed execution is intentionally proven by Plan 05's retry-free pull-request observation.

## Next Phase Readiness

Plan 04 can rebalance ordinary shards knowing the six-module scaffold class is excluded and continuous coverage remains merge-blocking. Plan 05 must observe the receiver, both ordinary shards, their timing artifacts, and the exact required aggregate on a real pull request.

## Self-Check: PASSED

- Confirmed the eight planned workflow/test artifacts exist and all four task commits are reachable in git history.
- Confirmed the TDD gate order: RED commits `8354ec35` and `c3ac39ff` precede GREEN commits `b55d84f9` and `07e6f65f`.
