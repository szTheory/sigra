---
phase: 255-make-failures-reproducible-and-report-the-result
plan: "06"
subsystem: testing
tags: [github-actions, playwright, diagnostics, artifact-retention, canary]
requires:
  - phase: 255-02
    provides: scoped command capture and invocation identity
  - phase: 255-04
    provides: safe diagnostic bundle staging and verification
  - phase: 255-05
    provides: native browser diagnostics and trace sanitization
provides:
  - Shared seven-day diagnostic upload for the library and browser CI owners
  - Bounded non-publishing hosted canary with retrieved success, failure, and cancellation artifacts
  - Final-source tracing overhead measurement with raw run storage references
affects: [browser-ci, ci-diagnostics, phase-255-verification]
commits: 24
plan_head_before: f02fea0ad6f7d9d03a146ed884b4c4348530935f
plan_head_after: 30922ba5170ae7b9525e0d0343dd78d25395446e
actuals:
  tokens: 132986
  tasks: 2
  commits: 24
tech-stack:
  added: []
  patterns: [source-bound diagnostic bundles, frozen controller allowance, exact-run artifact identity]
key-files:
  created:
    - .github/actions/ci-diagnostic-upload/action.yml
    - scripts/ci/ci-diagnostics-canary.py
    - scripts/ci/ci-diagnostics-canary.test.py
    - .planning/execution/255-diagnostics-canary/RESULT.json
    - .planning/execution/255-local/TRACE-OVERHEAD.json
  modified:
    - .github/workflows/ci.yml
    - .github/actions/example-playwright-boot/action.yml
    - scripts/ci/ci-browser-command.mjs
    - scripts/ci/ci-run-metrics.sh
    - .planning/execution/255-diagnostics-canary/FREEZE.json
key-decisions:
  - "Keep the production source SHA and fixture overlay commit separate; a controller-only parser repair is explicitly hash-bound in FREEZE.json without resetting the deadline or allowance."
  - "When GitHub omits workflow_run.run_attempt, accept an artifact only if the run endpoint supplies the attempt, the artifact workflow_run ID matches, and its exact name binds source, run, attempt, job, seam, and invocation."
  - "Keep raw browser output and failed-run logs in ignored .gsd/temp; commit only validated bundles, sanitized summaries, and byte inventories."
patterns-established:
  - "Artifact identity checks can use the exact run-scoped artifact name when the artifact API omits its attempt field, while rejecting any explicit mismatch."
  - "Keep partial cancellation evidence literal: retain files uploaded before cancellation and list files that never arrived."
requirements-completed: []
coverage:
  - id: D1
    description: "The shared upload action retained and returned an invocation-bound success artifact with verified member hashes."
    verification:
      - kind: e2e
        ref: ".planning/execution/255-diagnostics-canary/RESULT.json; run 40122912945; artifact 12572360759"
        status: pass
    human_judgment: false
  - id: D2
    description: "The failure fixture returned a real failed run and artifact; cancellation returned a real cancelled run with partial evidence and two explicit missing files."
    verification:
      - kind: e2e
        ref: ".planning/execution/255-diagnostics-canary/RESULT.json; runs 40123954650 and 40124112173"
        status: pass
    human_judgment: false
  - id: D3
    description: "Three paired tracing-off/on browser runs recorded exact durations and source hashes, separate from acceptance measurements."
    verification:
      - kind: integration
        ref: "node scripts/ci/ci-browser-diagnostics.test.mjs --measure-overhead --pairs 3 --output .planning/execution/255-local/TRACE-OVERHEAD.json"
        status: pass
    human_judgment: false
metrics:
  duration: 46min
  completed: 2026-10-24
status: complete
---

# Phase 255 Plan 06: Retain and Verify CI Diagnostics Summary

**CI diagnostics now use a shared seven-day upload boundary, and a finite hosted canary verified real success, failure, and partial cancellation artifacts.**

## Performance

- **Duration:** 46 minutes, from the first Plan 06 task commit through cancellation evidence verification.
- **Started:** 2026-10-24T18:28:36Z
- **Completed:** 2026-10-24T19:14:03Z
- **Tasks:** 2/2
- **Files changed:** 34 across task commits, including scoped evidence and test records.

## Accomplishments

