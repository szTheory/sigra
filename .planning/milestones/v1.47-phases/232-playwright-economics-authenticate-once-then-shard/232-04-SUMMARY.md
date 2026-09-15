---
phase: 232-playwright-economics-authenticate-once-then-shard
plan: 04
subsystem: ci
tags: [github-actions, composite-action, playwright, phoenix]
requires:
  - phase: 232-playwright-economics-authenticate-once-then-shard
    provides: sealed PW-01 receipt before topology changes
provides:
  - One parameterized example Playwright boot action
  - Four consumers wired to identical compile/database/browser/boot/readiness behavior
affects: [232-05, 232-06, github-actions]
key-files:
  created:
    - .github/actions/example-playwright-boot/action.yml
    - .planning/phases/232-playwright-economics-authenticate-once-then-shard/232-04-SUMMARY.md
  modified:
    - .github/workflows/ci.yml
    - test/sigra/planning/phase_232_playwright_economics_test.exs
key-decisions:
  - "Keep one SHA-pinned checkout in each caller because a repository-local action cannot load before checkout; centralize every subsequent setup step."
  - "Expose database, port, base URL, log, browsers, cache, and warmup paths as explicit action inputs."
requirements-completed: [PW-03]
duration: 8min
completed: 2026-07-31
status: complete
---

# Phase 232 Plan 04: Shared Example Boot Summary

**All four example-app Playwright consumers now use one composite action for toolchains, caches, compile, database lifecycle, seeds, browser installation, Phoenix boot, bounded readiness, and route warmup.**

## Accomplishments

- Added `.github/actions/example-playwright-boot/action.yml` with explicit isolation and runtime inputs.
- Replaced duplicate preludes in `example_playwright_smoke`, both recapture jobs, and `admin_eval_render`.
- Preserved job services, permissions, event gates, timeouts, artifacts, browser sets, ports, logs, and test commands.
- Added a non-vacuous four-consumer one-definition contract using job-scoped assertions.

## Verification

- Focused Phase 232 suite: 5 tests, 0 failures.
- Full planning suite: 59 tests, 0 failures, 12 skipped.
- YAML lint: passed.

## Deviations

- Caller checkout remains outside the composite action because GitHub must check out a repository before a local `./.github/actions/...` action can be resolved. This is the required bootstrap boundary, not a second boot definition.

## Self-Check: PASSED

- Canonical migrate/seed/boot/readiness markers occur only in the shared action for the four consumers.
- No application UI, package manifest, lockfile, or runtime auth-prefix setting changed.
