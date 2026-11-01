---
phase: 255-make-failures-reproducible-and-report-the-result
plan: "07"
subsystem: testing
tags: [replay, github-actions, comparison-report, distribution]
requires:
  - phase: 255-01
    provides: pinned comparison inputs and offline calculator
  - phase: 255-03
    provides: contributor local CI command and receiver records
  - phase: 255-04
    provides: focused local browser commands
  - phase: 255-05
    provides: local diagnostics and trace evidence
  - phase: 255-06
    provides: bounded hosted diagnostic canary
provides:
  - Immutable remotely accessible replay archive with independent clean-checkout replay evidence
  - Truthful Phase 254 comparison report and tested reproduction guidance
affects: [maintainers, replay, ci-diagnostics, comparison-report]
actuals:
  tokens: 16880
  tasks: 2
  commits: 7
  plan_head_before: 6c9fb43539dcd7b5489ae591767b828c8a17ce65
  plan_head_after: 2f73730a6e53c69612524eefaa3ec3215a39ee46
tech-stack:
  added: []
  patterns: [create-only digest-scoped evidence ref, offline replay from pinned package, semantic report assertions]
key-files:
  created:
    - .planning/execution/255-replay/DISTRIBUTION.json
    - .planning/execution/255-replay/REPORT.json
    - .planning/execution/255-replay/REPORT.md
    - scripts/ci/ci-comparison-report.test.py
  modified:
    - scripts/ci/ci-comparison-replay.py
    - scripts/ci/ci-comparison-replay.test.py
    - .planning/execution/255-replay/DISTRIBUTION-ATTEMPTS.json
    - CONTRIBUTING.md
    - MAINTAINING.md
key-decisions:
  - "Publish the exact archive once on a create-only ref named from its full package digest; do not republish after retrieval."
  - "Keep the comparison insufficient_data with zero pairs, null statistics, and CISPEED-01/02 open."
  - "Identify the evidence commit parent/publisher helper and corrected verification controller as separate source identities."
patterns-established:
  - "Bind report assertions to saved source IDs, costs, sample limits, and the actual retrieval history."
  - "Acquire the evidence branch from the real remote in a fresh repository, then run the packaged analysis with network commands blocked."
requirements-completed: []
coverage:
  - id: D1
    description: "Digest-scoped remote package can be fetched from an unrelated checkout and replayed offline with unchanged inputs."
    verification:
      - kind: integration
        ref: ".planning/execution/255-replay/DISTRIBUTION.json#independent_verification"
        status: pass
      - kind: unit
        ref: "scripts/ci/ci-comparison-replay.test.py#test_portable_package_calculates_in_an_empty_directory"
        status: pass
    human_judgment: false
  - id: D2
    description: "Report and contributor/maintainer instructions preserve the measured result and distinguish later diagnostic evidence."
    verification:
      - kind: unit
        ref: "scripts/ci/ci-comparison-report.test.py"
        status: pass
    human_judgment: false
duration: 19m
completed: 2026-10-24
status: complete
---

# Phase 255 Plan 07: Make failures reproducible and report the result Summary

**An immutable remote archive now reproduces the saved `insufficient_data` result from a clean checkout; the report and maintainer guides keep the original measurements separate from later fixes and diagnostics.**

## Performance

- **Duration:** 19 minutes
- **Started:** 2026-10-24T19:16:26Z
- **Completed:** 2026-10-24T19:35:21Z
- **Tasks:** 2
- **Files modified:** 11

## Accomplishments

- Published the 59,461,735-byte package with SHA-256 `6d098e9bee2d28b0d88dda2c517503467448939b4e48af84bf6e2ffd5255fe23` at `refs/heads/evidence/phase255-replay-6d098e9bee2d28b0d88d`, commit `52d2f3611fa195042d52ab0ef9dba64e4d75a2eb`.
- Retrieved that commit in an unrelated fresh repository from the real Git remote. The offline replay verified all 191 package members, unchanged input hashes, zero network-command attempts, zero comparable pairs, null median/p95, and costs 2,046/1,589 seconds.
- Recorded one failed replay after exact retrieval followed by one successful retrieval. The budget ended at one create-only push, zero transport retries, two retrievals, and zero workflow dispatches; no Phase 06 allowance was reused.
- Added the machine and human report plus contributor/maintainer reproduction instructions. The original baseline, candidate, repaired analysis, later development run, and diagnostic sources remain distinct; CISPEED-01/02 remain open.

## Task Commits

