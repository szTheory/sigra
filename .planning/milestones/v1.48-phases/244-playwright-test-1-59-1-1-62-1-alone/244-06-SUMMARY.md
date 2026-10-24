---
phase: 244-playwright-test-1-59-1-1-62-1-alone
plan: 06
subsystem: testing
tags: [playwright, github-actions, provenance, merge-eligibility]

# Dependency graph
requires:
  - phase: 244-playwright-test-1-59-1-1-62-1-alone
    provides: Phase 244 measurement workflow, manifest, and deferred disposition
provides:
  - Run and artifact API provenance bound to complete manifest bytes
  - Fail-closed current PR, base, policy, and required-check eligibility
  - Updated offline-verifiable Phase 244 evidence receipt
affects: [phase-244, playwright-baseline, merge-eligibility]

# Actuals (#2632)
actuals:
  tokens: 148877
  tasks: 2
  commits: 4
plan_head_before: 8493fd0fbc304d51b2a5c0314547c6813e1c4954
commits: 4

# Tech tracking
tech-stack:
  added: []
  patterns: [structured GitHub API provenance, exact-head authorization evaluation, fail-closed policy collection]

key-files:
  created: []
  modified:
    - .github/workflows/phase-244-playwright-measure.yml
    - scripts/ci/measure-playwright-drift.mjs
    - scripts/ci/measure-playwright-drift.test.mjs
    - .planning/phases/244-playwright-test-1-59-1-1-62-1-alone/244-PLAYWRIGHT-EVIDENCE.json

key-decisions:
  - "Retain the measured drift as a valid failure conclusion and require success only for zero-drift runs."
  - "Persist inaccessible classic branch protection as untrusted policy, preserving a false eligibility decision."
  - "Compare authorization records structurally so JSON object key order does not affect offline validation."

patterns-established:
  - "Measurement trust requires exact manifest bytes, a completed structured run, and the matching artifact API digest."
  - "Merge eligibility requires complete current policy and exactly one successful result per required entry at the measured SHA."

requirements-completed: [QUEUE-02]
coverage:
  - id: D1
    description: Full measurement manifest bytes are bound to matching workflow run and artifact API identity.
    requirement: QUEUE-02
    verification:
      - kind: unit
        ref: "node --test scripts/ci/measure-playwright-drift.test.mjs — structured provenance fixtures"
        status: pass
    human_judgment: false
  - id: D2
    description: Merge eligibility fails closed on drift, stale candidate state, incomplete policy, or nonmatching required checks.
    requirement: QUEUE-02
    verification:
      - kind: unit
        ref: "node --test scripts/ci/measure-playwright-drift.test.mjs — authorization fixtures"
        status: pass
      - kind: other
        ref: "offline verify of .planning/phases/244-playwright-test-1-59-1-1-62-1-alone/244-PLAYWRIGHT-EVIDENCE.json"
        status: pass
    human_judgment: false

# Metrics
duration: 31min
completed: 2026-09-26
status: complete
---

# Phase 244 Plan 06: Structured Provenance and Eligibility Summary

**Playwright measurements now require API-bound run and artifact provenance, with merge eligibility derived from current PR and required-check evidence.**

## Performance

- **Duration:** 31 min
- **Started:** 2026-09-26T17:49:00-04:00
- **Completed:** 2026-09-26T18:20:17-04:00
- **Tasks:** 2
- **Files modified:** 4

## Accomplishments

- Bound the full raw measurement manifest to a completed workflow run, exact artifact record, archive digest, and exact extracted bytes.
- Collected current PR, main, live head ref, active rules, classic protection response, check runs, statuses, and required workflow results using read-only GET requests.
- Persisted the structured evidence and false eligibility outcome for the existing drifted measurement and closed PR #213.
- Added offline positive and negative fixtures for run/artifact identity, policies, pagination, and exact-head check results.

## Task Commits

Each task was committed with TDD red and implementation commits:

1. **Task 1: Bind the full measurement manifest to structured run and artifact identity**
   - `5d24b17c` test(244-06): add structured provenance contract fixture
   - `7bb8fb85` feat(244-06): bind measurements to run and artifact APIs
2. **Task 2: Require live PR, base, and current required checks for merge eligibility**
   - `b32cf3f1` test(244-06): define fail-closed merge eligibility contract
   - `7373979e` feat(244-06): derive eligibility from current GitHub authorization