- Added a shared upload action that stages explicit diagnostic files, verifies the bundle, and retains it for seven days. Integrated it into library and browser setup/failure paths while preserving legacy browser report members required by metrics and origin validators.
- Ran three real invocations through the isolated, read-only fixture overlay. Success run `40122912945` and failure run `40123954650` each returned a complete artifact. Cancellation run `40124112173` was canceled after its exact upload step succeeded; its surviving artifact is marked partial and lists `final-output.log` and `final-trace.zip` as missing.
- Measured six passing browser runs on source commit `d6ce89a067c75308fb254a637691feadf2061349`, with one worker and zero retries. Tracing off averaged 519.208 ms; tracing on averaged 478.235 ms. The observed −40.973 ms (−7.89%) is noisy and inconclusive, not a performance improvement and not an adjustment to historical measurements.
- Verified the final run/artifact/member identities and all three actual conclusions with the controller's terminal verifier. Final allowance use: 37/120 requests, 3/4 invocations, 1/2 pushes, zero infrastructure retries, and zero test retries. The conservative deadline stayed `2026-10-24T19:51:49Z`; no allowance was reset.

## Verification

- `python3 -B scripts/ci/ci-diagnostics-canary.test.py`: passed, 16 tests, including the captured GitHub response regression and direct legacy metrics extraction.
- `node --test scripts/ci/ci-browser-records.test.mjs scripts/ci/ci-playwright-report.test.mjs scripts/ci/ci-measure-workflow.test.mjs`: passed.
- `python3 -B scripts/ci/ci-hosted-gate-verify.test.py`: passed.
- `bash scripts/ci/honest-skip-verdict.test.sh`: passed.
- `python3 -B scripts/ci/ci-diagnostics-canary.py verify --freeze .planning/execution/255-diagnostics-canary/FREEZE.json --output .planning/execution/255-diagnostics-canary/RESULT.json`: passed with conclusions `success`, `failure`, and `cancelled` and budget usage inside every frozen cap.
- `node scripts/ci/ci-browser-diagnostics.test.mjs --measure-overhead --pairs 3 --output .planning/execution/255-local/TRACE-OVERHEAD.json`: passed with six duration records. The first sandboxed launch was blocked by macOS Chromium's Mach port permission check before any test ran; the same command then passed with browser process permissions enabled. The failed attempt remains in ignored raw storage and is not counted as a duration.
- The actual failure run's log ZIP was fetched once after its failure conclusion; its nine member hashes and the intentional assertion are recorded. Raw logs and browser output remain under ignored `.gsd/temp`, with inventories and safe references in `.planning/execution/255-local/RAW-STORAGE.json`.

## Task Commits

Task 1 (source-bound upload, freeze, and success retrieval) commits:

1. `3ad738e08` TDD RED contracts; `520178c58` shared upload integration; `7aae47281` local evidence preflight.
2. `0c758b604`, `99d7b9dc6`, `a570318fb`, `dd8981fab`, `b613dc056`, and `bded1c721` froze the allowance, charged/reconciled the scoped push, and preserved the initial identity failure.
3. `4460b0f37`, `f0bea37fd`, `72cdb9a1d`, and `ca6522eae` charged and preserved the existing-run and artifact-list responses.
4. `4fe4205b1` added the assertion-based RED test; `c31d1ff4b` fixed the artifact-attempt parser and added existing-run recovery; `02831b210` recorded the controller-only hash amendment without changing the original source, fixture, deadline, or caps.
5. `a3cd6a6d4` retained the verified success artifact; `b894e3f6c` separated the superseded parser stop from the final result.

Task 2 (failure, cancellation, and overhead evidence) commits:

1. `d6ce89a06` stored overhead raw runs in ignored temp storage and recorded exact run hashes/durations.
2. `589af125b` retained failure and overhead results; `4ffde70fa` precharged failed logs; `972e85337` recorded the raw response; `c5ccb5246` committed sanitized log hashes and raw-storage references.
3. `30922ba51` retained the verified cancellation artifact and final three-scenario verifier result.

## TDD Gate Compliance

- The planned upload contract RED commit `3ad738e08` preceded the implementation commit `520178c58`; the recorded target test failed on its intended assertions before integration.
- During actual artifact retrieval, a second assertion-based RED test was committed as `4fe4205b1`. `gsd_run check tdd-red-evidence` returned `RED_EVIDENCE_OK` for `TDD-RED-artifact-attempt.json`; semantic inspection confirmed the target failed because the artifact API omitted `workflow_run.run_attempt`, despite the run endpoint and exact artifact name agreeing. `c31d1ff4b` made the target pass and rejects an explicit wrong attempt or artifact name.

