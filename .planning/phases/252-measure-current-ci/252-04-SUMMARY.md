---
phase: 252-measure-current-ci
plan: "04"
subsystem: ci-observability
tags: [node, playwright, timing, test-only]
requires:
  - phase: 252-01
    provides: Bounded CI collection and replay for later source-bound timing analysis.
provides:
  - Opt-in native Playwright JSON output alongside the existing list and HTML reporters.
  - A dependency-free normalizer that preserves project, test, retry, result, duration and completeness data.
affects: [252-05, 252-06]
actuals:
  tokens: 6372
  tasks: 2
  commits: 4
commits: 4
plan_head_before: fbe453e8fc6879166a04ecb2a85fd434beda21f6
plan_head_after: 5df05038f2098951a5624be021e78adb189760ae
tech-stack:
  added: []
  patterns:
    - Keep timing collection opt-in and preserve native test selection, workers, retries and human-readable reporters.
    - Treat absent timing, excluded counts and reporter overhead as unknown rather than zero.
key-files:
  created:
    - scripts/ci/ci-playwright-report.mjs
    - scripts/ci/ci-playwright-report.test.mjs
  modified:
    - test/example/priv/playwright/playwright.config.ts
key-decisions:
  - "SIGRA_PLAYWRIGHT_JSON enables native JSON output; an unset or empty value leaves the regular reporter list unchanged."
  - "Native Playwright JSON does not report excluded test counts, so excluded_count remains null with an explicit reason."
  - "No paired same-selection reporter runs were recorded, so reporter overhead remains unmeasured and null."
  - "Workflow invocation wiring stays with Plan 252-05, whose declared ownership includes ci.yml."
patterns-established:
  - "Validate report project identity and terminal result records before producing a complete timing report."
  - "Sort by stable test identity and retry so equal-duration tests remain distinct and reproducible."
requirements-completed: []
coverage:
  - id: D1
    description: "Existing Playwright selections can opt into native JSON output while retaining list and HTML reports and serial one-worker zero-retry settings."
    requirement: CIMEAS-02
    verification:
      - kind: unit
        ref: "scripts/ci/ci-playwright-report.test.mjs#Playwright JSON output is opt-in beside the existing human-readable reporters"
        status: pass
      - kind: unit
        ref: "scripts/ci/ci-playwright-report.test.mjs#the five existing browser seam identifiers and selection commands stay in place"
        status: pass
    human_judgment: false
  - id: D2
    description: "Native Playwright results normalize into source-identified millisecond rows, with malformed or incomplete reports and unavailable overhead kept unknown."
    requirement: CIMEAS-02
    verification:
      - kind: unit
        ref: "scripts/ci/ci-playwright-report.test.mjs#normalizes identity, retry, result and millisecond durations without merging ties"
        status: pass
      - kind: unit
        ref: "scripts/ci/ci-playwright-report.test.mjs#rejects malformed, empty, truncated, duplicate and invalid-duration reports as incomplete"
        status: pass
      - kind: integration
        ref: "scripts/ci/ci-playwright-report.test.mjs#CLI writes incomplete output atomically and retains a nonzero status for missing or malformed input"
        status: pass
    human_judgment: false
duration: 28min
completed: 2026-10-12
status: complete
---

# Phase 252 Plan 04: Native Playwright report timing Summary

**The browser test config can emit native JSON on demand, and a dependency-free Node CLI turns complete reports into stable per-test timing rows without converting missing data to zero.**

## Performance

- **Duration:** 28 minutes
- **Started:** 2026-10-12T18:32:22Z
- **Completed:** 2026-10-12T19:00:16Z
- **Tasks:** 2
- **Files modified:** 3

## Accomplishments

- Added `SIGRA_PLAYWRIGHT_JSON` as an opt-in native JSON reporter beside the existing list and HTML reporters. With the variable unset or empty, the existing reporters remain unchanged; worker count, serial execution, retries and project definitions are untouched.
- Added a Node 20-compatible, dependency-free normalizer for the Playwright 1.59.1 JSON format. It preserves project, seam, invocation, spec/test identity, retry, literal result, start time and millisecond duration; complete output also separates summed attempt time from suite elapsed time.
- Made missing, malformed, truncated, duplicate, cross-project and invalid-duration reports incomplete. Missing-result skipped tests retain null duration/retry, excluded counts remain null because the native report does not provide them, and reporter overhead is explicitly `unmeasured` with `overhead_ms: null`.
- The report CLI writes derived output through a same-directory temporary file and rename. Missing or invalid input still writes an incomplete diagnostic and exits nonzero; output errors retain a nonzero exit and do not publish partial output. It also refuses to overwrite its raw input.
- The test contract confirms all five existing browser seam identifiers, all seven existing Playwright CLI commands, and each command's explicit zero-retry flag.

## Task Commits