1. **Task 1: Retrieve and replay the immutable package** —
   - `800b290e3` (test, RED evidence)
   - `e80670479` (feature, distribution commands)
   - `c560a0b0e` (chore, froze distribution limits)
   - `e41aabd0c` (fix, test-token fixture scanning)
   - `83b62cd55` (fix, use the retrieved checkout's helper)
   - `c54837006` (docs, record bounded retrieval history)
2. **Task 2: Publish the report and reproduction guidance** — `2f73730a6` (docs and semantic assertions)

## Files Created/Modified

- `scripts/ci/ci-comparison-replay.py` and `scripts/ci/ci-comparison-replay.test.py` — create-only package distribution, remote verification, and offline replay support with regression tests.
- `.planning/execution/255-replay/DISTRIBUTION.json`, `DISTRIBUTION-ATTEMPTS.json`, `DISTRIBUTION-FREEZE.json`, and `RED-EVIDENCE.json` — frozen budget, exact remote identity, retrieval history, and TDD evidence.
- `.planning/execution/255-replay/REPORT.json` and `REPORT.md` — saved results, source identities, diagnostic limitations, and reproduction commands.
- `scripts/ci/ci-comparison-report.test.py` — assertions for exact sources, counts, null statistics, open requirements, distribution history, and guide links.
- `CONTRIBUTING.md` and `MAINTAINING.md` — prerequisites, local reproduction, safe artifact handling, and replay instructions.

## TDD Gate Compliance

- **RED:** `test_distribution_commands_are_exposed` failed on the intended assertion because the CLI help exposed only `preflight`, `pack`, and `replay`. The complete captured output is in `RED-EVIDENCE.json`; `gsd_run check tdd-red-evidence .planning/execution/255-replay/RED-EVIDENCE.json --raw` returned `RED_EVIDENCE_OK` (`target_test_failed`).
- **GREEN:** Added the distribution and verification commands; the same target test passed in the replay test suite. RED commit `800b290e3` precedes GREEN commit `e80670479`.
- **REFACTOR:** Subsequent real remote replay exposed that the fetched analysis package intentionally omits the distribution helper. The verification controller was corrected to invoke the helper from the fetched checkout, preserving the first failure and succeeding on retrieval attempt two.

## Decisions Made

- Used one hash-named, create-only evidence branch and did not update it after publication.
- Recorded the corrected verification controller `83b62cd55` separately from the publisher helper/evidence parent `e41aabd0c`.
- Kept the original comparison result as `insufficient_data`; later development and diagnostics are not replacement measurements.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Corrected the clean-checkout helper path after the first exact retrieval**
- **Found during:** Task 1
- **Issue:** The first retrieval obtained the exact archive, but its controller looked for `ci-comparison-replay.py` inside the analysis package, which does not include the distribution helper.
- **Fix:** Invoke the helper from the fetched evidence checkout while replaying only the pinned package contents; retain the failed attempt and use the one remaining retrieval.
- **Files modified:** `scripts/ci/ci-comparison-replay.py`, `.planning/execution/255-replay/DISTRIBUTION-ATTEMPTS.json`
- **Verification:** Attempt two fetched the immutable commit from the real remote in an independent repository and passed offline replay with network commands denied.
- **Committed in:** `83b62cd55`, with retrieval history finalized in `c54837006` and `2f73730a6`.

**2. [Rule 1 - Bug] Allowed deterministic fake tokens in the synthetic secret-scan fixture**
- **Found during:** Task 1
- **Issue:** The secret scanner treated the test fixture's sequential placeholder token as a credential, preventing the intended security assertion from reaching its real-credential case.
- **Fix:** Restrict the fixture exemption to the deterministic sequential fake pattern while keeping real-looking credentials rejected.
- **Files modified:** `scripts/ci/ci-comparison-replay.py`, `scripts/ci/ci-comparison-replay.test.py`
- **Verification:** Replay suite passed all nine tests, including the real-looking credential rejection.
- **Committed in:** `e41aabd0c`.

**3. [Rule 1 - Test correction] Bound report assertions to the actual nested retrieval record and guide structure**
- **Found during:** Task 2
- **Issue:** The first semantic test expected offline fields at the distribution object's root and expected both guides to duplicate the replay command.
- **Fix:** Assert the sole passed retrieval's nested replay fields, exact attempt/budget/source identities, and the maintainer guide's link to the tested command in CONTRIBUTING.
- **Files modified:** `scripts/ci/ci-comparison-report.test.py`
- **Verification:** Report suite passed all six tests.
- **Committed in:** `2f73730a6`.

**Total deviations:** 3 auto-fixed. **Impact:** Fixes were limited to replay correctness and assertions; distribution limits and measured evidence were unchanged.

## Verification

- `PYTHONDONTWRITEBYTECODE=1 python3 -B scripts/ci/ci-comparison-report.test.py` — 6 passed.
- `PYTHONDONTWRITEBYTECODE=1 python3 -B scripts/ci/ci-comparison-replay.test.py` — 9 passed.
- `node --test scripts/ci/ci-browser-records.test.mjs scripts/ci/ci-playwright-report.test.mjs` — 41 passed.
- `PYTHONDONTWRITEBYTECODE=1 python3 -B scripts/ci/ci-hosted-gate-verify.test.py` — 154 passed.
- `bash scripts/ci/ci-run-metrics-comparison.test.sh` — passed.
- `PYTHONDONTWRITEBYTECODE=1 python3 -B scripts/ci/ci-metrics-security.test.py` — 23 passed.
- `node --test scripts/ci/prohibitions/p17-no-playwright-retry-wrapper.test.mjs` — 5 passed.
- Parsed all three report/distribution JSON files and `git diff --check` passed.
- The real `distribute` / `verify-distribution` flow completed with the bounded remote activity recorded above. It was not repeated after the retrieval budget was exhausted.

## Issues Encountered

The first fetched replay failed because the wrapper path was wrong; the preserved diagnosis and correction are described above. No remote push retry was needed, and no additional remote activity occurred after the second retrieval succeeded.

## User Setup Required

None. The report describes the existing local runtime, PostgreSQL, Phoenix archive, npm lockfile, and browser setup.

## Next Phase Readiness

Plan 07 implementation is complete. `CISPEED-01` and `CISPEED-02` remain open, and phase-level CIDX/CIMEAS review and final verification remain for the parent workflow. No requirement is marked complete in this plan summary.

## Self-Check: PASSED

All required implementation/report files exist, and all seven task commits are ancestors of the current branch head.

---
*Phase: 255-make-failures-reproducible-and-report-the-result*
*Completed: 2026-10-24*
