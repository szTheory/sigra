---
phase: 254-speed-up-the-measured-slow-jobs
plan: "04"
subsystem: testing
tags: [playwright, organizations, authentication, postgres, ci]
requires:
  - phase: 254-speed-up-the-measured-slow-jobs
    plan: "01"
    provides: Pinned local app/database/browser preparation
  - phase: 254-speed-up-the-measured-slow-jobs
    plan: "03"
    provides: Isolated Playwright invocation and owned database patterns
provides:
  - Browser-proved authenticated zero-organization state after registration helper return
  - Organization invitation owner paths without duplicate login-page navigation
  - Native pre-change and post-change browser outcomes for both projects
affects: [254-05, non_admin_smoke, playwright]
actuals:
  tokens: 12965
  tasks: 2
  commits: 3
commits: 3
plan_head_before: 6b13592092e7cd3b9eaefbb07cffd67ff4ac496e
plan_head_after: baa181c70c2a41e1b79ef36acb7133df76f9e121
tech-stack:
  added: []
  patterns:
    - Assert authenticated route access using the existing zero-organization page without a second browser navigation
    - Preserve native Playwright JSON outcomes alongside selected titles, project identities, source digests, and owned database cleanup
key-files:
  created:
    - scripts/ci/ci-org-prep.test.mjs
    - .planning/phases/254-speed-up-the-measured-slow-jobs/254-ORGANIZATION-CHECK.json
    - .planning/phases/254-speed-up-the-measured-slow-jobs/254-04-SUMMARY.md
  modified:
    - test/example/priv/playwright/tests/organizations.spec.ts
key-decisions:
  - "Use a cookie-sharing API request to /organizations and check the existing first-organization response, so authentication is proved without another page.goto navigation."
  - "Remove only the two invitation-owner login calls; retain invitee registration/login and the first-organization, slug, switch, invitation, and acceptance lifecycles."
  - "Treat local test durations as diagnostics; no hosted speed acceptance is claimed."
patterns-established:
  - "A 200 response with the first-organization state after helper return proves the owner is authenticated and still has zero organizations."
  - "Run organization browser cases on fresh uniquely named databases with one worker, zero retries, and real Chromium/mobile projects."
requirements-completed: []
requirements-supported: [CISPEED-01, CISPEED-02]
coverage:
  - id: D1
    description: "Invitation owners use the authentication already established by registration; invitee signup or matching-user login and final membership assertions remain real."
    requirement: CISPEED-02
    verification:
      - kind: unit
        ref: "scripts/ci/ci-org-prep.test.mjs#registered owner helper proves authenticated zero-organization state without browser navigation"
        status: pass
      - kind: e2e
        ref: ".planning/phases/254-speed-up-the-measured-slow-jobs/254-ORGANIZATION-CHECK.json#tracer and individual_runs"
        status: pass
    human_judgment: false
  - id: D2
    description: "All three original organization cases remain selected and pass individually and by file in Chromium and mobile."
    requirement: CISPEED-01
    verification:
      - kind: e2e
        ref: ".planning/phases/254-speed-up-the-measured-slow-jobs/254-ORGANIZATION-CHECK.json#selection, individual_runs, full_file_run"
        status: pass
    human_judgment: true
    rationale: "Local browser runs show coverage parity; only the authorized hosted comparison can establish the required median, p95, and runner-cost result."
metrics:
  duration: 10m
  completed: 2026-10-23
  status: complete
---

# Phase 254 Plan 04: Organization Invitation Navigation Summary

**The two invitation owners now keep the authenticated session established by registration while retaining the complete real organization and invitee lifecycles.**

## Performance

- **Duration:** 10 minutes
- **Started:** 2026-10-23T17:44:00Z
- **Completed:** 2026-10-23T17:54:10Z
- **Tasks:** 2
- **Files modified:** 4

## Accomplishments

- Added `assertAuthenticatedZeroOrganizationState`, which uses the existing `/organizations` route through the browser context's request API and verifies the first-organization state without changing the current page.
- Removed only the duplicate owner `logInIfNeeded` calls from the new-user and matching-user invitation tests. The separate invitee contexts, real invitee signup/login or signed-in acceptance, pending-invitation checks, and original test titles remain.
- Preserved a pre-change native report and actual post-change reports. All three original cases passed individually in Chromium and mobile; the full file passed 6/6 with zero skips, failures, or retries.

## Browser Outcomes

The pinned toolchain was Node 20.18.1 and Playwright 1.59.1. Each invocation used one worker, zero retries, a new uniquely named PostgreSQL database, and Chromium plus mobile project contexts. The test readiness check used the existing `/users/log_in` route. Each database was dropped after its run.