1. **Task 1: Produce one JSON report per existing Playwright invocation** — `30a3f45ca` (RED contract), `111375214` (reporter implementation).
2. **Task 2: Normalize browser results and flag incomplete reports** — `2c5674c58` (RED contract), `5df05038f` (normalizer implementation).

## Files Created/Modified

- `test/example/priv/playwright/playwright.config.ts` — enables native JSON only when `SIGRA_PLAYWRIGHT_JSON` has a destination.
- `scripts/ci/ci-playwright-report.mjs` — validates native reports and atomically writes normalized output.
- `scripts/ci/ci-playwright-report.test.mjs` — reporter, selection, normalization, incomplete data, stable ordering, CLI and atomic-output contracts.

## Decisions Made

- The native JSON report contains no excluded-test count. The normalized contract uses `excluded_count: null` and explains why instead of guessing zero.
- No five-with/five-without paired observations were available for this Playwright selection, so the report overhead remains explicit as unmeasured; no estimate is subtracted from timing.
- The CI workflow edits belong to Plan 252-05. That plan should provide a distinct `SIGRA_PLAYWRIGHT_JSON` path to each of the seven commands:
  - `admin_behavior` command: `admin-behavior.json`
  - `admin_checkpoints` command: `admin-checkpoints.json`
  - `design_gallery` PR behavior command: `design-gallery-pr-behavior.json`
  - `design_gallery` non-PR snapshot command: `design-gallery-nonpr-snapshots.json`
  - `design_gallery` non-PR non-snapshot behavior command: `design-gallery-nonpr-behavior.json`
  - `non_admin_smoke` command: `non-admin-smoke.json`
  - `demo_showcase` command: `demo-showcase.json`

## Deviations from Plan

None. The plan's `files_modified` scope assigns workflow wiring to the dependent Plan 252-05; this plan supplies the opt-in config and the per-invocation contract for that wiring.

## Planning Write-Ahead Preservation

The SDK state transition and later route updates were committed before their exact planning files were refreshed. Each read-back hash below matched the committed bytes.

| Prior revision | Durable commit | Path | Exact SHA-256 read-back |
|---|---|---|---|
| SDK plan advance | `feb0db300` | `.planning/STATE.md` | `8711157ddf0eae47e3d61d1aeb2f60f872dbf0212bf880064bebc3c4680fd32a` |
| SDK plan advance | `feb0db300` | `.planning/state.json` | `8d6f70acf511f73e56279579fb850b185e00bd8dc287a6f61d5280f0b4e40317` |
| SDK performance metric | `d999831b1` | `.planning/STATE.md` | `cea4c97af961d7341352af451d094af9a346252c2a122c7dd62a0a93c7129a35` |
| SDK decision entry | `a3d2f13c0` | `.planning/STATE.md` | `834b3491dd3c9f60ce74e132355b092ab05c43a22cba20a338d544a99844904c` |
| SDK session route | `262a99fa5` | `.planning/STATE.md` | `2d64e7acc426282bae0ecc8ad31902f7a9af4fe6de5ba73541e978a363dc00a0` |
| SDK roadmap progress | `95c87db82` | `.planning/ROADMAP.md` | `1bffd79e520313edb13aa001fa8c870b5e333e9b1aec44e9fc62df634e163531` |

## Issues Encountered

- The lockfile pins `@playwright/test` 1.59.1, but this checkout's installed package reports 1.62.1. The config loaded with the local package using `playwright test --list`; no browser reporter smoke was claimed for the pinned version, and no package install was performed. The normalizer contracts use fixtures shaped from the pinned native report types.
- The plan-scope check resolved all four task commits. The changes add no source directory or new architectural boundary, so no structural codebase map update was needed.

## User Setup Required

None.

## Next Phase Readiness

Plan 252-04 implementation and automated checks are complete. Plan 252-05 can now wire the seven distinct JSON destinations above and bind/upload the reports to their run and attempt metadata. Phase 252 remains in progress; CIMEAS-02 stays pending until phase-level verification.

## Verification

- `node --test scripts/ci/ci-playwright-report.test.mjs` — 8 passed, 0 failed.
- `node --check scripts/ci/ci-playwright-report.mjs` — passed.
- `node --check scripts/ci/ci-playwright-report.test.mjs` — passed.
- `git diff --check` — passed.
- `SIGRA_PLAYWRIGHT_JSON=... playwright test --list tests/golden-path.spec.ts --project=chromium` — loaded the config and listed the selected test; this used installed Playwright 1.62.1, not the locked 1.59.1.
- `gsd_run check evaluation-scope --plan 252-04 --commits-only --raw` — resolved four task commits; changed-file union was empty.

## Self-Check: PASSED

- The three planned source/test files and this summary exist.
- All four task commits are ancestors of the current branch.
- The scoped contract suite passes, and the task commit ledger measures 4 commits from `fbe453e8fc6879166a04ecb2a85fd434beda21f6` through `5df05038f2098951a5624be021e78adb189760ae`.

---
*Phase: 252-measure-current-ci*
*Completed: 2026-10-12*
