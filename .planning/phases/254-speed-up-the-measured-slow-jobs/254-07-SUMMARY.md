---
phase: speed-up-the-measured-slow-jobs
plan: "07"
subsystem: testing
tags: [playwright, native-reports, comparison-collector, performance]
requires:
  - phase: 254-01..254-06
    provides: Frozen source provenance, measured setup changes, native identity comparison, and hosted comparison tooling
provides:
  - Five isolated workflow-derived browser owner runs with source-bound native reports
  - A 108-row native coverage map and parity receipt with product/setup separation
  - A collector preflight that requires the exact map digest and successful source-bound parity receipt
  - Separate local implementation and hosted readiness decisions for Plan 08
affects: [254-08, collection-eligibility, browser-workload-map]
actuals:
  tokens: 9471210
  tasks: 3
  commits: 6
  plan_head_before: 11f34b734f571163ac424f366270dccf3670b306
  plan_head_after: 8cc0d7c417aba48a1d7cc043e5d1e9cf45a41bb6
tech-stack:
  added: []
  patterns: [source-bound native report descriptors, one-to-one native owner mapping, receipt-gated comparison collection]
key-files:
  created:
    - .planning/phases/254-speed-up-the-measured-slow-jobs/254-COLLECTION-ELIGIBILITY.json
    - .planning/phases/254-speed-up-the-measured-slow-jobs/254-INTEGRATION-CHECK-FINAL8.json
    - .planning/phases/254-speed-up-the-measured-slow-jobs/254-INTEGRATION-CHECK-FINAL8-PARITY-RECEIPT.json
    - .planning/phases/254-speed-up-the-measured-slow-jobs/254-07-SECURITY.md
    - .planning/phases/254-speed-up-the-measured-slow-jobs/254-REVIEW.md
  modified:
    - .planning/phases/254-speed-up-the-measured-slow-jobs/254-WORKLOAD-MAP.json
    - scripts/ci/ci-prep-profile.mjs
    - scripts/ci/ci-browser-records.mjs
    - scripts/ci/ci-run-metrics.sh
    - scripts/ci/ci-hosted-gate-verify.py
key-decisions:
  - "Keep all five existing owners: the local evidence did not prove a compatible move that reduces the measured maximum without increasing total work."
  - "Block hosted collection until a map-and-source-bound receipt confirms all five local native owner comparisons passed."
patterns-established:
  - "Native reports and list selections are accepted only when their bytes match retained source digests."
  - "Setup/dependency rows remain separate from product coverage and keep the same owner."
requirements-completed: []
coverage:
  - id: D1
    description: "Run all five existing isolated browser owners and compare every exact native identity, result, owner, and setup row."
    requirement: CISPEED-02
    verification:
      - kind: integration
        ref: ".planning/phases/254-speed-up-the-measured-slow-jobs/254-INTEGRATION-CHECK-FINAL8.json"
        status: pass
      - kind: integration
        ref: ".planning/phases/254-speed-up-the-measured-slow-jobs/254-INTEGRATION-CHECK-FINAL8-PARITY-RECEIPT.json"
        status: pass
    human_judgment: false
  - id: D2
    description: "Gate future collection on exact native map and successful parity receipt; keep hosted readiness blocked until Plan 08 prerequisites are proven."
    verification:
      - kind: unit
        ref: "bash scripts/ci/ci-run-metrics-comparison.test.sh"
        status: pass
      - kind: other
        ref: ".planning/phases/254-speed-up-the-measured-slow-jobs/254-COLLECTION-ELIGIBILITY.json"
        status: pass
    human_judgment: false
duration: 45min
completed: 2026-10-23
status: complete
---

# Phase 254 Plan 07: Speed Up the Measured Slow Jobs Summary

**Five isolated Playwright owners now produce a source-bound 108-row native comparison, and the hosted collector refuses to start without its passing receipt.**

## Performance

- **Duration:** about 45 minutes from the first task commit
- **Started:** 2026-10-23T14:55:14-04:00 (first task commit)
- **Completed:** 2026-10-23T15:38:37-04:00
- **Tasks:** 3
- **Files modified:** 140 tracked files, mostly retained baseline/candidate native reports and diagnostic logs

## Accomplishments