## Files Created/Modified

- `.github/workflows/phase-244-playwright-measure.yml` - Adds only read permissions and read-only API collection for provenance and authorization.
- `scripts/ci/measure-playwright-drift.mjs` - Verifies run/artifact identity and derives fail-closed eligibility.
- `scripts/ci/measure-playwright-drift.test.mjs` - Covers structured provenance, policy, pagination, and exact-head authorization cases.
- `.planning/phases/244-playwright-test-1-59-1-1-62-1-alone/244-PLAYWRIGHT-EVIDENCE.json` - Records API-bound provenance and the current deferred, ineligible disposition.

## Decisions Made

- A measured drift remains a valid completed measurement whose workflow conclusion is failure; success is required only when the verdict is zero-drift.
- An inaccessible classic required-status protection response is retained as an explicit untrusted-policy error and forces ineligibility.
- Authorization records are compared structurally, independent of JSON object key ordering.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Preserve provenance for a completed drift measurement**
- **Found during:** Task 1
- **Issue:** The plan required a successful workflow conclusion, but the authoritative run correctly concluded `failure` because its completed measurement found pixel drift. Requiring success would reject the genuine measurement and prevent an accurate deferred receipt.
- **Fix:** Require `success` for `zero-drift` and `failure` for `drift` or `inconclusive`, while preserving false merge eligibility for nonzero verdicts.
- **Files modified:** `scripts/ci/measure-playwright-drift.mjs`, `scripts/ci/measure-playwright-drift.test.mjs`
- **Verification:** Structured run fixtures and full offline suite passed; live run `36262576391` provenance verified against exact manifest bytes and artifact digest.
- **Committed in:** `7bb8fb85` and `7373979e`

**2. [Rule 1 - Bug] Compare persisted eligibility independent of JSON key order**
- **Found during:** Task 2
- **Issue:** The receipt stores the same derived eligibility object with a different property order, and stringified comparison incorrectly rejected it.
- **Fix:** Use structural equality for offline eligibility receipt validation.
- **Files modified:** `scripts/ci/measure-playwright-drift.mjs`
- **Verification:** Offline receipt validation and all contract tests passed.
- **Committed in:** `7373979e`

**Total deviations:** 2 auto-fixed (1 blocking correctness issue, 1 validation bug)
**Impact on plan:** The change keeps completed drift evidence truthful and still fails closed. No remote state was changed.

## Issues Encountered

- The classic branch-protection endpoint returned HTTP 404. The collector preserves this as an untrusted policy source; eligibility remains false. The active ruleset's five required contexts and exact-head results are retained in the receipt.
- GitHub's plural statuses listing did not provide pagination totals; collection uses the combined-status endpoint with explicit complete pagination metadata.
- `roadmap.update-plan-progress 244` returned `missing_phase_details`; the GSD handler did not recognize the existing checklist-form Phase 244 entry or its progress-table row, so ROADMAP.md remains unchanged at the stale 5/5 count. `state.update-progress` also reported no body `Progress:` line and left frontmatter progress unchanged. Both limitations are surfaced to the orchestrator.

## TDD Gate Compliance

- Task 1 RED: `5d24b17c`; GREEN: `7bb8fb85`.
- Task 1 tracer feedback gate: full contract suite passed before Task 2 expansion.
- Task 2 RED: `b32cf3f1`; GREEN: `7373979e`.
- Final verification: `node --test scripts/ci/measure-playwright-drift.test.mjs` — 49 tests passed, 0 failed.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Plan 244-07 can proceed with the verified read-only evidence contract.
- Plan 244-08 must rerun `MIX_ENV=test HEX_HOME=/private/tmp/sigra-phase244-hex-cache mix ci` on the final gap-code HEAD before any remote update.
- No workflow dispatch, push, PR update, merge, or remote ref change was performed.

## Self-Check: PASSED

- Summary file path and all four task commits were verified.
- Evidence receipt validates offline with verdict `drift` and `merge_eligible: false`.
- No code stubs, skipped tests, or unrun plan verification remain.
- Sequential STATE position is Plan 7 of 8; ROADMAP progress could not be written by the required GSD handler.

---
*Phase: 244-playwright-test-1-59-1-1-62-1-alone*
*Completed: 2026-09-26*
