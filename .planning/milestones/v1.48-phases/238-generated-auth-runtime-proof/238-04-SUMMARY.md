---
phase: 238-generated-auth-runtime-proof
plan: 04
subsystem: testing
tags: [github-actions, playwright, postgres, generated-auth, source-contract]
requires:
  - phase: 238-03
    provides: Complete serial generated-host B2C auth journey, OAuth collision proof, and scoped accessibility gates.
provides:
  - Isolated generated-auth Desktop Chromium Playwright partition.
  - Direct PostgreSQL/Chromium CI runtime-proof lane with retained diagnostics.
  - Fast source locks for the fresh-host OAuth, mailbox, journey, accessibility, and CI contracts.
affects: [238-05, AUTH-01, AUTH-02, AUTH-03, ci]
tech-stack:
  added: []
  patterns: [exclusive Playwright partition, credential-free loopback CI proof, source-locked CI configuration]
key-files:
  created:
    - test/sigra/planning/phase_238_generated_auth_runtime_proof_test.exs
  modified:
    - test/example/priv/playwright/playwright.config.ts
    - scripts/ci/generated-auth-runtime-proof.sh
    - .github/workflows/ci.yml
key-decisions:
  - "Generated auth remains a direct CI signal outside the legacy skip-tolerant ci-gate."
  - "One fresh host executes both allowlisted generated-auth specs through the exclusive generated-auth project."
  - "Runtime artifacts retain report, test-result, and server-log paths with warning-only missing-file handling."
patterns-established:
  - "Generated-host browser tests must be excluded from example-host projects and selected only by their dedicated project."
requirements-completed: [AUTH-01, AUTH-02, AUTH-03]
coverage:
  - id: D1
    description: Dedicated generated-auth Playwright partition excludes disposable-host specs from generic example-app projects.
    requirement: AUTH-01
    verification:
      - kind: unit
        ref: test/sigra/planning/phase_238_generated_auth_runtime_proof_test.exs#Generated Auth Runtime Proof isolates the complete suite in its own Chromium project
        status: pass
      - kind: automated_ui
        ref: playwright --list --project=generated-auth
        status: pass
    human_judgment: false
  - id: D2
    description: PostgreSQL and Chromium CI lane runs the fresh generated-host lifecycle plus both auth specs without provider credentials.
    requirement: AUTH-02
    verification:
      - kind: unit
        ref: test/sigra/planning/phase_238_generated_auth_runtime_proof_test.exs#Generated Auth Runtime Proof CI lane is non-skipping PostgreSQL-backed and diagnostic
        status: pass
      - kind: e2e
        ref: GITHUB_WORKSPACE="$PWD" scripts/ci/generated-auth-runtime-proof.sh --all
        status: unknown
    human_judgment: false
  - id: D3
    description: Source locks cover the local OAuth double, observable mailbox polling, complete journey states, and scoped accessibility assertions.
    requirement: AUTH-03
    verification:
      - kind: unit
        ref: test/sigra/planning/phase_238_generated_auth_runtime_proof_test.exs#Generated Auth Runtime Proof locks the local OAuth mailbox journey and accessibility evidence
        status: pass
    human_judgment: false
duration: 8min
completed: 2026-08-05
status: complete
---

# Phase 238 Plan 04: Generated Auth Runtime Proof Summary

**Dedicated Chromium Playwright partition and PostgreSQL CI lane for the complete credential-free generated B2C authentication proof.**

## Performance

- **Duration:** 8 min
- **Started:** 2026-08-05T11:10:00-04:00
- **Completed:** 2026-08-05T11:14:00-04:00
- **Tasks:** 2
- **Files modified:** 5

## Accomplishments

- Isolated both generated-auth specs in a desktop Chromium `generated-auth` project; generic Chromium and mobile example-app projects explicitly ignore them.
- Added `generated_auth_runtime_proof`, an unconditional direct CI job with PostgreSQL 15, strict Beam setup, pinned `phx_new` 1.8.8, npm/Chromium setup, and no provider or email credentials.
- Added deterministic source contracts for project partitioning, OAuth double flags/routes, mailbox polling, full rendered state/accessibility coverage, workflow execution, and artifacts.
- Preserved server diagnostics before the disposable fresh host is removed and uploads report, test results, and server diagnostics with main/non-main retention.

## Task Commits

1. **Task 1: Isolate and source-lock the generated-auth Playwright project** - `6913b65f` (test), `191dfa4c` (feat)
2. **Task 2: Add the PostgreSQL-backed generated-auth CI lane and artifacts** - `13a9f12e` (feat)

## Files Created/Modified

- `test/example/priv/playwright/playwright.config.ts` - Dedicated generated-auth project and generic-project exclusion.
- `scripts/ci/generated-auth-runtime-proof.sh` - Runs both allowlisted specs in the isolated project and preserves server diagnostics.
- `.github/workflows/ci.yml` - Direct PostgreSQL/Chromium proof lane and branch-aware artifact retention.
- `test/sigra/planning/phase_238_generated_auth_runtime_proof_test.exs` - Fast, non-vacuous source contracts for the full proof chain.

## Decisions Made

- Kept the lane outside `ci-gate`: adding it to that legacy skip-tolerant aggregator would require coordinated honest-skip and terminal-ratification contract changes, while this job must remain a direct evidence signal.
- Used one fresh generated host for both allowlisted specs, maintaining a bounded runtime while proving both full email/OAuth/accessibility journey and focused OAuth state/PKCE behavior.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking integration] Made the prescribed isolated full-proof command executable**
- **Found during:** Task 1
- **Issue:** The harness still ran its selected spec via generic `chromium` and exposed no `--all` selector, so the required dedicated-project CI command could not run both generated-auth specs.
- **Fix:** Switched the harness to `--project=generated-auth`, added an explicit two-spec `--all` allowlist, and copied server diagnostics before temporary-host cleanup.
- **Files modified:** `scripts/ci/generated-auth-runtime-proof.sh`
- **Verification:** `bash -n`, source contract, and Playwright `--list` discovered exactly two generated-auth tests.
- **Committed in:** `191dfa4c`, `13a9f12e`

**Total deviations:** 1 auto-fixed (Rule 3).

## Issues Encountered

- Local PostgreSQL and Chromium are unavailable, so the fresh-host browser runtime was not claimed as passing. Plan 05 must record green exact-commit CI evidence.
- `npx tsc --noEmit` cannot run because this checkout has no installed TypeScript CLI; Playwright's installed CLI successfully parsed the TypeScript config and listed both dedicated-project tests without downloading dependencies.
- `actionlint` reported only pre-existing shellcheck warnings elsewhere in `ci.yml`; no new workflow errors were reported.

## Known Stubs

None.

## User Setup Required

None - CI provisions PostgreSQL and Chromium and uses only the harness's loopback dummy provider configuration.

## Next Phase Readiness

- Plan 05 can correlate the direct `Generated auth runtime proof` job's green result to the exact commit and record runtime evidence.
- Runtime proof remains pending until that CI job completes successfully; source-contract and Playwright discovery checks alone are not runtime evidence.

## Self-Check: PASSED

- Found all planned files plus the task-scoped harness diagnostic update.
- Found commits `6913b65f`, `191dfa4c`, and `13a9f12e` in git history.
- `MIX_ENV=test mix test test/sigra/planning/phase_238_generated_auth_runtime_proof_test.exs` passed (3 tests); YAML parsing, `bash -n`, Playwright project discovery, and `git diff --check` passed.

---
*Phase: 238-generated-auth-runtime-proof*
*Completed: 2026-08-05*