- Ran the five workflow-defined owners sequentially with separate databases, ports, server processes, and browser state. All five completed successfully with Node 20.19.5 and Playwright 1.59.1.
- Replaced the selection-only map with 108 exact before/after native identity mappings: 105 product cases and 3 design-gallery setup cases. All five owner comparisons passed with no differences.
- Measured the full local owner paths (about 82–110 seconds each), setup components, 371,495 bytes of native report/selection transfer (5 ms), and 148 ms total comparator validation.
- Added a fail-closed collector check for the exact map and parity-receipt digests, all five owner results, source IDs, and a successful owner integration status.
- Reviewed Plan 06's `comparison-family` origin mode and pinned both run and artifact provenance to `szTheory/sigra` and repository ID `1207487684`.
- Recorded implementation readiness separately from hosted readiness. CISPEED-01/02 are supported by local evidence but remain incomplete until authorized Plan 08 hosted acceptance.

## Task Commits

1. **Task 1: Run all five isolated browser owners and build exact native parity** — `9491c8f9b` (`perf`)
2. **Task 2/3: Gate collection on successful parity and bind comparison origin** — `20dcee2f1` (`fix`)
3. **Task 1/3: Record native evidence transfer and comparison cost** — `8cc0d7c41` (`perf`)

TDD and runtime commits: `bf711cdf0` (RED test), `d1d315477` (GREEN workload mode), and `da6401170` (verify the Node version resolved by the workflow shell).

## Files Created/Modified

- [254-WORKLOAD-MAP.json](/Users/jon/projects/sigra/.planning/phases/254-speed-up-the-measured-slow-jobs/254-WORKLOAD-MAP.json) — exact 108-row native map with actual owner outcomes and separate setup rows.
- [254-INTEGRATION-CHECK-FINAL8.json](/Users/jon/projects/sigra/.planning/phases/254-speed-up-the-measured-slow-jobs/254-INTEGRATION-CHECK-FINAL8.json) and [its parity receipt](/Users/jon/projects/sigra/.planning/phases/254-speed-up-the-measured-slow-jobs/254-INTEGRATION-CHECK-FINAL8-PARITY-RECEIPT.json) — actual owner runs, measured setup and native validation/transfer costs, and all five passing comparisons.
- [254-COLLECTION-ELIGIBILITY.json](/Users/jon/projects/sigra/.planning/phases/254-speed-up-the-measured-slow-jobs/254-COLLECTION-ELIGIBILITY.json) — map/receipt digests, test and review references, concrete hosted blockers, and separate readiness states.
- `scripts/ci/ci-prep-profile.mjs` — workflow-derived owner execution, retained report verification, transfer measurement, and exact parity assembly.
- `scripts/ci/ci-browser-records.mjs`, `scripts/ci/ci-run-metrics.sh`, and `scripts/ci/ci-hosted-gate-verify.py` — exact setup-owner checks, receipt-gated collection, and fixed repository-origin validation.

## Decisions Made

- Keep the current five owners and selectors. The local environment provided no measured, compatible recipient headroom for moving work while preserving total cost and isolation.
- Require the map and successful parity receipt in the later collection contract. Missing receipt data or a blocked owner result is rejected before any GitHub request.
- Keep hosted readiness blocked until Plan 08 proves a real PR can use the exact frozen baseline and compatible cache, runner image, and setup inputs.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Used a supported Node 20 patch for frozen selection capture**
- **Found during:** Task 1
- **Issue:** Node 20.18.1 could not load a locked dependency using `require(ESM)`; the exact frozen `--list` command failed before selecting tests.
- **Fix:** Used Node 20.19.5, still within the workflow's Node 20 pin, for the baseline and candidate owner paths. Recorded the actual bash-resolved version.
- **Verification:** The five pinned baseline list captures and the five actual candidate owners passed under Node 20.19.5 / Playwright 1.59.1.
- **Committed in:** `da6401170` and `9491c8f9b`.

**2. [Rule 1 - Bug] Bound native outcomes to exact retained input bytes**
- **Found during:** Task 1
- **Issue:** A source descriptor could have re-hashed substituted report bytes and labeled them as the frozen baseline or actual candidate run.
- **Fix:** Validate baseline report hashes against the archived report record, baseline list hashes against the pinned Node 20.19.5 manifest, and candidate report/list hashes against the original owner-run records before comparison.
- **Verification:** All five comparators passed; the Nyquist adversarial test changed a report byte and observed `native_artifact_digest_not_retained`.
- **Committed in:** `9491c8f9b` and `8cc0d7c41`.

**3. [Rule 2 - Missing Critical] Require repository identity for registered comparison families**
- **Found during:** Task 3 security review
- **Issue:** The Plan 06 origin verifier checked matching run and PR SHAs but did not require the measured repository's fixed name/ID or bind the artifact to that repository.
- **Fix:** Require `szTheory/sigra` / `1207487684` on the saved run and every accepted artifact; add wrong-repository negative cases.
- **Verification:** Hosted verifier tests passed (153 tests); comparison collection shell tests passed.
- **Committed in:** `20dcee2f1`.

