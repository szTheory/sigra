---
phase: 232-playwright-economics-authenticate-once-then-shard
plan: 05
subsystem: ci
tags: [github-actions, matrix, playwright, isolation, branch-protection]
requires:
  - phase: 232-playwright-economics-authenticate-once-then-shard
    provides: shared boot action from Plan 232-04
provides:
  - Five runner-isolated Playwright shard seams
  - Retry-zero commands and an exact-name fail-closed terminal verdict
affects: [232-06, 232-07, ci-gate]
key-files:
  created:
    - .planning/phases/232-playwright-economics-authenticate-once-then-shard/232-05-SUMMARY.md
  modified:
    - .github/workflows/ci.yml
    - test/example/priv/playwright/playwright.config.ts
    - test/sigra/planning/phase_232_playwright_economics_test.exs
key-decisions:
  - "Use one five-row matrix job plus one stable terminal job; each matrix leg owns a runner, PostgreSQL service, database, Phoenix port, base URL, and log."
  - "Keep each invocation internally serial while removing global cross-seam serialization."
  - "Run design behavior on PRs and both behavior plus tagged snapshots on non-PR events."
requirements-completed: [PW-02, PW-03]
duration: 7min
completed: 2026-07-31
status: complete
---

# Phase 232 Plan 05: Isolated Playwright Shards Summary

**Five independently owned Playwright seams now execute as concurrent matrix jobs and converge on the unchanged protected `Example Playwright smoke (full lifecycle)` result.**

## Accomplishments

- Added explicit `admin_behavior`, `admin_checkpoints`, `design_gallery`, `non_admin_smoke`, and `demo_showcase` matrix rows with `fail-fast: false`.
- Assigned unique databases, ports/base URLs, and server logs while using the shared boot action in every leg.
- Added `--retries=0` to every shard invocation and set the global Playwright retry default to zero.
- Preserved PR/non-PR design snapshot routing, curated checkpoint artifacts, diagnostics, docs-only behavior, and existing `ci-gate` dependency wiring.
- Converted the original job ID into a thin always-running fail-closed aggregator with the exact required display name.

## Verification

- Focused Phase 232 suite: 6 tests, 0 failures.
- Full planning suite: 60 tests, 0 failures, 12 skipped.
- Playwright inventory: 394 tests in 21 files, listing exits 0 with `--retries=0`.
- Workflow/action YAML lint: passed.

## Deviations

- Updated Phase 230 structural contracts to assert the new matrix/terminal topology rather than stale in-job step IDs and the obsolete 45-minute serial-job timeout.

## Self-Check: PASSED

- No shard uses `continue-on-error`, retry recovery, runtime auth-prefix overrides, shared database names, shared app ports, or shared log paths.
- Every matrix result reaches the exact-name terminal verdict through `needs.example_playwright_shard.result` under `if: always()`.
