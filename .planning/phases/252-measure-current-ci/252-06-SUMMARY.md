---
phase: 252-measure-current-ci
plan: 06
subsystem: ci-measurement
tags: [github-actions, ci, timing, comparison]
requires: [252-05]
provides: [source-bound-current-baseline, immutable-hosted-evidence, matched-comparison-contract, reproducible-baseline-report]
affects: [252, 253, 254]
tech-stack:
  added: []
  patterns: [offline-source-bundle-replay, measured-versus-configured-runtime-identity, matched-cache-strata]
key-files:
  created:
    - scripts/ci/ci-measure-report.sh
    - scripts/ci/ci-measure-report.test.sh
    - .planning/phases/252-measure-current-ci/252-CI-SOURCE-BUNDLE.tar.gz
    - .planning/phases/252-measure-current-ci/252-BASELINE.json
    - .planning/phases/252-measure-current-ci/252-BASELINE.md
    - .planning/phases/252-measure-current-ci/252-COMPARISON-CONTRACT.json
    - .planning/phases/252-measure-current-ci/252-06-STATE-PRESERVATION.json
  modified:
    - scripts/ci/ci-run-metrics.sh
    - scripts/ci/ci-run-metrics.test.sh
    - .github/workflows/ci.yml
    - .planning/phases/252-measure-current-ci/252-06-SUMMARY.md
decisions:
  - Preserve the first ECR container-pull failure and its attempt cost; use only one diagnosed infrastructure retry.
  - Freeze the 20-pair method and measured cache stratum now, then predeclare candidate identity and exact UTC dates before any later comparison run.
  - Keep Playwright reporter overhead null because same-selection paired runs were not recorded.
metrics:
  duration: 84 minutes
  completed_date: 2026-10-12
  plan_head_before: 399f80d8c2f17120117d729a75d3e57f099ec9dc
  plan_head_after: fa2d151e50f3d72afc3c29b925d28cce3fa53451
  commits: 20
actuals:
  tokens: 8676277
  tasks: 3
  commits: 20
status: complete
---

# Phase 252 Plan 06: Hosted baseline, reproducible report and comparison contract

The bounded source bundle now replays into a validated CI baseline, the report distinguishes wait from runner cost, and the later 20-pair comparison method is frozen against the measured hosted PR identity and cache vector.

## Tasks completed

| Task | Result | Commit |
| --- | --- | --- |
| 1. Capture a fresh bounded hosted snapshot and prove offline replay | Complete; source bundle and baseline are committed and hash-validated. | `a071875c7` |
| 2. Freeze the later matched comparison and test all outcome arithmetic | Complete; 20 pairs/40 families, one source-backed cache stratum, exact baseline revisions and fail-closed evaluator are recorded. | `45f3dcb61` |
| 3. Render a reproducible report with one-command replay instructions | Complete; report names event populations, provenance, costs, unknowns and reproduction commands. | `fa2d151e5` |

The implementation fixes were committed separately: `1c7bd817a`, `8bd4d6392`, `b26243c3a`, `b5d1632e6`, `e40889292`, `a76bfd85c`, `2ecbb09dd`, `eb4615dc3`, `2d548f967`, `0461f3118`, `9e882feab`, `dc7ff1965`, `15248bfba`, `705558fe5`, `34ab7d50b`, `ae864e5dc`, and `b9bb12907`.

The plan-state SDK transition was committed and byte-verified at `2c50a2a213a7ca52f2733e694e4b8bc4a630796f` before the handoff text and next route were curated. File hashes and the preserved bytes' original clean-state hashes are in `252-06-STATE-PRESERVATION.json`.

## Hosted evidence

