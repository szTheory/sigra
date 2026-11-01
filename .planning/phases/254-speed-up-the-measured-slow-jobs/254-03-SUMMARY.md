---
phase: 254-speed-up-the-measured-slow-jobs
plan: "03"
subsystem: testing
tags: [playwright, admin-theme, auth-isolation, postgres, ci]
requires:
  - phase: 254-speed-up-the-measured-slow-jobs
    plan: "01"
    provides: Source-bound local preparation profile and isolated app setup pattern
  - phase: 254-speed-up-the-measured-slow-jobs
    plan: "02"
    provides: Exact browser case identities and native-result comparison conventions
provides:
  - Opt-in worker-scoped admin registration with invocation-private storage and a fresh consumer context per eligible test
  - Bounded browser checker for tracer, individual, file, state-controls, and all modes
  - Actual local-browser evidence for every eligible admin-theme case and the full original file
affects: [254-04, 254-07, ci, playwright]
actuals:
  tokens: 26335
  tasks: 2
  commits: 18
commits: 18
plan_head_before: f89de5b11a502b9034180446b15ba7777c9147c5
plan_head_after: 20614c85e929c19d52b9a6ffd9e909aff23aeeef
tech-stack:
  added: []
  patterns:
    - Invocation-only storage-state reuse with a fresh browser context per test
    - Fresh owned database per standalone browser invocation with explicit teardown
key-files:
  created:
    - test/example/priv/playwright/fixtures/adminTheme.ts
    - scripts/ci/ci-admin-theme-prep.test.mjs
    - scripts/ci/ci-admin-theme-check.mjs
    - .planning/phases/254-speed-up-the-measured-slow-jobs/254-ADMIN-THEME-CHECK.json
  modified:
    - test/example/priv/playwright/tests/admin-theme.spec.ts
key-decisions:
  - "Use an opt-in fixture only for the 18 presentation/navigation cases; leave the real lockout test on the anonymous default context."
  - "Keep authenticated storage in a unique mode-0600 file under ignored test-results/.auth and remove it at worker teardown."
  - "Reset saved branding through the real admin UI after branding tests; a new browser context alone does not reset backend state."
  - "Treat all browser timings as local development diagnostics; they do not establish either hosted speed target."
patterns-established:
  - "A fresh app/database and one-worker, zero-retry invocation can prove focused Playwright cases against isolated state."
  - "Retain native JSON exit/results and safe context metadata without recording cookies or storage bytes."
requirements-completed: []
requirements-supported: [CISPEED-01, CISPEED-02]
coverage:
  - id: D1
    description: "Eighteen eligible admin-theme cases reuse one invocation-local registration while receiving distinct browser contexts; the original product assertions and test names remain."
    requirement: CISPEED-01
    verification:
      - kind: unit
        ref: scripts/ci/ci-admin-theme-prep.test.mjs
        status: pass
      - kind: integration
        ref: ".planning/phases/254-speed-up-the-measured-slow-jobs/254-ADMIN-THEME-CHECK.json: all-mode individual-01 through individual-18"
        status: pass
      - kind: e2e
        ref: ".planning/phases/254-speed-up-the-measured-slow-jobs/254-ADMIN-THEME-CHECK.json: full-file, 19 passed / 0 failed / 0 skipped"
        status: pass
    human_judgment: false
  - id: D2
    description: "Real lockout, branding restoration, anonymous default projects, storage cleanup and workflow cache/upload exclusion remain checked on fresh local state."
    requirement: CISPEED-02
    verification:
      - kind: integration
        ref: ".planning/phases/254-speed-up-the-measured-slow-jobs/254-ADMIN-THEME-CHECK.json: lockout-control and state_controls"
        status: pass
      - kind: unit
        ref: scripts/ci/prohibitions/p17-no-playwright-retry-wrapper.test.mjs
        status: pass
    human_judgment: false
metrics:
  duration: 22m
  completed: 2026-10-23
  status: complete
---

# Phase 254 Plan 03: Invocation-local Admin Theme Preparation Summary

**The eligible admin-theme cases now reuse a freshly registered admin within one isolated run while preserving a fresh browser context and explicit backend cleanup for every case.**

## Performance

- **Duration:** 22 minutes
- **Started:** 2026-10-23T17:19:37Z
- **Completed:** 2026-10-23T17:41:56Z
- **Tasks:** 2
- **Files modified:** 5

## Accomplishments