**4. [Rule 3 - Blocking] Resolved the baseline selection/report directory mismatch**
- **Found during:** Task 1 native parity assembly
- **Issue:** An earlier extracted selection file did not match the Node 20.19.5 pinned list capture.
- **Fix:** Preserved the earlier extraction and built a verified baseline directory from the exact retained report plus the hash-checked pinned list selection.
- **Verification:** All five source descriptors validated; the native comparator passed with 105 product rows and 3 setup rows.
- **Committed in:** `9491c8f9b`.

**5. [Rule 3 - Blocking] Corrected the evidence transfer base directory**
- **Found during:** Task 3 transfer-cost capture
- **Issue:** The first transfer-only replay resolved owner report references from the repository root instead of the report-reference base.
- **Fix:** Resolve paths from the directory used by the owner report references; retain the blocked replay as a diagnostic and regenerate the final integration result.
- **Verification:** Final8 reports 371,495 verified bytes transferred, all five native comparisons passed, and the transfer helper's digest mismatch test passed.
- **Committed in:** `8cc0d7c41`.

**Total deviations:** 5 auto-fixed (3 blocking, 1 bug, 1 missing critical security check). No workflow owner was moved.

## Verification

- `node --test scripts/ci/ci-prep-profile.test.mjs scripts/ci/ci-browser-records.test.mjs` — 45 passed.
- `bash scripts/ci/ci-run-metrics.test.sh` — passed.
- `bash scripts/ci/ci-run-metrics-comparison.test.sh` — passed, including missing/blocked receipt cases stopping before network calls.
- The retained Phase 253 control chain passed: 53 Node tests, 153 hosted-verifier tests, honest-skip checks, and browser-cache checks.
- Code review: 21 files reviewed, no unresolved findings. Security review: T-254-16 and T-254-17 closed; Plan 08 threats remain open as listed in the security artifact. Nyquist audit: zero remaining gaps.

## TDD Gate Compliance

- **RED:** `scripts/ci/ci-prep-profile.test.mjs` workload-mode test; evidence is recorded in `254-07-01-red-evidence.json`, commit `bf711cdf0`. The target failed because the new workload mode contract had not yet been implemented; the TDD evidence checker accepted it.
- **GREEN:** Workflow-derived owner mode and native report retention, commit `d1d315477`; focused tests later passed 45/45.
- **REFACTOR:** Added actual transfer/validation timing and exact report-origin checks, commit `8cc0d7c41`; focused tests remained green.

## Issues Encountered

- The initial Node 20.18.1 non-admin attempt failed three passkey cases. It remains recorded in `254-INTEGRATION-CHECK.json` and `254-NONADMIN-DIAGNOSTIC.json`; the corrected Node 20.19.5 / localhost run passed. No failures were substituted for hosted acceptance, and no acceptance budget was renewed.
- The first transfer-only replay failed on a path-base mistake; it is preserved separately as FINAL7 and is not used as passing evidence.

## User Setup Required

None for this local plan. Hosted collection remains blocked until Plan 08 establishes the exact PR baseline, cache/image compatibility, and fixed comparison window prerequisites.

## Next Phase Readiness

Plan 07 implementation and local verification are complete. Plan 08 may consume the exact map and receipt paths/digests in `254-COLLECTION-ELIGIBILITY.json`. Hosted readiness remains false; do not begin collection until the eligibility blockers are proven. The phase requirements remain supported, not completed.

The read-only `gsd_run query init.execute-phase 254` readiness check lists `254-08-PLAN.md` as runnable and reports no GSD prerequisite blockers. Its hosted collection prerequisites remain open in the eligibility artifact, so Plan 08 must resolve those before collection.

## Self-Check: PASSED

- Summary, collection eligibility, code review, security review, validation report, and final integration/receipt artifacts exist.
- All six task commits are ancestors of the final implementation HEAD `8cc0d7c417aba48a1d7cc043e5d1e9cf45a41bb6`; the persisted ledger measures six commits from base `11f34b734f571163ac424f366270dccf3670b306`.
- The final map, native comparison, parity receipt, code review, security review, and Nyquist report digests match the retained artifacts.
- `init.execute-phase 254` reports Plan 08 runnable; hosted evidence requirements remain explicitly unresolved.

---
*Phase: 254-speed-up-the-measured-slow-jobs*
*Completed: 2026-10-23*