The pre-change new-user invitation case passed 2/2. The committed tracer passed 2/2 after the change. Its native per-test durations were 1,213 ms / 1,936 ms before and 1,207 ms / 1,545 ms after for Chromium / mobile. These are noisy local diagnostics, not a speed claim. The three individual runs each passed 2/2; the full-file run passed 6/6, zero skipped. `--list` selected the same three titles for both projects. See [254-ORGANIZATION-CHECK.json](./254-ORGANIZATION-CHECK.json) for native report digests, exact outcomes, source digests, commands, and the pre-change native report.

Preparation task durations were not recorded separately in these browser invocations, so no database/server preparation savings are attributed to this change.

## Task Commits

1. **Task 1 RED:** `6614383f5` — add failing organization helper and lifecycle contracts.
2. **Task 1 GREEN:** `61ae68be4` — prove authenticated zero-org access and remove duplicate owner navigation.
3. **Task 2 evidence:** `baa181c70` — preserve native organization browser outcomes.

The plan metadata commit will contain this summary. Shared planning state was already dirty at the execution boundary and was not edited or committed by this executor.

## Files Created/Modified

- [organizations.spec.ts](/Users/jon/projects/sigra/test/example/priv/playwright/tests/organizations.spec.ts) — helper-return authentication assertion and two owner navigation removals.
- [ci-org-prep.test.mjs](/Users/jon/projects/sigra/scripts/ci/ci-org-prep.test.mjs) — four structural/lifecycle contract checks.
- [254-ORGANIZATION-CHECK.json](/Users/jon/projects/sigra/.planning/phases/254-speed-up-the-measured-slow-jobs/254-ORGANIZATION-CHECK.json) — pre-change and post-change browser evidence, native report hashes, selected identities, and source digests.

## Verification

- `node --test scripts/ci/ci-org-prep.test.mjs` — 4 passed.
- Focused new-user tracer on Chromium and mobile — 2 passed.
- Each of the three original tests individually on Chromium and mobile — 2 passed per invocation.
- Entire `organizations.spec.ts` on Chromium and mobile — 6 passed, 0 skipped.
- `node --test scripts/ci/prohibitions/p17-no-playwright-retry-wrapper.test.mjs` — 5 passed.
- All browser invocations used `--workers=1 --retries=0`; no hosted runs were started.

## TDD Gate Compliance

- **RED:** `6614383f5`; the named helper-return contract failed because the authentication proof and owner-navigation changes were absent. `gsd_run check tdd-red-evidence` returned `RED_EVIDENCE_OK`; the complete TAP report is retained in the organization check record.
- **GREEN:** `61ae68be4`; the contract suite passed 4/4, then the real tracer passed both projects against a fresh app/database.
- **REFACTOR:** No separate refactor was needed.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Correct contract-test expectations to match actual Playwright source syntax**
- **Found during:** Task 1 GREEN.
- **Issue:** Two initial regex expectations did not account for `expect(response.status()).toBe(200)` and the existing invitee button's multiline locator chain.
- **Fix:** Updated the contract patterns to match the actual expressions while retaining the behavior checks.
- **Files modified:** `scripts/ci/ci-org-prep.test.mjs`.
- **Verification:** Contract suite passed 4/4.
- **Committed in:** `61ae68be4`.

**2. [Rule 3 - Blocking] Match the existing app build and readiness configuration**
- **Found during:** Task 1 pre-change capture.
- **Issue:** An external temporary Mix build path produced broken relative JOSE include symlinks; the app's compile-time endpoint settings also require stable `PORT` and `CI=true`, and this app has no `/health` route.
- **Fix:** Reused the app-local ignored build path, kept the compiled port fixed, set `CI=true`, and waited on the existing `/users/log_in` route. The available local PostgreSQL server provided fresh owned databases because sandboxed `initdb` is blocked by shared-memory restrictions.
- **Files modified:** None beyond generated ignored build output.
- **Verification:** Fresh migrated/seeded databases booted; all actual browser runs passed and databases were absent afterward.
- **Committed in:** Not applicable.

**Total deviations:** 2 auto-fixed (one contract-test correction and one local setup correction).
**Impact on plan:** All required browser selections ran with pinned tools, isolated database state, and the original projects. Preparation component timings remain unmeasured and no hosted acceptance result is claimed.

## Issues Encountered

- The default sandbox blocked Chromium/WebKit launch. The failed launch report was retained; the same pre-change selection then passed with the already-authorized local browser escalation. No product assertion was waived.
- The local browser reports show small per-case timing changes only. They do not establish the required hosted comparison or either CISPEED acceptance threshold.

## User Setup Required

None.

## Next Phase Readiness

Plan 254-04 implementation and local browser verification are complete. CISPEED-01 and CISPEED-02 remain supported but not complete until the authorized hosted comparison records its required median, p95, and runner-cost outcomes. The executor did not alter shared planning state.

---
*Phase: 254-speed-up-the-measured-slow-jobs*
*Completed: 2026-10-23*

## Self-Check: PASSED

- The source, contract test, organization check record, and summary exist.
- Task commits `6614383f5`, `61ae68be4`, and `baa181c70` are ancestors of `HEAD`.