- Added `adminThemeTest`, an opt-in worker fixture that registers through the real anonymous UI path, captures storage before theme changes, creates a new context per consumer, and deletes its unique mode-0600 storage file after the worker exits. Eighteen eligible tests use it; the real lockout case remains a regular `test` on the default anonymous context.
- Added a bounded checker with `tracer`, `individual`, `file`, `state-controls`, and `all` modes. It checks out the committed source into a disposable directory, uses Node 20.18.1 and Playwright 1.59.1, creates and drops uniquely named databases, retains native reports and exit codes, uses one worker and zero retries, and removes its scoped build/cache directories.
- All-mode local browser evidence passed: 18 of 18 eligible cases passed individually against fresh databases; the complete original file passed 19 of 19 with no skips; and the separate lockout control passed with five real failed login attempts. The full-file record contains 18 distinct consumer context IDs, one setup registration, storage mode `0600`, and completed cleanup.
- The checker found no remaining admin-theme auth files in Playwright output or scoped caches, and the workflow does not configure the auth path for upload or caching. All 20 generated databases were dropped. No hosted CI run or speed improvement claim is included.

## Task Commits

1. **Task 1 RED:** `8d4afe6e7` - specify isolated admin-theme auth fixture.
2. **Task 1 GREEN:** `96eaa9503` - add fixture, selected case migration, and bounded runner.
3. **Task 1 correction:** `8a12a761c` - scope source cleanliness to plan-owned files.
4. **Task 1 preserved first setup failure:** `86899475a` - retain initial blocked runner result.
5. **Task 1 correction:** `bc70855f6` - verify Playwright after `npm ci`.
6. **Task 1 preserved database setup failure:** `4b646529d` - retain isolated PostgreSQL setup result.
7. **Task 1 correction:** `1ec492551` - use only unique owned databases on the local PostgreSQL service.
8. **Task 1 preserved selection failure:** `0ada264a3` - retain native zero-selection result.
9. **Task 1 correction:** `bca4f4fc4` - match the unchanged case title under its suite title.
10. **Task 1 preserved sandbox browser failure:** `1a372b279` - retain native Chromium launch denial.
11. **Task 1 correction:** `cafd8073b` - drop an owned database after browser failure.
12. **Task 1 preserved default-sandbox result:** `fa3a73826` - retain browser denial and verified cleanup.
13. **Task 1 preserved first escalated product failure:** `91ef26f95` - retain the actual failed native result.
14. **Task 1 correction:** `51c68c3e7` - keep Task 2 state reset off the tracer path.
15. **Task 1 evidence:** `478139a99` - record the passing original tracer case.
16. **Task 2 RED:** `f7e9feedb` - require supported-UI branding restoration.
17. **Task 2 GREEN:** `3e4c67369` - add state restoration and full case/control modes.
18. **Task 2 evidence:** `20614c85e` - record standalone and whole-file browser outcomes.

## Files Created/Modified

- [adminTheme.ts](/Users/jon/projects/sigra/test/example/priv/playwright/fixtures/adminTheme.ts) - private invocation auth storage and per-test consumer contexts.
- [admin-theme.spec.ts](/Users/jon/projects/sigra/test/example/priv/playwright/tests/admin-theme.spec.ts) - uses the opt-in fixture for presentation/navigation tests and restores saved branding through the UI after branding cases.
- [ci-admin-theme-prep.test.mjs](/Users/jon/projects/sigra/scripts/ci/ci-admin-theme-prep.test.mjs) - fixture, anonymous-project, restoration, and runner contract checks.
- [ci-admin-theme-check.mjs](/Users/jon/projects/sigra/scripts/ci/ci-admin-theme-check.mjs) - bounded real-browser verification and safe result capture.
- [254-ADMIN-THEME-CHECK.json](/Users/jon/projects/sigra/.planning/phases/254-speed-up-the-measured-slow-jobs/254-ADMIN-THEME-CHECK.json) - final source-bound local browser record.

## Decisions Made

- The shared test suite stays one-worker/zero-retry. Only opted-in cases read the fixture's temporary storage; Chromium and mobile default projects remain anonymous.
- Browser contexts isolate browser state, so branding state is restored separately through the existing admin UI after each branding case.
- The local Postgres service was used only for generated per-run database names after sandboxed `initdb` could not allocate shared memory. The checker drops a database only after its own successful create.
- The record is local functional evidence, not hosted comparison evidence. CISPEED-01 and CISPEED-02 remain supported but incomplete until the authorized hosted comparison passes.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Scope the runner's clean-source guard to this plan's files**
- **Found during:** Task 1 tracer setup.
- **Issue:** The initial checker rejected the orchestrator-owned dirty `.planning/STATE.md` and `.planning/state.json`.
- **Fix:** Restrict the source check to the four owned implementation files while retaining committed-source identity.
- **Files modified:** `scripts/ci/ci-admin-theme-check.mjs`.
- **Committed in:** `8a12a761c`.