## Decisions Made

- GitHub's artifact endpoint was treated as omitting `workflow_run.run_attempt`, not as providing a conflicting attempt. The actual run API response supplied attempt `1`; the artifact's run ID matched and its exact name contained the frozen source, run, attempt, job, seam, and probe ID. The checker now accepts only that fully matched case.
- The controller-only repair was bound to its old and new SHA-256 values in the freeze amendment. Production source SHA `7aae47281bb3e91bb38fe2387427f27bd0b44327`, fixture commit `504aaa25ca047792ca70a62f78c164f8d908ddd9`, original deadline, and allowance were retained.
- The measured tracing-on mean was lower in this small sample. It is reported as inconclusive rather than evidence that tracing improves performance.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Repaired artifact identity validation for an omitted API attempt field.**
- **Found during:** Task 1, while retrieving the actual success artifact.
- **Issue:** The artifact API returned the matching `workflow_run.id` but omitted `workflow_run.run_attempt`; the controller rejected the artifact before downloading it.
- **Fix:** Preserved the failed result, retrieved the existing run and artifact-list responses once each, added a regression test using those exact bytes, and accepted the omission only when the run endpoint and exact source/run/attempt/job/seam/invocation name agree.
- **Files modified:** `scripts/ci/ci-diagnostics-canary.py`, `scripts/ci/ci-diagnostics-canary.test.py`, `.planning/execution/255-diagnostics-canary/FREEZE.json`, `.planning/execution/255-diagnostics-canary/RESULT.json`.
- **Verification:** RED classified `RED_EVIDENCE_OK`; targeted and full controller/gate tests passed; existing artifact downloaded and all member hashes verified.
- **Committed in:** `4fe4205b1`, `c31d1ff4b`, and `02831b210`.

**2. [Rule 3 - Blocking] Kept overhead raw browser output out of tracked planning files.**
- **Found during:** Task 2.
- **Issue:** The prescribed overhead runner originally placed each native raw run beside the tracked JSON summary.
- **Fix:** The runner now writes raw runs under ignored `.gsd/temp` and records per-run durations and source hashes; inventory hashes and safe references are stored in `RAW-STORAGE.json`.
- **Files modified:** `scripts/ci/ci-browser-diagnostics.test.mjs`, `.planning/execution/255-local/TRACE-OVERHEAD.json`, `.planning/execution/255-local/RAW-STORAGE.json`.
- **Verification:** Six passing runs, byte inventories read back exactly, and no raw run tree was staged.
- **Committed in:** `d6ce89a06`, `589af125b`.

**Total deviations:** 2 auto-fixed (one parser bug, one raw-output storage adjustment).
**Impact on plan:** Recovered the existing successful artifact without redispatch and completed the bounded scenarios without resetting the allowance.

## Issues Encountered

- The first uncharged rate read before the freeze had no retained raw response or known timestamp. It is explicitly recorded as one conservatively spent request with reported remaining `4051` marked unverified; no timestamp or receipt was invented.
- The first artifact-list mismatch was preserved in `RESULT.json` and `STOP.json` history. It was superseded only after the already completed success run's raw API responses proved the exact identity and its artifact was retrieved.
- The first local overhead attempt hit a macOS Chromium Mach port permission failure before the test began. The same six-run measurement command passed with browser process permissions enabled; the failed raw directory remains inventoried separately.
- Cancellation correctly preserved a partial artifact; the two expected post-cancellation files remain absent and are recorded as missing.

## User Setup Required

None.

## Next Phase Readiness

Plan 255-06 has a verified success artifact, a real failed run with logs and artifact, a real canceled run with partial artifact and explicit missing files, and a separately reported tracing overhead sample. This summary does not mark phase-level CIDX requirements complete; that status remains with the phase owner. The evidence branch was not deleted or pushed again.

## Self-Check: PASSED

- Summary file exists at the required phase path.
- All 24 commits measured from `plan_head_before` are ancestors of the current HEAD.

---
*Phase: 255-make-failures-reproducible-and-report-the-result*
*Completed: 2026-10-24*