Draft evidence PR [#331](https://github.com/szTheory/sigra/pull/331) produced workflow run [38307191464](https://github.com/szTheory/sigra/actions/runs/38307191464). Its five required checks passed on attempt 2: Library tests; Example unit smoke (ExUnit + ConnTest); Install smoke (fresh phx.new + sigra.install); Example HTTP smoke (boot + curl critical routes); and Example Playwright smoke (full lifecycle). The browser jobs reported Playwright 1.59.1. The PR remains a non-publishing draft; it was not merged.

Attempt 1 failed before Example unit tests began because PostgreSQL container pulls from public ECR hit `Data limit exceeded` on three pulls. Attempt 2 succeeded. The report retains attempt 1's 2,147 runner seconds and the 23-second failed unit-job setup, plus attempt 2's 2,178 runner seconds; total runner cost is 4,325 seconds. No failed attempt was replaced or omitted.

The immutable source bundle digest is `169e5425870bd4486b0c7c6a07a4fd2c938c363fb7c156ffac27f4220f7426f0`. The measured app/workflow revision is `0e15a5713da5aeeec5a81110970011d76486eae1`; its producer jobs checked out merge source `dc94d895317a91e164aa29d47135710641008814`. The workflow file digest is `d5dcdb22303ed7426fc3d597fa47b5c9401fa80f7a5501fdc472ac01642049f6`; the separate measured workload digest is `682515c962a366c31e8c6acada380d58294976d8282ca2d7b081d26c530191db`.

At the fixed cutoff `2026-10-12T21:04:28Z`, the collector selected 100 of 267 pull-request runs (capped), all 81 main-push runs and all 30 scheduled runs. The source-bound full PR sample completed all five required contexts in 594 seconds. It records 1,470 seconds across the six timing producer jobs, ExUnit test time of 188,522 microseconds and Playwright test time of 881,789 milliseconds. The measured cache vector had hits for library dependencies and for example dependencies and browser binaries across all five Playwright seams. The observed runner was Linux X64 on `ubuntu24`, image `20261004.327.1`.

ExUnit's separate five-pair historical overhead measurement remains `-60,547µs` by its saved median method. The current hosted run has no paired uninstrumented sample, and Playwright overhead remains `null` with reason `paired_same_selection_runs_not_recorded`. No overhead estimate is subtracted from later improvement targets. Pure queue time and dependency edges remain unknown where the saved API does not expose them; configured runtime pins stay separate from command-observed versions.

The comparison contract fixes 20 equivalent pairs, 40 primary families, nearest-rank `ceil(0.95*n)` p95 (the 19th sorted value at n=20), the 20% median target, non-increasing p95 and total runner cost, one diagnosed infrastructure retry per original family, and no replacement families or window extension. Its cache allocation assigns all 20 pairs to the only observed full-PR cache vector. Candidate revision and exact UTC dates are intentionally unset; they must be frozen before the first later comparison run. No comparison runs were launched in this plan.

## Deviations from plan

**1. [Rule 2 - Missing critical workflow output] Create the ExUnit timing destination before CI.**

- **Found during:** Hosted full-PR CI.
- **Issue:** The ExUnit producer writes `test-results/ci-exunit-timing.json`, but the workflow did not create `test-results` before `mix ci`.
- **Fix:** Add a directory-creation step and an ordering assertion to the existing workflow contract test. Apply the same repair to the local implementation and scoped evidence PR.
- **Files modified:** `.github/workflows/ci.yml`, `scripts/ci/ci-measure-workflow.test.mjs`.
- **Commit:** `2ecbb09dd` (local implementation; evidence PR carries its own corresponding commit).

**2. [Rule 1 - Replay portability bug] Resolve artifact members from their verified family IDs.**

- **Found during:** Archive replay.
- **Issue:** Collected artifact-member paths named the temporary staging directory, which is absent after the bundle moves.
- **Fix:** Replay resolves members under the family directory using the source-verified numeric artifact ID.
- **Files modified:** `scripts/ci/ci-run-metrics.sh`.
- **Commit:** `705558fe5`.

**3. [Rule 1 - macOS temporary-path bug] Canonicalize extraction paths before invoking Node.**

- **Found during:** Offline replay through the normal repository command.
- **Issue:** macOS's `/var/folders` temporary path alias prevented the Playwright normalizer's CLI entrypoint check from matching, so Node exited without producing normalized output.
- **Fix:** Canonicalize the temporary extraction directory before replay and baseline verification.
- **Files modified:** `scripts/ci/ci-run-metrics.sh`.
- **Commit:** `705558fe5`.

**4. [Rule 1 - Verification output bug] Force JSON output inside baseline verification and comparison evaluation.**

- **Found during:** Running the documented verification command without `--format json`.
- **Issue:** Internal replay inherited the default table format and could not be compared as structured baseline data.
- **Fix:** Make these validator paths request JSON internally; require the baseline to contain the exact source archive SHA-256.
- **Files modified:** `scripts/ci/ci-run-metrics.sh`.
- **Commits:** `dc7ff1965`, `705558fe5`.

**5. [Hosted infrastructure retry] Preserve the failed attempt and its cost.**

- **Found during:** Run 38307191464, attempt 1.
- **Issue:** Public ECR rejected PostgreSQL pulls due to its data-transfer limit; test setup did not start.
- **Fix:** Used one retry after recording the failed attempt and diagnosing the external pull limit. Attempt 2 passed.
- **Files modified:** None.

**6. [TDD evidence gap] The task-level RED/GREEN/REFACTOR sequence was not preserved as separate commits.**

- The report and comparison tests pass, but implementation commits preceded a separately committed failing-test (RED) record for these task-level changes. This is recorded as an execution-process deviation; no retroactive RED evidence is claimed.

## Validation

- `bash scripts/ci/ci-run-metrics.test.sh` — 39 passed, 0 failed.
- `bash scripts/ci/ci-run-metrics-comparison.test.sh` — passed, including 20-pair arithmetic, median 10.5 and p95 19 for the synthetic 1–20 fixture, insufficient-data handling and cache-allocation mismatch.
- `bash scripts/ci/ci-measure-report.test.sh` — passed; repeated report generation is byte-identical.
- `node --test scripts/ci/ci-measure-workflow.test.mjs` — 4 passed.
- `bash scripts/ci/ci-run-metrics.sh --verify-baseline --source-bundle .planning/phases/252-measure-current-ci/252-CI-SOURCE-BUNDLE.tar.gz --baseline .planning/phases/252-measure-current-ci/252-BASELINE.json` — `ready`, no diagnostics.
- Two `--replay` invocations over the committed archive were byte-identical; `bash -n` and `git diff --check` passed.

## Self-Check: PASSED

The source bundle, JSON baseline, report, comparison contract and all 20 plan commits exist on the expected branch. The baseline verifies against the committed bundle digest and offline replay is deterministic.

## Next

Plan 252-06 implementation is complete. Phase 252 remains pending phase-level verification; its requirements stay unchecked until that verification is recorded. Continue with `$gsd-execute-phase 252` for the phase verification/closeout workflow; do not start Phase 253 in this plan.