**2. [Rule 3 - Blocking] Check the pinned Playwright install after `npm ci`, and use generated databases on the available local service**
- **Found during:** Task 1 tracer setup.
- **Issue:** The first detached checkout had no `node_modules` before `npm ci`; sandboxed `initdb` also failed with `shmget: Operation not permitted`.
- **Fix:** Check Playwright 1.59.1 after installation. Use the already-running local PostgreSQL service only for unique per-invocation databases, and refuse to drop a name unless this runner created it successfully.
- **Files modified:** `scripts/ci/ci-admin-theme-check.mjs`.
- **Committed in:** `bc70855f6`, `1ec492551`.

**3. [Rule 1 - Bug] Match the test under its full Playwright title path**
- **Found during:** Task 1 tracer.
- **Issue:** An anchored grep omitted the parent suite title and selected no tests.
- **Fix:** Match the unchanged unique case title within Playwright's full suite/test title.
- **Files modified:** `scripts/ci/ci-admin-theme-check.mjs`.
- **Committed in:** `bca4f4fc4`.

**4. [Rule 1 - Bug] Drop the owned database if the browser process fails**
- **Found during:** Task 1 tracer failure-path review.
- **Issue:** An exception during Playwright execution bypassed the normal `mix ecto.drop` path.
- **Fix:** The outer `finally` stops the app and drops only the exact database successfully created by this invocation. Contract test verifies this guard.
- **Files modified:** `scripts/ci/ci-admin-theme-check.mjs`, `scripts/ci/ci-admin-theme-prep.test.mjs`.
- **Committed in:** `cafd8073b`.

**5. [Rule 1 - Bug] Keep backend restoration off the tracer and run it after branding cases**
- **Found during:** Task 1 escalated tracer.
- **Issue:** A Task 2 reset hook ran before the original tracer assertion and failed before reaching the test behavior.
- **Fix:** Remove the hook from the tracer path; after the tracer passed, add an `afterEach` cleanup limited to branding tests. It restores defaults through the supported admin dialog and surfaces cleanup failures.
- **Files modified:** `test/example/priv/playwright/tests/admin-theme.spec.ts`.
- **Committed in:** `51c68c3e7`, `3e4c67369`.

**Total deviations:** 5 auto-fixed (3 blocking setup/cleanup issues, 2 runner/test bugs).
**Impact on plan:** The planned fixture and real-browser proof completed. Each failed setup/tracer attempt remains in branch history and under a scoped `refs/gsd/phase254/admin-theme-check-*` ref; the final JSON records the passing tracer and all-mode results.

## Issues Encountered

- The default sandbox denied Chromium's macOS Mach-port bootstrap. With the parent's authorized local-check escalation, Chromium launched successfully; no product-level assertion was waived or retried.
- The final all-mode local run took 278 seconds. This is development evidence only and does not establish hosted median, p95, or runner-cost targets.
- No package was added, no hosted run was started, and no change was made to shared planning state.

## User Setup Required

None.

## Next Phase Readiness

Plan 254-04 may proceed. The reusable fixture, bounded browser modes, and local controls are complete. The required hosted comparison and both CISPEED acceptance thresholds remain unproven.

## TDD Gate Compliance

- **Task 1 RED:** `8d4afe6e7`; both target contract assertions failed because the opt-in fixture did not exist. The failure was an assertion on the missing planned contract, not a load or syntax error.
- **Task 1 GREEN:** `96eaa9503`; the fixture and real tracer runner were added. The passing tracer record later shows the original case passed through one registration and one fresh consumer context.
- **Task 2 RED:** `f7e9feedb`; the new backend-restoration target failed on the missing `restoreBrandingDefaults` hook.
- **Task 2 GREEN:** `3e4c67369`; the supported-UI cleanup and full individual/file/state-control paths were added; contract suite passed 7/7.
- **REFACTOR:** No separate refactor commit was needed.

## Decisions and Evidence Notes

- The 18 individual records use unique database identities and each report one passed case, zero failures, and zero skips. The full-file report records 19 passed, zero failures, zero skips.
- Safe diagnostics include only a random context ID, auth filename, file mode, and database identity. Cookie and storage bytes are not included.
- The first tracer diagnostic is recoverable from `refs/gsd/phase254/admin-theme-check-tracer`; earlier actual failures remain recoverable from their correspondingly named `admin-theme-check-*` refs.

---
*Phase: 254-speed-up-the-measured-slow-jobs*
*Completed: 2026-10-23*

## Self-Check: PASSED

- Summary, fixture, checker, test contract, and machine-readable browser record exist.
- All task commits, including the final evidence commit, are ancestors of `HEAD`.
- The committed all-mode record contains 20 passing native invocations and 18 distinct contexts in the full-file run.
